package co.udistrital.proyectofinalbd.compras;

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
 * Endpoints REST de órdenes de compra y recepciones para el microservicio de
 * compras y abastecimiento.
 */
@RestController
@RequestMapping("/api")
public class ComprasController {

    private static final int LIMITE_MAXIMO = 200;

    private final JdbcTemplate jdbc;

    public ComprasController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/ordenes-compra")
    public List<Map<String, Object>> ordenesCompra(
            @RequestParam(required = false) String estado,
            @RequestParam(required = false) Integer idProveedor,
            @RequestParam(defaultValue = "100") int limite) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("oc.estado = ?", estado);
        where.agregarSiPresente("oc.id_proveedor = ?", idProveedor);
        return jdbc.queryForList(
                "SELECT oc.id_orden_compra, oc.id_proveedor, oc.id_almacen_destino, oc.id_empleado, "
                        + "oc.fecha_orden, oc.fecha_estimada, oc.estado, "
                        + "COALESCE(SUM(d.cantidad_solicitada * d.costo_unitario), 0) AS total_orden "
                        + "FROM ordenes_compra oc "
                        + "LEFT JOIN detalle_orden_compra d ON d.id_orden_compra = oc.id_orden_compra"
                        + where.clausula()
                        + " GROUP BY oc.id_orden_compra, oc.id_proveedor, oc.id_almacen_destino, "
                        + "oc.id_empleado, oc.fecha_orden, oc.fecha_estimada, oc.estado "
                        + "ORDER BY oc.id_orden_compra DESC LIMIT ?",
                where.params(SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
    }

    @GetMapping("/ordenes-compra/{id}")
    public Map<String, Object> ordenPorId(@PathVariable int id) {
        List<Map<String, Object>> ordenes = jdbc.queryForList(
                "SELECT id_orden_compra, id_proveedor, id_almacen_destino, id_empleado, "
                        + "fecha_orden, fecha_estimada, estado "
                        + "FROM ordenes_compra WHERE id_orden_compra = ?",
                id);
        if (ordenes.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Orden de compra " + id + " no encontrada");
        }
        List<Map<String, Object>> detalle = jdbc.queryForList(
                "SELECT id_orden_compra, id_producto, cantidad_solicitada, costo_unitario "
                        + "FROM detalle_orden_compra WHERE id_orden_compra = ? ORDER BY id_producto",
                id);
        List<Map<String, Object>> recepciones = jdbc.queryForList(
                "SELECT id_recepcion, id_orden_compra, fecha_recepcion, estado "
                        + "FROM recepciones_compra WHERE id_orden_compra = ? ORDER BY id_recepcion",
                id);

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("orden", ordenes.get(0));
        respuesta.put("detalle", detalle);
        respuesta.put("recepciones", recepciones);
        return respuesta;
    }

    @PostMapping("/ordenes-compra")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crearOrden(@RequestBody OrdenCompraRequest req) {
        if (req.detalles() == null || req.detalles().isEmpty()) {
            throw new IllegalArgumentException("La orden de compra debe incluir al menos un producto");
        }
        int id = req.idOrdenCompra() != null
                ? req.idOrdenCompra()
                : SqlUtils.siguienteId(jdbc, "ordenes_compra", "id_orden_compra");
        LocalDate fechaOrden = req.fechaOrden() != null ? req.fechaOrden() : LocalDate.now();
        LocalDate fechaEstimada = req.fechaEstimada() != null ? req.fechaEstimada() : fechaOrden.plusDays(5);
        String estado = (req.estado() == null || req.estado().isBlank()) ? "Pendiente" : req.estado();

        jdbc.update(
                "INSERT INTO ordenes_compra (id_orden_compra, id_proveedor, id_almacen_destino, "
                        + "id_empleado, fecha_orden, fecha_estimada, estado) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?)",
                id, req.idProveedor(), req.idAlmacenDestino(), req.idEmpleado(),
                fechaOrden, fechaEstimada, estado);

        for (DetalleOrdenRequest linea : req.detalles()) {
            jdbc.update(
                    "INSERT INTO detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario) "
                            + "VALUES (?, ?, ?, ?)",
                    id, linea.idProducto(), linea.cantidadSolicitada(), linea.costoUnitario());
        }
        return ordenPorId(id);
    }

    @PostMapping("/recepciones")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> registrarRecepcion(@RequestBody RecepcionRequest req) {
        if (req.detalles() == null || req.detalles().isEmpty()) {
            throw new IllegalArgumentException("La recepción debe incluir al menos un producto");
        }
        Integer existe = jdbc.queryForObject(
                "SELECT COUNT(*) FROM ordenes_compra WHERE id_orden_compra = ?",
                Integer.class, req.idOrdenCompra());
        if (existe == null || existe == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "Orden de compra " + req.idOrdenCompra() + " no encontrada");
        }

        int id = req.idRecepcion() != null
                ? req.idRecepcion()
                : SqlUtils.siguienteId(jdbc, "recepciones_compra", "id_recepcion");
        LocalDate fecha = req.fechaRecepcion() != null ? req.fechaRecepcion() : LocalDate.now();
        String estado = (req.estado() == null || req.estado().isBlank()) ? "Procesado" : req.estado();

        jdbc.update(
                "INSERT INTO recepciones_compra (id_recepcion, id_orden_compra, fecha_recepcion, estado) "
                        + "VALUES (?, ?, ?, ?)",
                id, req.idOrdenCompra(), fecha, estado);

        for (DetalleRecepcionRequest linea : req.detalles()) {
            jdbc.update(
                    "INSERT INTO detalle_recepcion (id_recepcion, id_producto, cantidad_recibida) VALUES (?, ?, ?)",
                    id, linea.idProducto(), linea.cantidadRecibida());
        }
        return ordenPorId(req.idOrdenCompra());
    }

    public record DetalleOrdenRequest(Integer idProducto, Integer cantidadSolicitada, BigDecimal costoUnitario) {
    }

    public record OrdenCompraRequest(
            Integer idOrdenCompra,
            Integer idProveedor,
            Integer idAlmacenDestino,
            Integer idEmpleado,
            LocalDate fechaOrden,
            LocalDate fechaEstimada,
            String estado,
            List<DetalleOrdenRequest> detalles) {
    }

    public record DetalleRecepcionRequest(Integer idProducto, Integer cantidadRecibida) {
    }

    public record RecepcionRequest(
            Integer idRecepcion,
            Integer idOrdenCompra,
            LocalDate fechaRecepcion,
            String estado,
            List<DetalleRecepcionRequest> detalles) {
    }
}
