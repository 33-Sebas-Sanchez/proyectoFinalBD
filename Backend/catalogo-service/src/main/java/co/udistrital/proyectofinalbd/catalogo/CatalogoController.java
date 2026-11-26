package co.udistrital.proyectofinalbd.catalogo;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import co.udistrital.proyectofinalbd.common.web.SqlUtils;
import co.udistrital.proyectofinalbd.common.web.SqlUtils.WhereBuilder;

/**
 * Endpoints REST de dominio para el microservicio de catálogo y terceros.
 */
@RestController
@RequestMapping("/api")
public class CatalogoController {

    private static final int LIMITE_MAXIMO = 200;

    private final JdbcTemplate jdbc;

    public CatalogoController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/sedes")
    public List<Map<String, Object>> sedes(@RequestParam(required = false) String estado) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("estado = ?", estado);
        return jdbc.queryForList(
                "SELECT id_sede, nombre_sede, ciudad, direccion, tipo_sede, estado "
                        + "FROM sedes" + where.clausula() + " ORDER BY id_sede",
                where.params());
    }

    @GetMapping("/almacenes")
    public List<Map<String, Object>> almacenes(
            @RequestParam(required = false) Integer idSede,
            @RequestParam(required = false) String estado) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("a.id_sede = ?", idSede);
        where.agregarSiPresente("a.estado = ?", estado);
        return jdbc.queryForList(
                "SELECT a.id_almacen, a.id_sede, s.nombre_sede, a.nombre_almacen, a.tipo_almacen, a.estado "
                        + "FROM almacenes a JOIN sedes s ON s.id_sede = a.id_sede"
                        + where.clausula() + " ORDER BY a.id_almacen",
                where.params());
    }

    @GetMapping("/categorias")
    public List<Map<String, Object>> categorias(@RequestParam(required = false) String estado) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("estado = ?", estado);
        return jdbc.queryForList(
                "SELECT id_categoria, nombre_categoria, descripcion, estado "
                        + "FROM categorias" + where.clausula() + " ORDER BY id_categoria",
                where.params());
    }

    @GetMapping("/productos")
    public List<Map<String, Object>> productos(
            @RequestParam(required = false) Integer idCategoria,
            @RequestParam(required = false) String estado,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "100") int limite) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("p.id_categoria = ?", idCategoria);
        where.agregarSiPresente("p.estado = ?", estado);
        if (q != null && !q.isBlank()) {
            String patron = "%" + q.trim() + "%";
            where.agregarCondicion("(p.nombre ILIKE ? OR p.sku ILIKE ?)");
            // Agrega ambos parámetros manualmente mediante una consulta con los dos valores
            return jdbc.queryForList(
                    "SELECT p.id_producto, p.sku, p.nombre, p.id_categoria, c.nombre_categoria, "
                            + "p.unidad_medida, p.precio_lista, p.estado "
                            + "FROM productos p JOIN categorias c ON c.id_categoria = p.id_categoria"
                            + where.clausula() + " ORDER BY p.id_producto LIMIT ?",
                    where.params(patron, patron, SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
        }
        return jdbc.queryForList(
                "SELECT p.id_producto, p.sku, p.nombre, p.id_categoria, c.nombre_categoria, "
                        + "p.unidad_medida, p.precio_lista, p.estado "
                        + "FROM productos p JOIN categorias c ON c.id_categoria = p.id_categoria"
                        + where.clausula() + " ORDER BY p.id_producto LIMIT ?",
                where.params(SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
    }

    @GetMapping("/productos/{id}")
    public Map<String, Object> productoPorId(@PathVariable int id) {
        List<Map<String, Object>> filas = jdbc.queryForList(
                "SELECT p.id_producto, p.sku, p.nombre, p.id_categoria, c.nombre_categoria, "
                        + "p.unidad_medida, p.precio_lista, p.estado "
                        + "FROM productos p JOIN categorias c ON c.id_categoria = p.id_categoria "
                        + "WHERE p.id_producto = ?",
                id);
        if (filas.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Producto " + id + " no encontrado");
        }
        return filas.get(0);
    }

    @PostMapping("/productos")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crearProducto(@RequestBody ProductoRequest req) {
        int id = req.idProducto() != null
                ? req.idProducto()
                : SqlUtils.siguienteId(jdbc, "productos", "id_producto");
        String estado = (req.estado() == null || req.estado().isBlank()) ? "Activo" : req.estado();
        jdbc.update(
                "INSERT INTO productos (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?)",
                id, req.sku(), req.nombre(), req.idCategoria(), req.unidadMedida(), req.precioLista(), estado);
        return productoPorId(id);
    }

    @PutMapping("/productos/{id}")
    @Transactional
    public Map<String, Object> actualizarProducto(@PathVariable int id, @RequestBody ProductoRequest req) {
        int actualizados = jdbc.update(
                "UPDATE productos SET sku = ?, nombre = ?, id_categoria = ?, "
                        + "unidad_medida = ?, precio_lista = ?, estado = ? WHERE id_producto = ?",
                req.sku(), req.nombre(), req.idCategoria(), req.unidadMedida(),
                req.precioLista(), req.estado(), id);
        if (actualizados == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Producto " + id + " no encontrado");
        }
        return productoPorId(id);
    }

    @GetMapping("/proveedores")
    public List<Map<String, Object>> proveedores(@RequestParam(required = false) String estado) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("estado = ?", estado);
        return jdbc.queryForList(
                "SELECT id_proveedor, identificacion_proveedor, razon_social, ciudad_proveedor, "
                        + "correo_proveedor, telefono_proveedor, estado "
                        + "FROM proveedores" + where.clausula() + " ORDER BY id_proveedor",
                where.params());
    }

    @GetMapping("/productos/{id}/proveedores")
    public List<Map<String, Object>> proveedoresPorProducto(@PathVariable int id) {
        return jdbc.queryForList(
                "SELECT pp.id_producto, pp.id_proveedor, pr.razon_social, pr.ciudad_proveedor, "
                        + "pp.costo_referencia, pp.plazo_entrega "
                        + "FROM producto_proveedor pp "
                        + "JOIN proveedores pr ON pr.id_proveedor = pp.id_proveedor "
                        + "WHERE pp.id_producto = ? ORDER BY pp.costo_referencia",
                id);
    }

    @GetMapping("/clientes")
    public List<Map<String, Object>> clientes(
            @RequestParam(required = false) String estado,
            @RequestParam(defaultValue = "100") int limite) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("estado = ?", estado);
        return jdbc.queryForList(
                "SELECT id_cliente, tipo_documento, num_documento, nombre_completo_cliente, "
                        + "correo_cliente, telefono_cliente, estado "
                        + "FROM clientes" + where.clausula() + " ORDER BY id_cliente LIMIT ?",
                where.params(SqlUtils.acotarLimite(limite, LIMITE_MAXIMO)));
    }

    @PostMapping("/clientes")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public Map<String, Object> crearCliente(@RequestBody ClienteRequest req) {
        int id = req.idCliente() != null
                ? req.idCliente()
                : SqlUtils.siguienteId(jdbc, "clientes", "id_cliente");
        String estado = (req.estado() == null || req.estado().isBlank()) ? "Activo" : req.estado();
        jdbc.update(
                "INSERT INTO clientes (id_cliente, tipo_documento, num_documento, nombre_completo_cliente, "
                        + "correo_cliente, telefono_cliente, estado) VALUES (?, ?, ?, ?, ?, ?, ?)",
                id, req.tipoDocumento(), req.numDocumento(), req.nombreCompleto(),
                req.correo(), req.telefono(), estado);
        return jdbc.queryForMap(
                "SELECT id_cliente, tipo_documento, num_documento, nombre_completo_cliente, "
                        + "correo_cliente, telefono_cliente, estado FROM clientes WHERE id_cliente = ?",
                id);
    }

    public record ProductoRequest(
            Integer idProducto,
            String sku,
            String nombre,
            Integer idCategoria,
            String unidadMedida,
            BigDecimal precioLista,
            String estado) {
    }

    public record ClienteRequest(
            Integer idCliente,
            String tipoDocumento,
            Long numDocumento,
            String nombreCompleto,
            String correo,
            Long telefono,
            String estado) {
    }
}
