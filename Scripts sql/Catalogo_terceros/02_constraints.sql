-- ============================================================================
-- MICROSERVICIO: catalogo_terceros
-- 02. Restricciones (ALTER TABLE / ALTER COLUMN) + claves foráneas INTERNAS
-- Motor: PostgreSQL (Neon)
-- ============================================================================

-- ---------------------- sedes ----------------------------------------------
ALTER TABLE sedes ALTER COLUMN nombre_sede SET NOT NULL;
ALTER TABLE sedes ALTER COLUMN ciudad      SET NOT NULL;
ALTER TABLE sedes ALTER COLUMN direccion   SET NOT NULL;
ALTER TABLE sedes ALTER COLUMN tipo_sede   SET NOT NULL;
ALTER TABLE sedes ALTER COLUMN estado      SET NOT NULL;
ALTER TABLE sedes ALTER COLUMN estado      SET DEFAULT 'Activo';
ALTER TABLE sedes ADD CONSTRAINT pk_sedes PRIMARY KEY (id_sede);
ALTER TABLE sedes ADD CONSTRAINT uq_sedes_nombre_sede UNIQUE (nombre_sede);
ALTER TABLE sedes ADD CONSTRAINT ck_sedes_tipo_sede CHECK (tipo_sede IN ('Ventas', 'Distribución', 'Regional'));
ALTER TABLE sedes ADD CONSTRAINT ck_sedes_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- almacenes ------------------------------------------
ALTER TABLE almacenes ALTER COLUMN id_sede        SET NOT NULL;
ALTER TABLE almacenes ALTER COLUMN nombre_almacen SET NOT NULL;
ALTER TABLE almacenes ALTER COLUMN tipo_almacen   SET NOT NULL;
ALTER TABLE almacenes ALTER COLUMN estado         SET NOT NULL;
ALTER TABLE almacenes ALTER COLUMN estado         SET DEFAULT 'Activo';
ALTER TABLE almacenes ADD CONSTRAINT pk_almacenes PRIMARY KEY (id_almacen);
ALTER TABLE almacenes ADD CONSTRAINT ck_almacenes_tipo_almacen CHECK (tipo_almacen IN ('Principal', 'Tienda', 'Bodega'));
ALTER TABLE almacenes ADD CONSTRAINT ck_almacenes_estado CHECK (estado IN ('Activo', 'Inactivo'));
-- FK INTERNA
ALTER TABLE almacenes ADD CONSTRAINT fk_almacenes_sede
    FOREIGN KEY (id_sede) REFERENCES sedes (id_sede);

-- ---------------------- categorias -----------------------------------------
ALTER TABLE categorias ALTER COLUMN nombre_categoria SET NOT NULL;
ALTER TABLE categorias ALTER COLUMN estado           SET NOT NULL;
ALTER TABLE categorias ALTER COLUMN estado           SET DEFAULT 'Activo';
ALTER TABLE categorias ADD CONSTRAINT pk_categorias PRIMARY KEY (id_categoria);
ALTER TABLE categorias ADD CONSTRAINT uq_categorias_nombre UNIQUE (nombre_categoria);
ALTER TABLE categorias ADD CONSTRAINT ck_categorias_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- productos ------------------------------------------
ALTER TABLE productos ALTER COLUMN sku           SET NOT NULL;
ALTER TABLE productos ALTER COLUMN nombre        SET NOT NULL;
ALTER TABLE productos ALTER COLUMN id_categoria  SET NOT NULL;
ALTER TABLE productos ALTER COLUMN unidad_medida SET NOT NULL;
ALTER TABLE productos ALTER COLUMN precio_lista  SET NOT NULL;
ALTER TABLE productos ALTER COLUMN estado        SET NOT NULL;
ALTER TABLE productos ALTER COLUMN estado        SET DEFAULT 'Activo';
ALTER TABLE productos ADD CONSTRAINT pk_productos PRIMARY KEY (id_producto);
ALTER TABLE productos ADD CONSTRAINT uq_productos_sku UNIQUE (sku);
ALTER TABLE productos ADD CONSTRAINT ck_productos_precio_lista CHECK (precio_lista >= 0);
ALTER TABLE productos ADD CONSTRAINT ck_productos_estado CHECK (estado IN ('Activo', 'Inactivo'));
-- FK INTERNA
ALTER TABLE productos ADD CONSTRAINT fk_productos_categoria
    FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria);

