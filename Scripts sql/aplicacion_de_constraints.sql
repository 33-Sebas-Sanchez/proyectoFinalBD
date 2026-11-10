-- ============================================================================
-- Proyecto Final - Bases de Datos
-- Restricciones aplicadas con ALTER TABLE / ALTER COLUMN
--     (NOT NULL, DEFAULT, PRIMARY KEY, UNIQUE, CHECK)
-- ----------------------------------------------------------------------------
-- Las FOREIGN KEY se definen en el archivo llaves_foraneas.sql para respetar
-- el orden de dependencias entre esquemas.
-- Convención de nombres:
--   pk_<tabla>     -> PRIMARY KEY
--   uq_<tabla>_... -> UNIQUE
--   ck_<tabla>_... -> CHECK
-- ============================================================================


-- ---------------------------------------------------------------------------
-- ESQUEMA: catalogo_terceros
-- ---------------------------------------------------------------------------

-- ---------------------- Tabla: sedes ---------------------------------------
ALTER TABLE catalogo_terceros.sedes ALTER COLUMN nombre_sede SET NOT NULL;
ALTER TABLE catalogo_terceros.sedes ALTER COLUMN ciudad      SET NOT NULL;
ALTER TABLE catalogo_terceros.sedes ALTER COLUMN direccion   SET NOT NULL;
ALTER TABLE catalogo_terceros.sedes ALTER COLUMN tipo_sede   SET NOT NULL;
ALTER TABLE catalogo_terceros.sedes ALTER COLUMN estado      SET NOT NULL;
ALTER TABLE catalogo_terceros.sedes ALTER COLUMN estado      SET DEFAULT 'Activo';

ALTER TABLE catalogo_terceros.sedes
    ADD CONSTRAINT pk_sedes PRIMARY KEY (id_sede);
ALTER TABLE catalogo_terceros.sedes
    ADD CONSTRAINT uq_sedes_nombre_sede UNIQUE (nombre_sede);
ALTER TABLE catalogo_terceros.sedes
    ADD CONSTRAINT ck_sedes_tipo_sede CHECK (tipo_sede IN ('Ventas', 'Distribución', 'Regional'));
ALTER TABLE catalogo_terceros.sedes
    ADD CONSTRAINT ck_sedes_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- Tabla: almacenes -----------------------------------
ALTER TABLE catalogo_terceros.almacenes ALTER COLUMN id_sede        SET NOT NULL;
ALTER TABLE catalogo_terceros.almacenes ALTER COLUMN nombre_almacen SET NOT NULL;
ALTER TABLE catalogo_terceros.almacenes ALTER COLUMN tipo_almacen   SET NOT NULL;
ALTER TABLE catalogo_terceros.almacenes ALTER COLUMN estado         SET NOT NULL;
ALTER TABLE catalogo_terceros.almacenes ALTER COLUMN estado         SET DEFAULT 'Activo';

ALTER TABLE catalogo_terceros.almacenes
    ADD CONSTRAINT pk_almacenes PRIMARY KEY (id_almacen);
ALTER TABLE catalogo_terceros.almacenes
    ADD CONSTRAINT ck_almacenes_tipo_almacen CHECK (tipo_almacen IN ('Principal', 'Tienda', 'Bodega'));
ALTER TABLE catalogo_terceros.almacenes
    ADD CONSTRAINT ck_almacenes_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- Tabla: categorias ----------------------------------
ALTER TABLE catalogo_terceros.categorias ALTER COLUMN nombre_categoria SET NOT NULL;
ALTER TABLE catalogo_terceros.categorias ALTER COLUMN estado           SET NOT NULL;
ALTER TABLE catalogo_terceros.categorias ALTER COLUMN estado           SET DEFAULT 'Activo';

ALTER TABLE catalogo_terceros.categorias
    ADD CONSTRAINT pk_categorias PRIMARY KEY (id_categoria);
