-- ============================================================================
-- MICROSERVICIO: identidad_accesos
-- 02. Restricciones (ALTER TABLE / ALTER COLUMN) + claves foráneas INTERNAS
-- Motor: PostgreSQL (Neon)
-- ============================================================================

-- ---------------------- empleados ------------------------------------------
ALTER TABLE empleados ALTER COLUMN id_sede         SET NOT NULL;
ALTER TABLE empleados ALTER COLUMN num_documento   SET NOT NULL;
ALTER TABLE empleados ALTER COLUMN nombre_completo SET NOT NULL;
ALTER TABLE empleados ALTER COLUMN cargo           SET NOT NULL;
ALTER TABLE empleados ALTER COLUMN correo          SET NOT NULL;
ALTER TABLE empleados ALTER COLUMN estado          SET NOT NULL;
ALTER TABLE empleados ALTER COLUMN estado          SET DEFAULT 'Activo';
ALTER TABLE empleados ADD CONSTRAINT pk_empleados PRIMARY KEY (id_empleado);
ALTER TABLE empleados ADD CONSTRAINT uq_empleados_num_documento UNIQUE (num_documento);
ALTER TABLE empleados ADD CONSTRAINT ck_empleados_estado CHECK (estado IN ('Activo', 'Inactivo'));
-- (sin FK a sedes: referencia lógica a catalogo_terceros.sedes, validada por app)

-- ---------------------- usuarios -------------------------------------------
ALTER TABLE usuarios ALTER COLUMN id_empleado    SET NOT NULL;
ALTER TABLE usuarios ALTER COLUMN nombre_usuario SET NOT NULL;
ALTER TABLE usuarios ALTER COLUMN password_hash  SET NOT NULL;
ALTER TABLE usuarios ALTER COLUMN rol            SET NOT NULL;
ALTER TABLE usuarios ALTER COLUMN estado         SET NOT NULL;
ALTER TABLE usuarios ALTER COLUMN estado         SET DEFAULT 'Activo';
ALTER TABLE usuarios ALTER COLUMN fecha_creacion SET NOT NULL;
ALTER TABLE usuarios ADD CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario);
ALTER TABLE usuarios ADD CONSTRAINT uq_usuarios_id_empleado UNIQUE (id_empleado);
ALTER TABLE usuarios ADD CONSTRAINT uq_usuarios_nombre_usuario UNIQUE (nombre_usuario);
ALTER TABLE usuarios ADD CONSTRAINT ck_usuarios_rol CHECK (rol IN ('Administrador', 'Gerencia', 'Inventario', 'Compras', 'Vendedor', 'Auditor'));
ALTER TABLE usuarios ADD CONSTRAINT ck_usuarios_estado CHECK (estado IN ('Activo', 'Inactivo'));
-- FK INTERNA
ALTER TABLE usuarios ADD CONSTRAINT fk_usuarios_empleado
    FOREIGN KEY (id_empleado) REFERENCES empleados (id_empleado);

-- ---------------------- auditoria_accesos ----------------------------------
ALTER TABLE auditoria_accesos ALTER COLUMN id_usuario        SET NOT NULL;
ALTER TABLE auditoria_accesos ALTER COLUMN fecha_hora        SET NOT NULL;
ALTER TABLE auditoria_accesos ALTER COLUMN accion            SET NOT NULL;
ALTER TABLE auditoria_accesos ALTER COLUMN objeto_consultado SET NOT NULL;
ALTER TABLE auditoria_accesos ADD CONSTRAINT pk_auditoria_accesos PRIMARY KEY (id_auditoria);
-- FK INTERNA
ALTER TABLE auditoria_accesos ADD CONSTRAINT fk_auditoria_usuario
    FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario);
