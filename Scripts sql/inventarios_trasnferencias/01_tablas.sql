-- ============================================================================
-- MICROSERVICIO: inventarios_transferencias   (instancia/proyecto Neon independiente)
-- 01. Creación de tablas (solo columnas y tipos)
-- Motor: PostgreSQL (Neon)
-- ============================================================================

CREATE TABLE inventarios (
    id_sede             INT,  -- referencia lógica a catalogo_terceros.sedes
    id_almacen          INT,  -- referencia lógica a catalogo_terceros.almacenes
    id_producto         INT,  -- referencia lógica a catalogo_terceros.productos
    existencia_actual   INT,
    stock_minimo        INT,
    fecha_actualizacion DATE
);

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