ALTER TABLE catalogo_terceros.categorias
    ADD CONSTRAINT uq_categorias_nombre UNIQUE (nombre_categoria);
ALTER TABLE catalogo_terceros.categorias
    ADD CONSTRAINT ck_categorias_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- Tabla: productos -----------------------------------
ALTER TABLE catalogo_terceros.productos ALTER COLUMN sku           SET NOT NULL;
ALTER TABLE catalogo_terceros.productos ALTER COLUMN nombre        SET NOT NULL;
ALTER TABLE catalogo_terceros.productos ALTER COLUMN id_categoria  SET NOT NULL;
ALTER TABLE catalogo_terceros.productos ALTER COLUMN unidad_medida SET NOT NULL;
ALTER TABLE catalogo_terceros.productos ALTER COLUMN precio_lista  SET NOT NULL;
ALTER TABLE catalogo_terceros.productos ALTER COLUMN estado        SET NOT NULL;
ALTER TABLE catalogo_terceros.productos ALTER COLUMN estado        SET DEFAULT 'Activo';

ALTER TABLE catalogo_terceros.productos
    ADD CONSTRAINT pk_productos PRIMARY KEY (id_producto);
ALTER TABLE catalogo_terceros.productos
    ADD CONSTRAINT uq_productos_sku UNIQUE (sku);
ALTER TABLE catalogo_terceros.productos
    ADD CONSTRAINT ck_productos_precio_lista CHECK (precio_lista >= 0);
ALTER TABLE catalogo_terceros.productos
    ADD CONSTRAINT ck_productos_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- Tabla: proveedores ---------------------------------
ALTER TABLE catalogo_terceros.proveedores ALTER COLUMN identificacion_proveedor SET NOT NULL;
ALTER TABLE catalogo_terceros.proveedores ALTER COLUMN razon_social             SET NOT NULL;
ALTER TABLE catalogo_terceros.proveedores ALTER COLUMN ciudad_proveedor         SET NOT NULL;
ALTER TABLE catalogo_terceros.proveedores ALTER COLUMN correo_proveedor         SET NOT NULL;
ALTER TABLE catalogo_terceros.proveedores ALTER COLUMN telefono_proveedor       SET NOT NULL;
ALTER TABLE catalogo_terceros.proveedores ALTER COLUMN estado                   SET NOT NULL;
ALTER TABLE catalogo_terceros.proveedores ALTER COLUMN estado                   SET DEFAULT 'Activo';

ALTER TABLE catalogo_terceros.proveedores
    ADD CONSTRAINT pk_proveedores PRIMARY KEY (id_proveedor);
ALTER TABLE catalogo_terceros.proveedores
    ADD CONSTRAINT uq_proveedores_identificacion UNIQUE (identificacion_proveedor);
ALTER TABLE catalogo_terceros.proveedores
    ADD CONSTRAINT ck_proveedores_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- Tabla: producto_proveedor --------------------------
ALTER TABLE catalogo_terceros.producto_proveedor ALTER COLUMN id_producto      SET NOT NULL;
ALTER TABLE catalogo_terceros.producto_proveedor ALTER COLUMN id_proveedor     SET NOT NULL;
ALTER TABLE catalogo_terceros.producto_proveedor ALTER COLUMN costo_referencia SET NOT NULL;
ALTER TABLE catalogo_terceros.producto_proveedor ALTER COLUMN plazo_entrega    SET NOT NULL;

ALTER TABLE catalogo_terceros.producto_proveedor
    ADD CONSTRAINT pk_producto_proveedor PRIMARY KEY (id_producto, id_proveedor);
ALTER TABLE catalogo_terceros.producto_proveedor
    ADD CONSTRAINT ck_producto_proveedor_costo CHECK (costo_referencia >= 0);
ALTER TABLE catalogo_terceros.producto_proveedor
    ADD CONSTRAINT ck_producto_proveedor_plazo CHECK (plazo_entrega >= 0);

