package co.udistrital.proyectofinalbd.common.web;

import java.sql.SQLException;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ApiExceptionHandlerTest {

    private final ApiExceptionHandler handler = new ApiExceptionHandler();

    @Test
    void traduceUniqueViolationAConflict409() {
        SQLException sqlEx = new SQLException("llave duplicada uq_productos_sku", "23505");
        DataIntegrityViolationException ex = new DataIntegrityViolationException("error", sqlEx);

        ResponseEntity<Map<String, Object>> respuesta = handler.manejarIntegridad(ex);

        assertEquals(HttpStatus.CONFLICT, respuesta.getStatusCode());
        assertEquals(409, respuesta.getBody().get("status"));
        assertTrue(String.valueOf(respuesta.getBody().get("mensaje")).contains("UNIQUE"));
    }

    @Test
    void traduceCheckViolationABadRequest400() {
        SQLException sqlEx = new SQLException("viola restricción check", "23514");
        DataIntegrityViolationException ex = new DataIntegrityViolationException("error", sqlEx);

        ResponseEntity<Map<String, Object>> respuesta = handler.manejarIntegridad(ex);

        assertEquals(HttpStatus.BAD_REQUEST, respuesta.getStatusCode());
        assertEquals(400, respuesta.getBody().get("status"));
        assertTrue(String.valueOf(respuesta.getBody().get("mensaje")).contains("CHECK"));
    }

    @Test
    void whereBuilderConstruyeParametrosSeguros() {
        SqlUtils.WhereBuilder where = new SqlUtils.WhereBuilder();
        where.agregarSiPresente("id_sede = ?", 2);
        where.agregarSiPresente("estado = ?", "   ");
        where.agregarCondicion("existencia_actual < stock_minimo");

        assertEquals(" WHERE id_sede = ? AND existencia_actual < stock_minimo", where.clausula());
        Object[] params = where.params(50);
        assertEquals(2, params.length);
        assertEquals(2, params[0]);
        assertEquals(50, params[1]);
    }

    @Test
    void acotarLimiteRespetaRango() {
        assertEquals(1, SqlUtils.acotarLimite(0, 200));
        assertEquals(200, SqlUtils.acotarLimite(999, 200));
        assertThrows(IllegalArgumentException.class,
                () -> SqlUtils.siguienteId(null, "productos; DROP TABLE sedes", "id_producto"));
    }
}
