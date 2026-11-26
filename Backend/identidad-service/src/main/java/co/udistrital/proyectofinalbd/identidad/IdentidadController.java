package co.udistrital.proyectofinalbd.identidad;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import co.udistrital.proyectofinalbd.common.web.SqlUtils;
import co.udistrital.proyectofinalbd.common.web.SqlUtils.WhereBuilder;

/**
 * Endpoints REST de empleados, usuarios, auditoría y autenticación básica
 * para el microservicio de identidad y accesos.
 */
@RestController
@RequestMapping("/api")
public class IdentidadController {

    private static final int LIMITE_MAXIMO = 200;

    private final JdbcTemplate jdbc;

    public IdentidadController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping("/empleados")
    public List<Map<String, Object>> empleados(
            @RequestParam(required = false) Integer idSede,
            @RequestParam(required = false) String estado) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("id_sede = ?", idSede);
        where.agregarSiPresente("estado = ?", estado);
        return jdbc.queryForList(
                "SELECT id_empleado, id_sede, num_documento, nombre_completo, cargo, correo, estado "
                        + "FROM empleados" + where.clausula() + " ORDER BY id_empleado",
                where.params());
    }

    /**
     * Lista usuarios sin exponer el campo {@code password_hash}.
     */
    @GetMapping("/usuarios")
    public List<Map<String, Object>> usuarios(
            @RequestParam(required = false) String rol,
            @RequestParam(required = false) String estado) {
        WhereBuilder where = new WhereBuilder();
        where.agregarSiPresente("u.rol = ?", rol);
        where.agregarSiPresente("u.estado = ?", estado);
        return jdbc.queryForList(
                "SELECT u.id_usuario, u.id_empleado, e.nombre_completo, e.id_sede, "
                        + "u.nombre_usuario, u.rol, u.estado, u.fecha_creacion "
                        + "FROM usuarios u JOIN empleados e ON e.id_empleado = u.id_empleado"
                        + where.clausula() + " ORDER BY u.id_usuario",
                where.params());
    }

    @GetMapping("/auditoria")
    public List<Map<String, Object>> auditoria(@RequestParam(defaultValue = "50") int limite) {
        return jdbc.queryForList(
                "SELECT a.id_auditoria, a.id_usuario, u.nombre_usuario, u.rol, "
                        + "a.fecha_hora, a.accion, a.objeto_consultado "
                        + "FROM auditoria_accesos a "
                        + "JOIN usuarios u ON u.id_usuario = a.id_usuario "
                        + "ORDER BY a.fecha_hora DESC, a.id_auditoria DESC LIMIT ?",
                SqlUtils.acotarLimite(limite, LIMITE_MAXIMO));
    }

    /**
     * Valida credenciales contra {@code usuarios} (incluidos los hashes sintéticos
     * de {@code 03_datos.sql}) y registra el acceso en {@code auditoria_accesos}.
     */
    @PostMapping("/auth/login")
    @Transactional
    public Map<String, Object> login(@RequestBody LoginRequest req) {
        if (req.nombreUsuario() == null || req.nombreUsuario().isBlank()
                || req.password() == null || req.password().isBlank()) {
            throw new IllegalArgumentException("Debe indicar nombreUsuario y password");
        }

        List<Map<String, Object>> filas = jdbc.queryForList(
                "SELECT u.id_usuario, u.id_empleado, u.nombre_usuario, u.password_hash, "
                        + "u.rol, u.estado AS estado_usuario, "
                        + "e.nombre_completo, e.cargo, e.id_sede, e.estado AS estado_empleado "
                        + "FROM usuarios u JOIN empleados e ON e.id_empleado = u.id_empleado "
                        + "WHERE u.nombre_usuario = ?",
                req.nombreUsuario().trim());

        if (filas.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
        }

        Map<String, Object> usuario = filas.get(0);
        if (!"Activo".equals(usuario.get("estado_usuario"))
                || !"Activo".equals(usuario.get("estado_empleado"))) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Usuario o empleado inactivo");
        }

        String hashGuardado = String.valueOf(usuario.get("password_hash"));
        if (!coincidePassword(req.password(), hashGuardado)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Credenciales inválidas");
        }

        int idUsuario = ((Number) usuario.get("id_usuario")).intValue();
        int idAuditoria = SqlUtils.siguienteId(jdbc, "auditoria_accesos", "id_auditoria");
        jdbc.update(
                "INSERT INTO auditoria_accesos (id_auditoria, id_usuario, fecha_hora, accion, objeto_consultado) "
                        + "VALUES (?, ?, CURRENT_DATE, 'LOGIN', 'identidad_accesos.usuarios')",
                idAuditoria, idUsuario);

        Map<String, Object> sesion = new LinkedHashMap<>();
        sesion.put("idUsuario", idUsuario);
        sesion.put("idEmpleado", usuario.get("id_empleado"));
        sesion.put("nombreUsuario", usuario.get("nombre_usuario"));
        sesion.put("nombreCompleto", usuario.get("nombre_completo"));
        sesion.put("cargo", usuario.get("cargo"));
        sesion.put("rol", usuario.get("rol"));
        sesion.put("idSede", usuario.get("id_sede"));
        return sesion;
    }

    private boolean coincidePassword(String passwordPlano, String hashGuardado) {
        if (hashGuardado.equals(passwordPlano)) {
            return true;
        }
        String hashSintetico = "$2b$10$" + md5Hex(passwordPlano) + "00000";
        return hashSintetico.equals(hashGuardado);
    }

    private String md5Hex(String valor) {
        try {
            byte[] digest = MessageDigest.getInstance("MD5")
                    .digest(valor.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("MD5 no disponible", ex);
        }
    }

    public record LoginRequest(String nombreUsuario, String password) {
    }
}