-- ---------------------- proveedores ----------------------------------------
ALTER TABLE proveedores ALTER COLUMN identificacion_proveedor SET NOT NULL;
ALTER TABLE proveedores ALTER COLUMN razon_social             SET NOT NULL;
ALTER TABLE proveedores ALTER COLUMN ciudad_proveedor         SET NOT NULL;
ALTER TABLE proveedores ALTER COLUMN correo_proveedor         SET NOT NULL;
ALTER TABLE proveedores ALTER COLUMN telefono_proveedor       SET NOT NULL;
ALTER TABLE proveedores ALTER COLUMN estado                   SET NOT NULL;
ALTER TABLE proveedores ALTER COLUMN estado                   SET DEFAULT 'Activo';
ALTER TABLE proveedores ADD CONSTRAINT pk_proveedores PRIMARY KEY (id_proveedor);
ALTER TABLE proveedores ADD CONSTRAINT uq_proveedores_identificacion UNIQUE (identificacion_proveedor);
ALTER TABLE proveedores ADD CONSTRAINT ck_proveedores_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- producto_proveedor ---------------------------------
ALTER TABLE producto_proveedor ALTER COLUMN id_producto      SET NOT NULL;
ALTER TABLE producto_proveedor ALTER COLUMN id_proveedor     SET NOT NULL;
ALTER TABLE producto_proveedor ALTER COLUMN costo_referencia SET NOT NULL;
ALTER TABLE producto_proveedor ALTER COLUMN plazo_entrega    SET NOT NULL;
ALTER TABLE producto_proveedor ADD CONSTRAINT pk_producto_proveedor PRIMARY KEY (id_producto, id_proveedor);
ALTER TABLE producto_proveedor ADD CONSTRAINT ck_producto_proveedor_costo CHECK (costo_referencia >= 0);
ALTER TABLE producto_proveedor ADD CONSTRAINT ck_producto_proveedor_plazo CHECK (plazo_entrega >= 0);
-- FK INTERNAS
ALTER TABLE producto_proveedor ADD CONSTRAINT fk_producto_proveedor_producto
    FOREIGN KEY (id_producto) REFERENCES productos (id_producto);
ALTER TABLE producto_proveedor ADD CONSTRAINT fk_producto_proveedor_proveedor
    FOREIGN KEY (id_proveedor) REFERENCES proveedores (id_proveedor);

-- ---------------------- clientes -------------------------------------------
ALTER TABLE clientes ALTER COLUMN tipo_documento          SET NOT NULL;
ALTER TABLE clientes ALTER COLUMN num_documento           SET NOT NULL;
ALTER TABLE clientes ALTER COLUMN nombre_completo_cliente SET NOT NULL;
ALTER TABLE clientes ALTER COLUMN correo_cliente          SET NOT NULL;
ALTER TABLE clientes ALTER COLUMN telefono_cliente        SET NOT NULL;
ALTER TABLE clientes ALTER COLUMN estado                  SET NOT NULL;
ALTER TABLE clientes ALTER COLUMN estado                  SET DEFAULT 'Activo';
ALTER TABLE clientes ADD CONSTRAINT pk_clientes PRIMARY KEY (id_cliente);
ALTER TABLE clientes ADD CONSTRAINT uq_clientes_num_documento UNIQUE (num_documento);
ALTER TABLE clientes ADD CONSTRAINT ck_clientes_tipo_documento CHECK (tipo_documento IN ('CC', 'NIT', 'CE', 'Pasaporte'));
ALTER TABLE clientes ADD CONSTRAINT ck_clientes_estado CHECK (estado IN ('Activo', 'Inactivo'));
