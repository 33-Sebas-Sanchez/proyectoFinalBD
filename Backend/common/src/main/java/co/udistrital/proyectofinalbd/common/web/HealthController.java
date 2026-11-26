package co.udistrital.proyectofinalbd.common.web;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Estado del microservicio y de su base de datos.
 *
 * <p>Siempre responde 200 para que Render pueda distinguir entre un proceso
 * vivo y un proceso caído. El estado real de PostgreSQL viaja en
 * {@code database.status}.</p>
 */
@RestController
@RequestMapping("/api")
public class HealthController {

    private final JdbcTemplate jdbcTemplate;
    private final String servicio;

    public HealthController(JdbcTemplate jdbcTemplate,
                            @Value("${spring.application.name:microservicio}") String servicio) {
        this.jdbcTemplate = jdbcTemplate;
        this.servicio = servicio;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> baseDeDatos = new LinkedHashMap<>();
        try {
            String version = jdbcTemplate.queryForObject("select version()", String.class);
            baseDeDatos.put("status", "up");
            baseDeDatos.put("version", version == null ? "" : version.split(" on ")[0]);
        } catch (DataAccessException ex) {
            baseDeDatos.put("status", "down");
            baseDeDatos.put("error", ex.getMostSpecificCause().getMessage());
        }

        Map<String, Object> respuesta = new LinkedHashMap<>();
        respuesta.put("status", "ok");
        respuesta.put("service", servicio);
        respuesta.put("database", baseDeDatos);
        return respuesta;
    }
}
