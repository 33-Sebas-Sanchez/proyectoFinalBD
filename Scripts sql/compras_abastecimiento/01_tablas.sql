-- ============================================================================
-- MICROSERVICIO: compras_abastecimiento  
-- 01. Creación de tablas (solo columnas y tipos)
-- Motor: PostgreSQL (Neon)
-- ============================================================================

CREATE TABLE ordenes_compra (
    id_orden_compra    INT,
    id_proveedor       INT,   -- referencia lógica a catalogo_terceros.proveedores
    id_almacen_destino INT,   -- referencia lógica a catalogo_terceros.almacenes
    id_empleado        INT,   -- referencia lógica a identidad_accesos.empleados
    fecha_orden        DATE,
    fecha_estimada     DATE,
    estado             VARCHAR(20)
);

CREATE TABLE detalle_orden_compra (
    id_orden_compra     INT,
    id_producto         INT,  -- referencia lógica a catalogo_terceros.productos
    cantidad_solicitada INT,
    costo_unitario      NUMERIC(12,2)
);

CREATE TABLE recepciones_compra (
    id_recepcion    INT,
    id_orden_compra INT,
    fecha_recepcion DATE,
    estado          VARCHAR(20)
);

CREATE TABLE detalle_recepcion (
    id_recepcion      INT,
    id_producto       INT,  -- referencia lógica a catalogo_terceros.productos
    cantidad_recibida INT
);
