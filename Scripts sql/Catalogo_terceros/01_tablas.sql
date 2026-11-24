============================================================================
-- MICROSERVICIO: catalogo_terceros  
-- 01. Creación de tablas (solo columnas y tipos)
-- Motor: PostgreSQL (Neon)
-- ============================================================================

CREATE TABLE sedes (
    id_sede        INT,
    nombre_sede    VARCHAR(50),
    ciudad         VARCHAR(50),
    direccion      VARCHAR(80),
    tipo_sede      VARCHAR(20),
    estado         VARCHAR(10)
);

CREATE TABLE almacenes (
    id_almacen     INT,
    id_sede        INT,
    nombre_almacen VARCHAR(50),
    tipo_almacen   VARCHAR(20),
    estado         VARCHAR(10)
);

CREATE TABLE categorias (
    id_categoria     INT,
    nombre_categoria VARCHAR(50),
    descripcion      VARCHAR,
    estado           VARCHAR(10)
);

CREATE TABLE productos (
    id_producto   INT,
    sku           VARCHAR(50),
    nombre        VARCHAR(60),
    id_categoria  INT,
    unidad_medida VARCHAR(20),
    precio_lista  NUMERIC(12,2),
    estado        VARCHAR(10)
);

CREATE TABLE proveedores (
    id_proveedor             INT,
    identificacion_proveedor BIGINT,
    razon_social             VARCHAR(50),
    ciudad_proveedor         VARCHAR(50),
    correo_proveedor         VARCHAR(50),
    telefono_proveedor       BIGINT,
    estado                   VARCHAR(10)
);

CREATE TABLE producto_proveedor (
    id_producto      INT,
    id_proveedor     INT,
    costo_referencia NUMERIC(12,2),
    plazo_entrega    INT
);

CREATE TABLE clientes (
    id_cliente              INT,
    tipo_documento          VARCHAR(15),
    num_documento           BIGINT,
    nombre_completo_cliente VARCHAR(60),
    correo_cliente          VARCHAR(50),
    telefono_cliente        BIGINT,
    estado                  VARCHAR(10)
);