-- ---------------------- Tabla: clientes ------------------------------------
ALTER TABLE catalogo_terceros.clientes ALTER COLUMN tipo_documento          SET NOT NULL;
ALTER TABLE catalogo_terceros.clientes ALTER COLUMN num_documento           SET NOT NULL;
ALTER TABLE catalogo_terceros.clientes ALTER COLUMN nombre_completo_cliente SET NOT NULL;
ALTER TABLE catalogo_terceros.clientes ALTER COLUMN correo_cliente          SET NOT NULL;
ALTER TABLE catalogo_terceros.clientes ALTER COLUMN telefono_cliente        SET NOT NULL;
ALTER TABLE catalogo_terceros.clientes ALTER COLUMN estado                  SET NOT NULL;
ALTER TABLE catalogo_terceros.clientes ALTER COLUMN estado                  SET DEFAULT 'Activo';

ALTER TABLE catalogo_terceros.clientes
    ADD CONSTRAINT pk_clientes PRIMARY KEY (id_cliente);
ALTER TABLE catalogo_terceros.clientes
    ADD CONSTRAINT uq_clientes_num_documento UNIQUE (num_documento);
ALTER TABLE catalogo_terceros.clientes
    ADD CONSTRAINT ck_clientes_tipo_documento CHECK (tipo_documento IN ('CC', 'NIT', 'CE', 'Pasaporte'));
ALTER TABLE catalogo_terceros.clientes
    ADD CONSTRAINT ck_clientes_estado CHECK (estado IN ('Activo', 'Inactivo'));


-- ---------------------------------------------------------------------------
-- ESQUEMA: identidad_accesos
-- ---------------------------------------------------------------------------

-- ---------------------- Tabla: empleados -----------------------------------
ALTER TABLE identidad_accesos.empleados ALTER COLUMN id_sede         SET NOT NULL;
ALTER TABLE identidad_accesos.empleados ALTER COLUMN num_documento   SET NOT NULL;
ALTER TABLE identidad_accesos.empleados ALTER COLUMN nombre_completo SET NOT NULL;
ALTER TABLE identidad_accesos.empleados ALTER COLUMN cargo           SET NOT NULL;
ALTER TABLE identidad_accesos.empleados ALTER COLUMN correo          SET NOT NULL;
ALTER TABLE identidad_accesos.empleados ALTER COLUMN estado          SET NOT NULL;
ALTER TABLE identidad_accesos.empleados ALTER COLUMN estado          SET DEFAULT 'Activo';

ALTER TABLE identidad_accesos.empleados
    ADD CONSTRAINT pk_empleados PRIMARY KEY (id_empleado);
ALTER TABLE identidad_accesos.empleados
    ADD CONSTRAINT uq_empleados_num_documento UNIQUE (num_documento);
ALTER TABLE identidad_accesos.empleados
    ADD CONSTRAINT ck_empleados_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- Tabla: usuarios ------------------------------------
ALTER TABLE identidad_accesos.usuarios ALTER COLUMN id_empleado    SET NOT NULL;
ALTER TABLE identidad_accesos.usuarios ALTER COLUMN nombre_usuario SET NOT NULL;
ALTER TABLE identidad_accesos.usuarios ALTER COLUMN password_hash  SET NOT NULL;
ALTER TABLE identidad_accesos.usuarios ALTER COLUMN rol            SET NOT NULL;
ALTER TABLE identidad_accesos.usuarios ALTER COLUMN estado         SET NOT NULL;
ALTER TABLE identidad_accesos.usuarios ALTER COLUMN estado         SET DEFAULT 'Activo';
ALTER TABLE identidad_accesos.usuarios ALTER COLUMN fecha_creacion SET NOT NULL;

ALTER TABLE identidad_accesos.usuarios
    ADD CONSTRAINT pk_usuarios PRIMARY KEY (id_usuario);
