package co.udistrital.proyectofinalbd.common.web;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * Explorador de solo lectura sobre las tablas del esquema {@code public} de la
 * base de datos del microservicio.
 *
 * <p>No conoce nombres de tablas ni de columnas: los descubre en
 * {@code information_schema}, de modo que el servicio sigue funcionando
 * cuando el equipo cambia los scripts SQL. El nombre recibido se valida
 * contra el catálogo antes de interpolarlo en la consulta.</p>
 */
@RestController
@RequestMapping("/api")
public class TablasController {

    private static final int LIMITE_MAXIMO = 200;

    private final JdbcTemplate jdbcTemplate;

    public TablasController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/tablas")
    public List<Map<String, Object>> tablas() {
        return jdbcTemplate.queryForList("""
                select table_name as tabla, table_type as tipo
                  from information_schema.tables
                 where table_schema = 'public'
                 order by table_name
                """);
    }

    @GetMapping("/resumen")
    public Map<String, Object> resumen() {
        Map<String, Object> respuesta = new LinkedHashMap<>();
        for (String tabla : nombresDeTablas()) {
            respuesta.put(tabla, contar(tabla));
        }
        return respuesta;
    }

    @GetMapping("/tablas/{tabla}")
    public List<Map<String, Object>> filas(
            @PathVariable String tabla,
            @RequestParam(defaultValue = "50") int limite) {
        String nombre = validarTabla(tabla);
        int filas = Math.max(1, Math.min(limite, LIMITE_MAXIMO));
        return jdbcTemplate.queryForList(
                "select * from " + citar(nombre) + " limit " + filas);
    }

    private List<String> nombresDeTablas() {
        return jdbcTemplate.queryForList("""
                select table_name
                  from information_schema.tables
                 where table_schema = 'public' and table_type = 'BASE TABLE'
                 order by table_name
                """, String.class);
    }

    private String validarTabla(String tabla) {
        List<String> existentes = jdbcTemplate.queryForList("""
                select table_name
                  from information_schema.tables
                 where table_schema = 'public' and table_name = ?
                """, String.class, tabla);
        if (existentes.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,
                    "La tabla '" + tabla + "' no existe en este microservicio");
        }
        return existentes.get(0);
    }

    private long contar(String tabla) {
        Long total = jdbcTemplate.queryForObject(
                "select count(*) from " + citar(tabla), Long.class);
        return total == null ? 0L : total;
    }

    private String citar(String identificador) {
        return '"' + identificador.replace("\"", "\"\"") + '"';
    }
}
