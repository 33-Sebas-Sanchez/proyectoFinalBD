-- ============================================================================
-- MICROSERVICIO: ventas_pagos   (instancia/proyecto Neon independiente)
-- 01. Creación de tablas (solo columnas y tipos)
-- Motor: PostgreSQL (Neon)
-- ============================================================================

CREATE TABLE pedidos_venta (
    id_pedido        INT,
    id_sede          INT,  -- referencia lógica a catalogo_terceros.sedes
    id_almacen       INT,  -- referencia lógica a catalogo_terceros.almacenes
    id_cliente       INT,  -- referencia lógica a catalogo_terceros.clientes
    id_empleado      INT,  -- referencia lógica a identidad_accesos.empleados
    fecha_pedido     DATE,
    estado           VARCHAR(20),
    total_registrado NUMERIC(12,2)
);

CREATE TABLE detalle_pedido (
    id_pedido       INT,
    id_producto     INT,  -- referencia lógica a catalogo_terceros.productos
    cantidad        INT,
    precio_unitario NUMERIC(12,2)
);

CREATE TABLE pagos (
    id_pago    INT,
    id_pedido  INT,
    fecha_pago DATE,
    valor      NUMERIC(12,2),
    medio_pago VARCHAR(20),
    estado     VARCHAR(20)
);

CREATE TABLE devoluciones (
    id_devolucion   INT,
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