ALTER TABLE identidad_accesos.usuarios
    ADD CONSTRAINT uq_usuarios_id_empleado UNIQUE (id_empleado);
ALTER TABLE identidad_accesos.usuarios
    ADD CONSTRAINT uq_usuarios_nombre_usuario UNIQUE (nombre_usuario);
ALTER TABLE identidad_accesos.usuarios
    ADD CONSTRAINT ck_usuarios_rol CHECK (rol IN ('Administrador', 'Gerencia', 'Inventario', 'Compras', 'Vendedor', 'Auditor'));
ALTER TABLE identidad_accesos.usuarios
    ADD CONSTRAINT ck_usuarios_estado CHECK (estado IN ('Activo', 'Inactivo'));

-- ---------------------- Tabla: auditoria_accesos ---------------------------
ALTER TABLE identidad_accesos.auditoria_accesos ALTER COLUMN id_usuario        SET NOT NULL;
ALTER TABLE identidad_accesos.auditoria_accesos ALTER COLUMN fecha_hora        SET NOT NULL;
ALTER TABLE identidad_accesos.auditoria_accesos ALTER COLUMN accion            SET NOT NULL;
ALTER TABLE identidad_accesos.auditoria_accesos ALTER COLUMN objeto_consultado SET NOT NULL;

ALTER TABLE identidad_accesos.auditoria_accesos
    ADD CONSTRAINT pk_auditoria_accesos PRIMARY KEY (id_auditoria);


-- ---------------------------------------------------------------------------
-- ESQUEMA: compras_abastecimiento
-- ---------------------------------------------------------------------------

-- ---------------------- Tabla: ordenes_compra ------------------------------
ALTER TABLE compras_abastecimiento.ordenes_compra ALTER COLUMN id_proveedor       SET NOT NULL;
ALTER TABLE compras_abastecimiento.ordenes_compra ALTER COLUMN id_almacen_destino SET NOT NULL;
ALTER TABLE compras_abastecimiento.ordenes_compra ALTER COLUMN id_empleado        SET NOT NULL;
ALTER TABLE compras_abastecimiento.ordenes_compra ALTER COLUMN fecha_orden        SET NOT NULL;
ALTER TABLE compras_abastecimiento.ordenes_compra ALTER COLUMN fecha_estimada     SET NOT NULL;
ALTER TABLE compras_abastecimiento.ordenes_compra ALTER COLUMN estado             SET NOT NULL;

ALTER TABLE compras_abastecimiento.ordenes_compra
    ADD CONSTRAINT pk_ordenes_compra PRIMARY KEY (id_orden_compra);
ALTER TABLE compras_abastecimiento.ordenes_compra
    ADD CONSTRAINT ck_ordenes_compra_fecha CHECK (fecha_estimada >= fecha_orden);
ALTER TABLE compras_abastecimiento.ordenes_compra
    ADD CONSTRAINT ck_ordenes_compra_estado CHECK (estado IN ('Pendiente', 'Recibida Parcial', 'Recibida Total', 'Cancelada'));

-- ---------------------- Tabla: detalle_orden_compra ------------------------
ALTER TABLE compras_abastecimiento.detalle_orden_compra ALTER COLUMN id_orden_compra     SET NOT NULL;
ALTER TABLE compras_abastecimiento.detalle_orden_compra ALTER COLUMN id_producto         SET NOT NULL;
ALTER TABLE compras_abastecimiento.detalle_orden_compra ALTER COLUMN cantidad_solicitada SET NOT NULL;
ALTER TABLE compras_abastecimiento.detalle_orden_compra ALTER COLUMN costo_unitario      SET NOT NULL;

ALTER TABLE compras_abastecimiento.detalle_orden_compra
    ADD CONSTRAINT pk_detalle_orden_compra PRIMARY KEY (id_orden_compra, id_producto);
