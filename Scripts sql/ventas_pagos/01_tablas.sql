-- ============================================================================
-- MICROSERVICIO: ventas_pagos   (instancia/base independiente)
-- 01. Creación de tablas + fragmentación horizontal LIST por id_sede
-- Motor: PostgreSQL 18 / Neon
-- ============================================================================

-- Tabla particionada declarativamente por sede (5 fragmentos disjuntos y completos)
CREATE TABLE pedidos_venta (
    id_pedido        INT,
    id_sede          INT,  -- clave de particionamiento LIST y ref. lógica a sedes
    id_almacen       INT,  -- referencia lógica a catalogo_terceros.almacenes
    id_cliente       INT,  -- referencia lógica a catalogo_terceros.clientes
    id_empleado      INT,  -- referencia lógica a identidad_accesos.empleados
    fecha_pedido     DATE,
    estado           VARCHAR(20),
    total_registrado NUMERIC(12,2)
) PARTITION BY LIST (id_sede);

-- Fragmentos físicos por sede (correspondientes a sedes 1..5)
CREATE TABLE pedidos_venta_sede_1 PARTITION OF pedidos_venta FOR VALUES IN (1);
CREATE TABLE pedidos_venta_sede_2 PARTITION OF pedidos_venta FOR VALUES IN (2);
CREATE TABLE pedidos_venta_sede_3 PARTITION OF pedidos_venta FOR VALUES IN (3);
CREATE TABLE pedidos_venta_sede_4 PARTITION OF pedidos_venta FOR VALUES IN (4);
CREATE TABLE pedidos_venta_sede_5 PARTITION OF pedidos_venta FOR VALUES IN (5);

CREATE TABLE detalle_pedido (
    id_sede         INT,
    id_pedido       INT,
    id_producto     INT,  -- referencia lógica a catalogo_terceros.productos
    cantidad        INT,
    precio_unitario NUMERIC(12,2)
);

CREATE TABLE pagos (
    id_pago    INT,
    id_sede    INT,
    id_pedido  INT,
    fecha_pago DATE,
    valor      NUMERIC(12,2),
    medio_pago VARCHAR(20),
    estado     VARCHAR(20)
);

CREATE TABLE devoluciones (
    id_devolucion   INT,
    id_sede         INT,
    id_pedido       INT,
    fecha_solicitud DATE,
    motivo          VARCHAR,
    estado          VARCHAR(20)
);

CREATE TABLE detalle_devolucion (
    id_devolucion      INT,
    id_producto        INT,  -- referencia lógica a catalogo_terceros.productos
    cantidad           INT,
    condicion_producto VARCHAR(20)
);
