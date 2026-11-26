-- ============================================================================
-- MICROSERVICIO: identidad_accesos   (instancia/proyecto Neon independiente)
-- 01. Creación de tablas (solo columnas y tipos)
-- Motor: PostgreSQL (Neon)
-- ============================================================================

CREATE TABLE empleados (
    id_empleado     INT,
    id_sede         INT,   -- referencia lógica a catalogo_terceros.sedes (otra base)
    num_documento   BIGINT,
    nombre_completo VARCHAR(60),
    cargo           VARCHAR(50),
    correo          VARCHAR(50),
    estado          VARCHAR(10)
);

CREATE TABLE usuarios (
    id_usuario     INT,
    id_empleado    INT,
    nombre_usuario VARCHAR(50),
    password_hash  VARCHAR(255),
    rol            VARCHAR(20),
    estado         VARCHAR(10),
    fecha_creacion DATE
);

CREATE TABLE auditoria_accesos (
    id_auditoria      INT,
    id_usuario        INT,
    fecha_hora        DATE,
    accion            VARCHAR(50),
    objeto_consultado VARCHAR(80)
);
