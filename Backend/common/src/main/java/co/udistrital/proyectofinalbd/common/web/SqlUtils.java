package co.udistrital.proyectofinalbd.common.web;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Utilidades SQL compartidas para los controladores JDBC de los microservicios.
 */
public final class SqlUtils {

    private static final Pattern IDENTIFICADOR_SEGURO = Pattern.compile("[a-z_][a-z0-9_]*");

    private SqlUtils() {
    }

    /**
     * Calcula el siguiente identificador entero para tablas cuya clave primaria
     * es {@code INT} sin secuencia automática.
     */
    public static int siguienteId(JdbcTemplate jdbc, String tabla, String columnaId) {
        validarIdentificador(tabla);
        validarIdentificador(columnaId);
        Integer siguiente = jdbc.queryForObject(
                "SELECT COALESCE(MAX(" + columnaId + "), 0) + 1 FROM " + tabla,
                Integer.class);
        return siguiente == null ? 1 : siguiente;
    }

    /**
     * Limita el tamaño de página entre 1 y {@code maximo}.
     */
    public static int acotarLimite(int limite, int maximo) {
        return Math.max(1, Math.min(limite, maximo));
    }

    /**
     * Construye dinámicamente cláusulas {@code WHERE} seguras con parámetros enlazados.
     */
    public static final class WhereBuilder {
        private final List<String> condiciones = new ArrayList<>();
        private final List<Object> parametros = new ArrayList<>();

        public void agregarSiPresente(String condicionSql, Object valor) {
            if (valor == null) {
                return;
            }
            if (valor instanceof String texto && texto.isBlank()) {
                return;
            }
            condiciones.add(condicionSql);
            parametros.add(valor);
        }

        public void agregarCondicion(String condicionSql) {
            condiciones.add(condicionSql);
        }

        public String clausula() {
            return condiciones.isEmpty() ? "" : " WHERE " + String.join(" AND ", condiciones);
        }

        public Object[] params(Object... extras) {
            if (extras.length == 0) {
                return parametros.toArray();
            }
            List<Object> todos = new ArrayList<>(parametros);
            for (Object extra : extras) {
                todos.add(extra);
            }
            return todos.toArray();
        }
    }

    private static void validarIdentificador(String identificador) {
        if (identificador == null || !IDENTIFICADOR_SEGURO.matcher(identificador).matches()) {
            throw new IllegalArgumentException("Identificador SQL inválido: " + identificador);
        }
    }
}
