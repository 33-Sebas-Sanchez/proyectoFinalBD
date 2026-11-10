-- ============================================================================
-- Proyecto Final - Bases de Datos
-- Creación de tablas
-- ===========================================================================
-- ESQUEMA: catalogo_terceros
-- ===========================================================================

CREATE TABLE catalogo_terceros.sedes (
    id_sede        INT,
    nombre_sede    VARCHAR(50),
    ciudad         VARCHAR(50),
    direccion      VARCHAR(80),
    tipo_sede      VARCHAR(20),
    estado         VARCHAR(10)
);

CREATE TABLE catalogo_terceros.almacenes (
    id_almacen     INT,
    id_sede        INT,
    nombre_almacen VARCHAR(50),
    tipo_almacen   VARCHAR(20),
    estado         VARCHAR(10)
);

CREATE TABLE catalogo_terceros.categorias (
    id_categoria     INT,
    nombre_categoria VARCHAR(50),
    descripcion      VARCHAR,
    estado           VARCHAR(10)
);

CREATE TABLE catalogo_terceros.productos (
    id_producto   INT,
    sku           VARCHAR(50),
    nombre        VARCHAR(60),
    id_categoria  INT,
    unidad_medida VARCHAR(20),
    precio_lista  NUMERIC(12,2),
    estado        VARCHAR(10)
);

CREATE TABLE catalogo_terceros.proveedores (
    id_proveedor             INT,
    identificacion_proveedor BIGINT,
    razon_social             VARCHAR(50),
    ciudad_proveedor         VARCHAR(50),
    correo_proveedor         VARCHAR(50),
    telefono_proveedor       BIGINT,
    estado                   VARCHAR(10)
);

CREATE TABLE catalogo_terceros.producto_proveedor (
    id_producto      INT,
    id_proveedor     INT,
    costo_referencia NUMERIC(12,2),
    plazo_entrega    INT
);

CREATE TABLE catalogo_terceros.clientes (
    id_cliente              INT,
    tipo_documento          VARCHAR(15),
    num_documento           BIGINT,
    nombre_completo_cliente VARCHAR(60),
    correo_cliente          VARCHAR(50),
    telefono_cliente        BIGINT,
    estado                  VARCHAR(10)
);

-- ===========================================================================
-- ESQUEMA: identidad_accesos
-- ===========================================================================

CREATE TABLE identidad_accesos.empleados (
    id_empleado     INT,
    id_sede         INT,
    num_documento   BIGINT,
    nombre_completo VARCHAR(60),
    cargo           VARCHAR(50),
    correo          VARCHAR(50),
    estado          VARCHAR(10)
);

CREATE TABLE identidad_accesos.usuarios (
    id_usuario     INT,
    id_empleado    INT,
    nombre_usuario VARCHAR(50),
    password_hash  VARCHAR(255),
    rol            VARCHAR(20),
    estado         VARCHAR(10),
    fecha_creacion DATE
);

CREATE TABLE identidad_accesos.auditoria_accesos (
    id_auditoria      INT,
    id_usuario        INT,
    fecha_hora        DATE,
    accion            VARCHAR(50),
    objeto_consultado VARCHAR(80)
);

-- ===========================================================================
-- ESQUEMA: compras_abastecimiento
-- ===========================================================================

CREATE TABLE compras_abastecimiento.ordenes_compra (
    id_orden_compra    INT,
    id_proveedor       INT,
    id_almacen_destino INT,
    id_empleado        INT,
    fecha_orden        DATE,
    fecha_estimada     DATE,
    estado             VARCHAR(20)
);

CREATE TABLE compras_abastecimiento.detalle_orden_compra (
    id_orden_compra     INT,
    id_producto         INT,
    cantidad_solicitada INT,
    costo_unitario      NUMERIC(12,2)
);

CREATE TABLE compras_abastecimiento.recepciones_compra (
    id_recepcion    INT,
    id_orden_compra INT,
    fecha_recepcion DATE,
    estado          VARCHAR(20)
);

CREATE TABLE compras_abastecimiento.detalle_recepcion (
    id_recepcion      INT,
    id_producto       INT,
    cantidad_recibida INT
);

-- ===========================================================================
-- ESQUEMA: inventarios_transferencias
-- ===========================================================================

CREATE TABLE inventarios_transferencias.inventarios (
    id_sede             INT,
    id_almacen          INT,
    id_producto         INT,
    existencia_actual   INT,
    stock_minimo        INT,
    fecha_actualizacion DATE
);

CREATE TABLE inventarios_transferencias.transferencias (
    id_transferencia   INT,
    id_almacen_origen  INT,
    id_almacen_destino INT,
    fecha_solicitud    DATE,
    fecha_despacho     DATE,
    fecha_recepcion    DATE,
    estado             VARCHAR(20)
);

CREATE TABLE inventarios_transferencias.detalle_transferencia (
    id_transferencia  INT,
    id_producto       INT,
    cantidad_enviada  INT,
    cantidad_recibida INT
);

-- ===========================================================================
-- ESQUEMA: ventas_pagos
-- ===========================================================================

CREATE TABLE ventas_pagos.pedidos_venta (
    id_pedido        INT,
    id_sede          INT,
    id_almacen       INT,
    id_cliente       INT,
    id_empleado      INT,
    fecha_pedido     DATE,
    estado           VARCHAR(20),
    total_registrado NUMERIC(12,2)
);

CREATE TABLE ventas_pagos.detalle_pedido (
    id_pedido       INT,
    id_producto     INT,
    cantidad        INT,
    precio_unitario NUMERIC(12,2)
);

CREATE TABLE ventas_pagos.pagos (
    id_pago    INT,
    id_pedido  INT,
    fecha_pago DATE,
    valor      NUMERIC(12,2),
    medio_pago VARCHAR(20),
    estado     VARCHAR(20)
);

CREATE TABLE ventas_pagos.devoluciones (
    id_devolucion   INT,
    id_pedido       INT,
    fecha_solicitud DATE,
    motivo          VARCHAR,
    estado          VARCHAR(20)
);

CREATE TABLE ventas_pagos.detalle_devolucion (
    id_devolucion      INT,
    id_producto        INT,
    cantidad           INT,
    condicion_producto VARCHAR(20)
);