ALTER TABLE compras_abastecimiento.detalle_orden_compra
    ADD CONSTRAINT ck_detalle_orden_compra_cantidad CHECK (cantidad_solicitada > 0);
ALTER TABLE compras_abastecimiento.detalle_orden_compra
    ADD CONSTRAINT ck_detalle_orden_compra_costo CHECK (costo_unitario >= 0);

-- ---------------------- Tabla: recepciones_compra --------------------------
ALTER TABLE compras_abastecimiento.recepciones_compra ALTER COLUMN id_orden_compra SET NOT NULL;
ALTER TABLE compras_abastecimiento.recepciones_compra ALTER COLUMN fecha_recepcion SET NOT NULL;
ALTER TABLE compras_abastecimiento.recepciones_compra ALTER COLUMN estado          SET NOT NULL;

ALTER TABLE compras_abastecimiento.recepciones_compra
    ADD CONSTRAINT pk_recepciones_compra PRIMARY KEY (id_recepcion);
ALTER TABLE compras_abastecimiento.recepciones_compra
    ADD CONSTRAINT ck_recepciones_compra_estado CHECK (estado IN ('Procesado', 'Parcial', 'Anulado'));

-- ---------------------- Tabla: detalle_recepcion ---------------------------
ALTER TABLE compras_abastecimiento.detalle_recepcion ALTER COLUMN id_recepcion      SET NOT NULL;
ALTER TABLE compras_abastecimiento.detalle_recepcion ALTER COLUMN id_producto       SET NOT NULL;
ALTER TABLE compras_abastecimiento.detalle_recepcion ALTER COLUMN cantidad_recibida SET NOT NULL;

ALTER TABLE compras_abastecimiento.detalle_recepcion
    ADD CONSTRAINT pk_detalle_recepcion PRIMARY KEY (id_recepcion, id_producto);
ALTER TABLE compras_abastecimiento.detalle_recepcion
    ADD CONSTRAINT ck_detalle_recepcion_cantidad CHECK (cantidad_recibida >= 0);


-- ---------------------------------------------------------------------------
-- ESQUEMA: inventarios_transferencias
-- ---------------------------------------------------------------------------

-- ---------------------- Tabla: inventarios ---------------------------------
ALTER TABLE inventarios_transferencias.inventarios ALTER COLUMN id_sede             SET NOT NULL;
ALTER TABLE inventarios_transferencias.inventarios ALTER COLUMN id_almacen          SET NOT NULL;
ALTER TABLE inventarios_transferencias.inventarios ALTER COLUMN id_producto         SET NOT NULL;
ALTER TABLE inventarios_transferencias.inventarios ALTER COLUMN existencia_actual   SET NOT NULL;
ALTER TABLE inventarios_transferencias.inventarios ALTER COLUMN stock_minimo        SET NOT NULL;
ALTER TABLE inventarios_transferencias.inventarios ALTER COLUMN fecha_actualizacion SET NOT NULL;

ALTER TABLE inventarios_transferencias.inventarios
    ADD CONSTRAINT pk_inventarios PRIMARY KEY (id_almacen, id_producto);
ALTER TABLE inventarios_transferencias.inventarios
    ADD CONSTRAINT ck_inventarios_existencia CHECK (existencia_actual >= 0);
ALTER TABLE inventarios_transferencias.inventarios
    ADD CONSTRAINT ck_inventarios_stock_minimo CHECK (stock_minimo >= 0);

-- ---------------------- Tabla: transferencias ------------------------------
ALTER TABLE inventarios_transferencias.transferencias ALTER COLUMN id_almacen_origen  SET NOT NULL;
ALTER TABLE inventarios_transferencias.transferencias ALTER COLUMN id_almacen_destino SET NOT NULL;
ALTER TABLE inventarios_transferencias.transferencias ALTER COLUMN fecha_solicitud    SET NOT NULL;
ALTER TABLE inventarios_transferencias.transferencias ALTER COLUMN estado             SET NOT NULL;

