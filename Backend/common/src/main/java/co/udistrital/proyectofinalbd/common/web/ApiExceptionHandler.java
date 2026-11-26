package co.udistrital.proyectofinalbd.common.web;

import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

/**
 * Traduce excepciones de PostgreSQL y de validación HTTP a respuestas JSON
 * legibles, evitando respuestas 500 genéricas cuando se violan restricciones
 * de integridad (UNIQUE, CHECK, FOREIGN KEY o NOT NULL).
 */
@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> manejarIntegridad(DataIntegrityViolationException ex) {
        SQLException sqlEx = buscarSqlException(ex);
        String sqlState = sqlEx == null ? null : sqlEx.getSQLState();
        String detalle = sqlEx == null ? ex.getMostSpecificCause().getMessage() : sqlEx.getMessage();

        HttpStatus status = HttpStatus.BAD_REQUEST;
        String mensaje = "Violación de restricción de integridad en la base de datos";

        if ("23505".equals(sqlState)) {
            status = HttpStatus.CONFLICT;
            mensaje = "Ya existe un registro con ese valor único (UNIQUE)";
        } else if ("23514".equals(sqlState)) {
            mensaje = "Los datos incumplen una regla de validación (CHECK)";
        } else if ("23503".equals(sqlState)) {
            mensaje = "Referencia inexistente o en uso (FOREIGN KEY)";
        } else if ("23502".equals(sqlState)) {
            mensaje = "Falta un campo obligatorio (NOT NULL)";
        }

        return responder(status, mensaje, detalle);
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, Object>> manejarAccesoDatos(DataAccessException ex) {
        Throwable causa = ex.getMostSpecificCause();
        return responder(HttpStatus.BAD_GATEWAY, "Error al consultar PostgreSQL",
                causa == null ? ex.getMessage() : causa.getMessage());
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> manejarArgumentoInvalido(IllegalArgumentException ex) {
        return responder(HttpStatus.BAD_REQUEST, ex.getMessage(), null);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, Object>> manejarJsonInvalido(HttpMessageNotReadableException ex) {
        return responder(HttpStatus.BAD_REQUEST, "Cuerpo JSON inválido o mal formado",
                ex.getMostSpecificCause().getMessage());
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> manejarResponseStatus(ResponseStatusException ex) {
        HttpStatus status = HttpStatus.valueOf(ex.getStatusCode().value());
        String mensaje = ex.getReason() == null ? status.getReasonPhrase() : ex.getReason();
        return responder(status, mensaje, null);
    }

    private ResponseEntity<Map<String, Object>> responder(HttpStatus status, String mensaje, String detalle) {
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("status", status.value());
        cuerpo.put("error", status.getReasonPhrase());
        cuerpo.put("mensaje", mensaje);
        if (detalle != null && !detalle.isBlank()) {
            cuerpo.put("detalle", detalle);
        }
        return ResponseEntity.status(status).body(cuerpo);
    }

    private SQLException buscarSqlException(Throwable error) {
        Throwable actual = error;
        while (actual != null) {
            if (actual instanceof SQLException sqlEx) {
                return sqlEx;
            }
            actual = actual.getCause();
        }
        return null;
    }
}
