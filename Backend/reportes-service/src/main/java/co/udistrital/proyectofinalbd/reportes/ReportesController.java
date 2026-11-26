package co.udistrital.proyectofinalbd.reportes;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;
import org.springframework.web.server.ResponseStatusException;

import co.udistrital.proyectofinalbd.common.web.SqlUtils;

/**
 * Reportes corporativos: consulta vistas consolidadas en su base de datos
 * (p. ej. vía {@code postgres_fdw}) y, cuando no están disponibles, compone la
 * respuesta consultando por HTTP los endpoints de los demás microservicios.
 */
@RestController
@RequestMapping("/api/reportes")
public class ReportesController {

    private static final int LIMITE_MAXIMO = 200;

    private final JdbcTemplate jdbc;
    private final Map<String, String> servicios = new LinkedHashMap<>();
    private final SimpleClientHttpRequestFactory requestFactory;

    public ReportesController(
            JdbcTemplate jdbc,
            @Value("${app.servicios.catalogo}") String catalogo,
            @Value("${app.servicios.compras}") String compras,
            @Value("${app.servicios.inventarios}") String inventarios,
            @Value("${app.servicios.ventas}") String ventas,
            @Value("${app.servicios.identidad}") String identidad) {
        this.jdbc = jdbc;
        servicios.put("catalogo", catalogo);
        servicios.put("compras", compras);
        servicios.put("inventarios", inventarios);
        servicios.put("ventas", ventas);
        servicios.put("identidad", identidad);

        this.requestFactory = new SimpleClientHttpRequestFactory();
        this.requestFactory.setConnectTimeout(4000);
        this.requestFactory.setReadTimeout(20000);
    }

    @GetMapping("/resumen")
    public Map<String, Object> resumen() {
        Map<String, Object> respuesta = new LinkedHashMap<>();
        servicios.forEach((nombre, url) -> respuesta.put(nombre, consultarJson(url, "/api/resumen", Map.class)));
        return respuesta;
    }

    @GetMapping("/vistas")
    public List<Map<String, Object>> listarVistas() {
        return jdbc.queryForList("""
                SELECT table_schema AS esquema, table_name AS vista
                  FROM information_schema.views
                 WHERE table_schema IN (current_schema(), 'reportes')
                 ORDER BY table_schema, table_name
                """);
    }

    @GetMapping("/vistas/{vista}")
    public List<Map<String, Object>> consultarVista(
            @PathVariable String vista,
            @RequestParam(defaultValue = "100") int limite) {
        Map<String, Object> encontrada = buscarVista(vista);
        if (encontrada == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "La vista '" + vista + "' no existe en la base de reportes");
        }
        String esquema = String.valueOf(encontrada.get("table_schema"));
        String nombre = String.valueOf(encontrada.get("table_name"));
        int filas = SqlUtils.acotarLimite(limite, LIMITE_MAXIMO);
        return jdbc.queryForList(
                "SELECT * FROM " + citar(esquema) + "." + citar(nombre) + " LIMIT " + filas);
    }

    @GetMapping("/corporativo")
    public Map<String, Object> corporativo() {
        Map<String, Object> vista = buscarVista("vista_reporte_corporativo");
        if (vista != null) {
            List<Map<String, Object>> filas = consultarVista("vista_reporte_corporativo", LIMITE_MAXIMO);
            Map<String, Object> respuesta = new LinkedHashMap<>();
            respuesta.put("fuente", "postgres_vista");
            respuesta.put("datos", filas);
            return respuesta;
        }

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("fuente", "composicion_http");
        respuesta.put("sedes", consultarJson(servicios.get("catalogo"), "/api/sedes", List.class));
        respuesta.put("inventariosPorSede",
                consultarJson(servicios.get("inventarios"), "/api/inventarios/por-sede", List.class));
        respuesta.put("resumenTablas", resumen());
        return respuesta;
    }

    @GetMapping("/alertas")
    public Map<String, Object> alertas(@RequestParam(defaultValue = "100") int limite) {
        Map<String, Object> vista = buscarVista("vista_alertas_reabastecimiento");
        if (vista != null) {
            Map<String, Object> respuesta = new LinkedHashMap<>();
            respuesta.put("fuente", "postgres_vista");
            respuesta.put("datos", consultarVista("vista_alertas_reabastecimiento", limite));
            return respuesta;
        }

        int acotado = SqlUtils.acotarLimite(limite, LIMITE_MAXIMO);
        Object datos = consultarJson(servicios.get("inventarios"),
                "/api/inventarios?soloAlertas=true&limite=" + acotado, List.class);
        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("fuente", "composicion_http");
        respuesta.put("datos", datos);
        return respuesta;
    }

    @GetMapping("/saldos-pendientes")
    public Map<String, Object> saldosPendientes(@RequestParam(defaultValue = "100") int limite) {
        Map<String, Object> vista = buscarVista("vista_saldos_pendientes");
        if (vista != null) {
            Map<String, Object> respuesta = new LinkedHashMap<>();
            respuesta.put("fuente", "postgres_vista");
            respuesta.put("datos", consultarVista("vista_saldos_pendientes", limite));
            return respuesta;
        }

        Object pedidosObj = consultarJson(servicios.get("ventas"),
                "/api/pedidos?limite=" + SqlUtils.acotarLimite(limite, LIMITE_MAXIMO), List.class);
        Object datos = pedidosObj;
        if (pedidosObj instanceof List<?> lista) {
            datos = lista.stream()
                    .filter(item -> item instanceof Map<?, ?> map && tieneSaldoPositivo(map.get("saldo_pendiente")))
                    .toList();
        }
        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("fuente", "composicion_http");
        respuesta.put("datos", datos);
        return respuesta;
    }

    private Map<String, Object> buscarVista(String vista) {
        try {
            List<Map<String, Object>> filas = jdbc.queryForList("""
                    SELECT table_schema, table_name
                      FROM information_schema.views
                     WHERE table_schema IN (current_schema(), 'reportes')
                       AND table_name = ?
                     ORDER BY CASE WHEN table_schema = current_schema() THEN 0 ELSE 1 END
                     LIMIT 1
                    """, vista);
            return filas.isEmpty() ? null : filas.get(0);
        } catch (Exception ex) {
            return null;
        }
    }

    private boolean tieneSaldoPositivo(Object saldo) {
        if (saldo instanceof Number num) {
            return new BigDecimal(num.toString()).compareTo(BigDecimal.ZERO) > 0;
        }
        return false;
    }

    private Object consultarJson(String baseUrl, String uri, Class<?> tipo) {
        try {
            return RestClient.builder()
                    .requestFactory(requestFactory)
                    .baseUrl(normalizar(baseUrl))
                    .build()
                    .get()
                    .uri(uri)
                    .retrieve()
                    .body(tipo);
        } catch (Exception ex) {
            Map<String, Object> error = new LinkedHashMap<>();
            error.put("url", baseUrl + uri);
            error.put("error", ex.getMessage());
            return error;
        }
    }

    /**
     * Render entrega el host sin esquema (por ejemplo
     * {@code catalogo-service.onrender.com}); en local se usa una URL completa.
     */
    private String normalizar(String url) {
        if (url == null || url.isBlank()) {
            return "http://localhost";
        }
        String limpia = url.trim();
        return limpia.startsWith("http://") || limpia.startsWith("https://")
                ? limpia
                : "https://" + limpia;
    }

    private String citar(String identificador) {
        return '"' + identificador.replace("\"", "\"\"") + '"';
    }
}