ALTER TABLE inventarios_transferencias.transferencias
    ADD CONSTRAINT pk_transferencias PRIMARY KEY (id_transferencia);
ALTER TABLE inventarios_transferencias.transferencias
    ADD CONSTRAINT ck_transferencias_estado CHECK (estado IN ('Solicitada', 'Despachada', 'Recibida', 'Cancelada'));
ALTER TABLE inventarios_transferencias.transferencias
    ADD CONSTRAINT ck_transferencias_almacenes CHECK (id_almacen_origen <> id_almacen_destino);
ALTER TABLE inventarios_transferencias.transferencias
    ADD CONSTRAINT ck_transferencias_fechas
    CHECK (fecha_despacho >= fecha_solicitud AND fecha_recepcion >= fecha_despacho);

-- ---------------------- Tabla: detalle_transferencia -----------------------
ALTER TABLE inventarios_transferencias.detalle_transferencia ALTER COLUMN id_transferencia SET NOT NULL;
ALTER TABLE inventarios_transferencias.detalle_transferencia ALTER COLUMN id_producto      SET NOT NULL;
ALTER TABLE inventarios_transferencias.detalle_transferencia ALTER COLUMN cantidad_enviada SET NOT NULL;

ALTER TABLE inventarios_transferencias.detalle_transferencia
    ADD CONSTRAINT pk_detalle_transferencia PRIMARY KEY (id_transferencia, id_producto);
ALTER TABLE inventarios_transferencias.detalle_transferencia
    ADD CONSTRAINT ck_detalle_transferencia_enviada CHECK (cantidad_enviada > 0);
ALTER TABLE inventarios_transferencias.detalle_transferencia
    ADD CONSTRAINT ck_detalle_transferencia_recibida CHECK (cantidad_recibida IS NULL OR cantidad_recibida >= 0);


-- ---------------------------------------------------------------------------
-- ESQUEMA: ventas_pagos
-- ---------------------------------------------------------------------------

-- ---------------------- Tabla: pedidos_venta -------------------------------
ALTER TABLE ventas_pagos.pedidos_venta ALTER COLUMN id_sede          SET NOT NULL;
ALTER TABLE ventas_pagos.pedidos_venta ALTER COLUMN id_almacen       SET NOT NULL;
ALTER TABLE ventas_pagos.pedidos_venta ALTER COLUMN id_cliente       SET NOT NULL;
ALTER TABLE ventas_pagos.pedidos_venta ALTER COLUMN id_empleado      SET NOT NULL;
ALTER TABLE ventas_pagos.pedidos_venta ALTER COLUMN fecha_pedido     SET NOT NULL;
ALTER TABLE ventas_pagos.pedidos_venta ALTER COLUMN estado           SET NOT NULL;
ALTER TABLE ventas_pagos.pedidos_venta ALTER COLUMN total_registrado SET NOT NULL;

ALTER TABLE ventas_pagos.pedidos_venta
    ADD CONSTRAINT pk_pedidos_venta PRIMARY KEY (id_pedido);
ALTER TABLE ventas_pagos.pedidos_venta
    ADD CONSTRAINT ck_pedidos_venta_estado CHECK (estado IN ('Pendiente', 'Completado', 'Cancelado'));
ALTER TABLE ventas_pagos.pedidos_venta
    ADD CONSTRAINT ck_pedidos_venta_total CHECK (total_registrado >= 0);

-- ---------------------- Tabla: detalle_pedido ------------------------------
ALTER TABLE ventas_pagos.detalle_pedido ALTER COLUMN id_pedido       SET NOT NULL;
ALTER TABLE ventas_pagos.detalle_pedido ALTER COLUMN id_producto     SET NOT NULL;
ALTER TABLE ventas_pagos.detalle_pedido ALTER COLUMN cantidad        SET NOT NULL;
ALTER TABLE ventas_pagos.detalle_pedido ALTER COLUMN precio_unitario SET NOT NULL;

