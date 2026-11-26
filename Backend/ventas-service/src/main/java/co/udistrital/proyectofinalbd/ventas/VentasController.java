package co.udistrital.proyectofinalbd.ventas;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import co.udistrital.proyectofinalbd.common.web.SqlUtils;
import co.udistrital.proyectofinalbd.common.web.SqlUtils.WhereBuilder;

/**
 * Endpoints REST de pedidos de venta, pagos y devoluciones.
 */
@RestController
@RequestMapping("/api")
public class VentasController {

    private static final int LIMITE_MAXIMO = 200;

    private final JdbcTemplate jdbc;

    public VentasController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/pedidos")
    public List<Map<String, Object>> pedidos(
            @RequestParam(required = false) Integer idSede,
            @RequestParam(required = false) String estado,
            @RequestParam(required = false) Integer idCliente,
            @RequestParam(defaultValue = "100") int limite) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("pv.id_sede = ?", idSede);
        where.agregarSiPresente("pv.estado = ?", estado);
        where.agregarSiPresente("pv.id_cliente = ?", idCliente);
        return jdbc.queryForList(
                "WITH pagos_conf AS ("
                        + "  SELECT id_pedido, COALESCE(SUM(valor), 0) AS pagado "
                        + "  FROM pagos WHERE estado = 'Confirmado' GROUP BY id_pedido"
                        + ") "
                        + "SELECT pv.id_pedido, pv.id_sede, pv.id_almacen, pv.id_cliente, pv.id_empleado, "
                        + "pv.fecha_pedido, pv.estado, pv.total_registrado, "
                        + "COALESCE(pc.pagado, 0) AS total_pagado_confirmado, "
                        + "GREATEST(pv.total_registrado - COALESCE(pc.pagado, 0), 0) AS saldo_pendiente "
                        + "FROM pedidos_venta pv "
                        + "LEFT JOIN pagos_conf pc ON pc.id_pedido = pv.id_pedido"
                        + where.clausula()
                        + " ORDER BY pv.id_pedido DESC LIMIT ?",
                where.params(SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
    }

    @GetMapping("/pedidos/{id}")
    public Map<String, Object> pedidoPorId(@PathVariable int id) {
        List<Map<String, Object>> pedidos = jdbc.queryForList(
                "SELECT id_pedido, id_sede, id_almacen, id_cliente, id_empleado, "
                        + "fecha_pedido, estado, total_registrado "
                        + "FROM pedidos_venta WHERE id_pedido = ?",
                id);
        if (pedidos.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Pedido " + id + " no encontrado");
        }
        List<Map<String, Object>> detalle = jdbc.queryForList(
                "SELECT id_pedido, id_producto, cantidad, precio_unitario "
                        + "FROM detalle_pedido WHERE id_pedido = ? ORDER BY id_producto",
                id);
        List<Map<String, Object>> pagos = jdbc.queryForList(
                "SELECT id_pago, id_pedido, fecha_pago, valor, medio_pago, estado "
                        + "FROM pagos WHERE id_pedido = ? ORDER BY id_pago",
                id);
        List<Map<String, Object>> devoluciones = jdbc.queryForList(
                "SELECT id_devolucion, id_pedido, fecha_solicitud, motivo, estado "
                        + "FROM devoluciones WHERE id_pedido = ? ORDER BY id_devolucion",
                id);

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("pedido", pedidos.get(0));
        respuesta.put("detalle", detalle);
        respuesta.put("pagos", pagos);
        respuesta.put("devoluciones", devoluciones);
        return respuesta;
    }

    @PostMapping("/pedidos")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crearPedido(@RequestBody PedidoRequest req) {
        if (req.detalles() == null || req.detalles().isEmpty()) {
            throw new IllegalArgumentException("El pedido debe incluir al menos un producto");
        }
        int id = req.idPedido() != null
                ? req.idPedido()
                : SqlUtils.siguienteId(jdbc, "pedidos_venta", "id_pedido");
        LocalDate fecha = req.fechaPedido() != null ? req.fechaPedido() : LocalDate.now();
        String estado = (req.estado() == null || req.estado().isBlank()) ? "Pendiente" : req.estado();

        BigDecimal total = BigDecimal.ZERO;
        for (DetallePedidoRequest linea : req.detalles()) {
            if (linea.cantidad() == null || linea.precioUnitario() == null) {
                throw new IllegalArgumentException("Cada línea requiere cantidad y precioUnitario");
            }
            total = total.add(linea.precioUnitario().multiply(BigDecimal.valueOf(linea.cantidad())));
        }

        jdbc.update(
                "INSERT INTO pedidos_venta (id_pedido, id_sede, id_almacen, id_cliente, id_empleado, "
                        + "fecha_pedido, estado, total_registrado) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                id, req.idSede(), req.idAlmacen(), req.idCliente(), req.idEmpleado(),
                fecha, estado, total);

        for (DetallePedidoRequest linea : req.detalles()) {
            jdbc.update(
                    "INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES (?, ?, ?, ?)",
                    id, linea.idProducto(), linea.cantidad(), linea.precioUnitario());
        }
        return pedidoPorId(id);
    }

    @GetMapping("/pagos")
    public List<Map<String, Object>> pagos(
            @RequestParam(required = false) Integer idPedido,
            @RequestParam(required = false) String estado,
            @RequestParam(defaultValue = "100") int limite) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("id_pedido = ?", idPedido);
        where.agregarSiPresente("estado = ?", estado);
        return jdbc.queryForList(
                "SELECT id_pago, id_pedido, fecha_pago, valor, medio_pago, estado "
                        + "FROM pagos" + where.clausula() + " ORDER BY id_pago DESC LIMIT ?",
                where.params(SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
    }

    @PostMapping("/pagos")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> registrarPago(@RequestBody PagoRequest req) {
        Integer existe = jdbc.queryForObject(
                "SELECT COUNT(*) FROM pedidos_venta WHERE id_pedido = ?",
                Integer.class, req.idPedido());
        if (existe == null || existe == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "Pedido " + req.idPedido() + " no encontrado");
        }
        int id = req.idPago() != null
                ? req.idPago()
                : SqlUtils.siguienteId(jdbc, "pagos", "id_pago");
        LocalDate fecha = req.fechaPago() != null ? req.fechaPago() : LocalDate.now();
        String estado = (req.estado() == null || req.estado().isBlank()) ? "Confirmado" : req.estado();

        jdbc.update(
                "INSERT INTO pagos (id_pago, id_pedido, fecha_pago, valor, medio_pago, estado) "
                        + "VALUES (?, ?, ?, ?, ?, ?)",
                id, req.idPedido(), fecha, req.valor(), req.medioPago(), estado);
        return jdbc.queryForMap(
                "SELECT id_pago, id_pedido, fecha_pago, valor, medio_pago, estado FROM pagos WHERE id_pago = ?",
                id);
    }

    @GetMapping("/devoluciones")
    public List<Map<String, Object>> devoluciones(
            @RequestParam(required = false) String estado,
            @RequestParam(defaultValue = "100") int limite) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("d.estado = ?", estado);
        return jdbc.queryForList(
                "SELECT d.id_devolucion, d.id_pedido, d.fecha_solicitud, d.motivo, d.estado, "
                        + "COALESCE(SUM(dd.cantidad), 0) AS unidades_devueltas "
                        + "FROM devoluciones d "
                        + "LEFT JOIN detalle_devolucion dd ON dd.id_devolucion = d.id_devolucion"
                        + where.clausula()
                        + " GROUP BY d.id_devolucion, d.id_pedido, d.fecha_solicitud, d.motivo, d.estado "
                        + "ORDER BY d.id_devolucion DESC LIMIT ?",
                where.params(SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
    }

    public record DetallePedidoRequest(Integer idProducto, Integer cantidad, BigDecimal precioUnitario) {
    }

    public record PedidoRequest(
            Integer idPedido,
            Integer idSede,
            Integer idAlmacen,
            Integer idCliente,
            Integer idEmpleado,
            LocalDate fechaPedido,
            String estado,
            List<DetallePedidoRequest> detalles) {
    }

    public record PagoRequest(
            Integer idPago,
            Integer idPedido,
            LocalDate fechaPago,
            BigDecimal valor,
            String medioPago,
            String estado) {
    }
}
