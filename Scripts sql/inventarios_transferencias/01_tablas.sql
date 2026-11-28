-- ============================================================================
-- MICROSERVICIO: inventarios_transferencias   (instancia/base independiente)
-- 01. Creación de tablas + fragmentación horizontal LIST por id_sede
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

-- Tabla particionada declarativamente por sede (5 fragmentos disjuntos y completos)
CREATE TABLE inventarios (
    id_sede             INT,  -- clave de particionamiento LIST y ref. lógica a sedes
    id_almacen          INT,  -- referencia lógica a catalogo_terceros.almacenes
    id_producto         INT,  -- referencia lógica a catalogo_terceros.productos
    existencia_actual   INT,
    stock_minimo        INT,
    fecha_actualizacion DATE
) PARTITION BY LIST (id_sede);

-- Fragmentos físicos por sede (correspondientes a sedes 1..5)
CREATE TABLE inventarios_sede_1 PARTITION OF inventarios FOR VALUES IN (1);
CREATE TABLE inventarios_sede_2 PARTITION OF inventarios FOR VALUES IN (2);
CREATE TABLE inventarios_sede_3 PARTITION OF inventarios FOR VALUES IN (3);
CREATE TABLE inventarios_sede_4 PARTITION OF inventarios FOR VALUES IN (4);
CREATE TABLE inventarios_sede_5 PARTITION OF inventarios FOR VALUES IN (5);

CREATE TABLE transferencias (
    id_transferencia   INT,
    id_almacen_origen  INT,  -- referencia lógica a catalogo_terceros.almacenes
    id_almacen_destino INT,  -- referencia lógica a catalogo_terceros.almacenes
    fecha_solicitud    DATE,
    fecha_despacho     DATE,
    fecha_recepcion    DATE,
    estado             VARCHAR(20)
);

CREATE TABLE detalle_transferencia (
    id_transferencia  INT,
    id_producto       INT,  -- referencia lógica a catalogo_terceros.productos
    cantidad_enviada  INT,
    cantidad_recibida INT
);