ALTER TABLE ventas_pagos.detalle_pedido
    ADD CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto);
ALTER TABLE ventas_pagos.detalle_pedido
    ADD CONSTRAINT ck_detalle_pedido_cantidad CHECK (cantidad > 0);
ALTER TABLE ventas_pagos.detalle_pedido
    ADD CONSTRAINT ck_detalle_pedido_precio CHECK (precio_unitario >= 0);

-- ---------------------- Tabla: pagos ---------------------------------------
ALTER TABLE ventas_pagos.pagos ALTER COLUMN id_pedido  SET NOT NULL;
ALTER TABLE ventas_pagos.pagos ALTER COLUMN fecha_pago SET NOT NULL;
ALTER TABLE ventas_pagos.pagos ALTER COLUMN valor      SET NOT NULL;
ALTER TABLE ventas_pagos.pagos ALTER COLUMN medio_pago SET NOT NULL;
ALTER TABLE ventas_pagos.pagos ALTER COLUMN estado     SET NOT NULL;

ALTER TABLE ventas_pagos.pagos
    ADD CONSTRAINT pk_pagos PRIMARY KEY (id_pago);
ALTER TABLE ventas_pagos.pagos
    ADD CONSTRAINT ck_pagos_valor CHECK (valor > 0);
ALTER TABLE ventas_pagos.pagos
    ADD CONSTRAINT ck_pagos_medio CHECK (medio_pago IN ('Efectivo', 'Tarjeta Debito', 'Tarjeta Credito', 'Transferencia'));
ALTER TABLE ventas_pagos.pagos
    ADD CONSTRAINT ck_pagos_estado CHECK (estado IN ('Confirmado', 'Rechazado', 'Pendiente'));

-- ---------------------- Tabla: devoluciones --------------------------------
ALTER TABLE ventas_pagos.devoluciones ALTER COLUMN id_pedido       SET NOT NULL;
ALTER TABLE ventas_pagos.devoluciones ALTER COLUMN fecha_solicitud SET NOT NULL;
ALTER TABLE ventas_pagos.devoluciones ALTER COLUMN motivo          SET NOT NULL;
ALTER TABLE ventas_pagos.devoluciones ALTER COLUMN estado          SET NOT NULL;

ALTER TABLE ventas_pagos.devoluciones
    ADD CONSTRAINT pk_devoluciones PRIMARY KEY (id_devolucion);
ALTER TABLE ventas_pagos.devoluciones
    ADD CONSTRAINT ck_devoluciones_estado CHECK (estado IN ('Solicitada', 'Aprobada', 'Rechazada'));

-- ---------------------- Tabla: detalle_devolucion --------------------------
ALTER TABLE ventas_pagos.detalle_devolucion ALTER COLUMN id_devolucion      SET NOT NULL;
ALTER TABLE ventas_pagos.detalle_devolucion ALTER COLUMN id_producto        SET NOT NULL;
ALTER TABLE ventas_pagos.detalle_devolucion ALTER COLUMN cantidad           SET NOT NULL;
ALTER TABLE ventas_pagos.detalle_devolucion ALTER COLUMN condicion_producto SET NOT NULL;

ALTER TABLE ventas_pagos.detalle_devolucion
    ADD CONSTRAINT pk_detalle_devolucion PRIMARY KEY (id_devolucion, id_producto);
ALTER TABLE ventas_pagos.detalle_devolucion
    ADD CONSTRAINT ck_detalle_devolucion_cantidad CHECK (cantidad > 0);
ALTER TABLE ventas_pagos.detalle_devolucion
    ADD CONSTRAINT ck_detalle_devolucion_condicion CHECK (condicion_producto IN ('Buen Estado', 'Defectuoso', 'Dañado'));
	
