package co.udistrital.proyectofinalbd.inventarios;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
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
 * Endpoints REST de inventarios por sede/almacén, alertas de stock y
 * transferencias internas entre bodegas.
 */
@RestController
@RequestMapping("/api")
public class InventariosController {

    private static final int LIMITE_MAXIMO = 200;

    private final JdbcTemplate jdbc;

    public InventariosController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/inventarios")
    public List<Map<String, Object>> inventarios(
            @RequestParam(required = false) Integer idSede,
            @RequestParam(required = false) Integer idAlmacen,
            @RequestParam(defaultValue = "false") boolean soloAlertas,
            @RequestParam(defaultValue = "100") int limite) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("id_sede = ?", idSede);
        where.agregarSiPresente("id_almacen = ?", idAlmacen);
        if (soloAlertas) {
            where.agregarCondicion("(existencia_actual = 0 OR existencia_actual < stock_minimo)");
        }
        return jdbc.queryForList(
                "SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, "
                        + "(stock_minimo - existencia_actual) AS faltante, fecha_actualizacion "
                        + "FROM inventarios" + where.clausula()
                        + " ORDER BY id_sede, id_almacen, id_producto LIMIT ?",
                where.params(SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
    }

    @GetMapping("/inventarios/por-sede")
    public List<Map<String, Object>> resumenPorSede() {
        return jdbc.queryForList(
                "SELECT id_sede, COUNT(*) AS total_registros, "
                        + "COALESCE(SUM(existencia_actual), 0) AS unidades_totales, "
                        + "COUNT(*) FILTER (WHERE existencia_actual = 0 OR existencia_actual < stock_minimo) AS productos_en_alerta "
                        + "FROM inventarios GROUP BY id_sede ORDER BY id_sede");
    }

    @PatchMapping("/inventarios/{idAlmacen}/{idProducto}")
    @Transactional
    public Map<String, Object> actualizarStock(
            @PathVariable int idAlmacen,
            @PathVariable int idProducto,
            @RequestBody StockPatchRequest req) {
        if (req.existenciaActual() == null && req.stockMinimo() == null) {
            throw new IllegalArgumentException("Debe enviar existenciaActual o stockMinimo");
        }
        int actualizados = jdbc.update(
                "UPDATE inventarios SET "
                        + "existencia_actual = COALESCE(?, existencia_actual), "
                        + "stock_minimo = COALESCE(?, stock_minimo), "
                        + "fecha_actualizacion = CURRENT_DATE "
                        + "WHERE id_almacen = ? AND id_producto = ?",
                req.existenciaActual(), req.stockMinimo(), idAlmacen, idProducto);
        if (actualizados == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "No existe inventario para almacén " + idAlmacen + " y producto " + idProducto);
        }
        return jdbc.queryForMap(
                "SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion "
                        + "FROM inventarios WHERE id_almacen = ? AND id_producto = ?",
                idAlmacen, idProducto);
    }

    @GetMapping("/transferencias")
    public List<Map<String, Object>> transferencias(
            @RequestParam(required = false) String estado,
            @RequestParam(defaultValue = "100") int limite) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("estado = ?", estado);
        return jdbc.queryForList(
                "SELECT id_transferencia, id_almacen_origen, id_almacen_destino, "
                        + "fecha_solicitud, fecha_despacho, fecha_recepcion, estado "
                        + "FROM transferencias" + where.clausula()
                        + " ORDER BY id_transferencia DESC LIMIT ?",
                where.params(SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
    }

    @GetMapping("/transferencias/{id}")
    public Map<String, Object> transferenciaPorId(@PathVariable int id) {
        List<Map<String, Object>> filas = jdbc.queryForList(
                "SELECT id_transferencia, id_almacen_origen, id_almacen_destino, "
                        + "fecha_solicitud, fecha_despacho, fecha_recepcion, estado "
                        + "FROM transferencias WHERE id_transferencia = ?",
                id);
        if (filas.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Transferencia " + id + " no encontrada");
        }
        List<Map<String, Object>> detalle = jdbc.queryForList(
                "SELECT id_transferencia, id_producto, cantidad_enviada, cantidad_recibida "
                        + "FROM detalle_transferencia WHERE id_transferencia = ? ORDER BY id_producto",
                id);
        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("transferencia", filas.get(0));
        respuesta.put("detalle", detalle);
        return respuesta;
    }

    @PostMapping("/transferencias")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crearTransferencia(@RequestBody TransferenciaRequest req) {
        if (req.detalles() == null || req.detalles().isEmpty()) {
            throw new IllegalArgumentException("La transferencia debe incluir al menos un producto");
        }
        int id = req.idTransferencia() != null
                ? req.idTransferencia()
                : SqlUtils.siguienteId(jdbc, "transferencias", "id_transferencia");
        LocalDate fechaSolicitud = req.fechaSolicitud() != null ? req.fechaSolicitud() : LocalDate.now();
        String estado = (req.estado() == null || req.estado().isBlank()) ? "Solicitada" : req.estado();

        jdbc.update(
                "INSERT INTO transferencias (id_transferencia, id_almacen_origen, id_almacen_destino, "
                        + "fecha_solicitud, fecha_despacho, fecha_recepcion, estado) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?)",
                id, req.idAlmacenOrigen(), req.idAlmacenDestino(),
                fechaSolicitud, req.fechaDespacho(), req.fechaRecepcion(), estado);

        for (DetalleTransferenciaRequest linea : req.detalles()) {
            jdbc.update(
                    "INSERT INTO detalle_transferencia (id_transferencia, id_producto, cantidad_enviada, cantidad_recibida) "
                            + "VALUES (?, ?, ?, ?)",
                    id, linea.idProducto(), linea.cantidadEnviada(), linea.cantidadRecibida());
        }
        return transferenciaPorId(id);
    }

    public record StockPatchRequest(Integer existenciaActual, Integer stockMinimo) {
    }

    public record DetalleTransferenciaRequest(Integer idProducto, Integer cantidadEnviada, Integer cantidadRecibida) {
    }

    public record TransferenciaRequest(
            Integer idTransferencia,
            Integer idAlmacenOrigen,
            Integer idAlmacenDestino,
            LocalDate fechaSolicitud,
            LocalDate fechaDespacho,
            LocalDate fechaRecepcion,
            String estado,
            List<DetalleTransferenciaRequest> detalles) {
    }
}
