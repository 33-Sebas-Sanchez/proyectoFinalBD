-- ============================================================================
-- INSTANCIA: reportes   (proyecto Neon independiente, SOLO LECTURA)
-- 01. Configuración de dblink y vistas-espejo de las 5 instancias operativas
-- Motor: PostgreSQL (Neon)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS dblink;

DROP TABLE IF EXISTS _conexiones;
CREATE TABLE _conexiones (
    servicio text PRIMARY KEY,
    conn_str text NOT NULL
);

INSERT INTO _conexiones (servicio, conn_str) VALUES
 ('catalogo',    'host=ep-royal-wave-bdrjn7v7.c-8.us-east-2.aws.neon.tech   port=5432 dbname=catalogo_terceros          user=neondb_owner password=npg_1rNtDfzouBI4 sslmode=require'),
 ('identidad',   'host=ep-red-river-bdho2130.c-8.us-east-2.aws.neon.tech  port=5432 dbname=identidad_accesos          user=neondb_owner password=npg_CJjacwh08GPI sslmode=require'),
 ('compras',     'host=ep-delicate-math-bez7vbjh.c-9.us-east-2.aws.neon.tech    port=5432 dbname=compras_abastecimiento     user=neondb_owner password=npg_NwbUZauQ01We sslmode=require'),
 ('inventarios', 'host=ep-dark-rice-bepfgks0.c-9.us-east-2.aws.neon.tech port=5432 dbname=inventarios_transferencias user=neondb_owner password=npg_l4ONBf9vqzYu sslmode=require'),
 ('ventas',      'host=ep-flat-mountain-bdtwkqqb.c-8.us-east-2.aws.neon.tech    port=5432 dbname=ventas_pagos               user=neondb_owner password=npg_NG8kxJTEVFB5 sslmode=require');

-- Función helper: devuelve la cadena de conexión de un servicio.
CREATE OR REPLACE FUNCTION _conn(p_servicio text)
RETURNS text LANGUAGE sql STABLE AS $$
    SELECT conn_str FROM _conexiones WHERE servicio = p_servicio;
$$;

-- ============================================================================
-- VISTAS-ESPEJO: una por cada tabla remota que necesitan las vistas/consultas.
-- Traen los datos vía dblink y los exponen como si fueran tablas locales.
-- (Al ser vistas, cada consulta las vuelve a leer en vivo desde el remoto.)
-- ============================================================================

-- --------------------------- catalogo_terceros -----------------------------
CREATE OR REPLACE VIEW m_sedes AS
SELECT * FROM dblink(_conn('catalogo'),
  'SELECT id_sede, nombre_sede, ciudad, direccion, tipo_sede, estado FROM sedes')
  AS t(id_sede int, nombre_sede varchar, ciudad varchar, direccion varchar, tipo_sede varchar, estado varchar);

CREATE OR REPLACE VIEW m_almacenes AS
SELECT * FROM dblink(_conn('catalogo'),
  'SELECT id_almacen, id_sede, nombre_almacen, tipo_almacen, estado FROM almacenes')
  AS t(id_almacen int, id_sede int, nombre_almacen varchar, tipo_almacen varchar, estado varchar);

CREATE OR REPLACE VIEW m_categorias AS
SELECT * FROM dblink(_conn('catalogo'),
  'SELECT id_categoria, nombre_categoria, descripcion, estado FROM categorias')
  AS t(id_categoria int, nombre_categoria varchar, descripcion varchar, estado varchar);

CREATE OR REPLACE VIEW m_productos AS
SELECT * FROM dblink(_conn('catalogo'),
  'SELECT id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado FROM productos')
  AS t(id_producto int, sku varchar, nombre varchar, id_categoria int, unidad_medida varchar, precio_lista numeric, estado varchar);

CREATE OR REPLACE VIEW m_proveedores AS
SELECT * FROM dblink(_conn('catalogo'),
  'SELECT id_proveedor, identificacion_proveedor, razon_social, ciudad_proveedor, correo_proveedor, telefono_proveedor, estado FROM proveedores')
  AS t(id_proveedor int, identificacion_proveedor bigint, razon_social varchar, ciudad_proveedor varchar, correo_proveedor varchar, telefono_proveedor bigint, estado varchar);

CREATE OR REPLACE VIEW m_producto_proveedor AS
SELECT * FROM dblink(_conn('catalogo'),
  'SELECT id_producto, id_proveedor, costo_referencia, plazo_entrega FROM producto_proveedor')
  AS t(id_producto int, id_proveedor int, costo_referencia numeric, plazo_entrega int);

CREATE OR REPLACE VIEW m_clientes AS
SELECT * FROM dblink(_conn('catalogo'),
  'SELECT id_cliente, tipo_documento, num_documento, nombre_completo_cliente, correo_cliente, telefono_cliente, estado FROM clientes')
  AS t(id_cliente int, tipo_documento varchar, num_documento bigint, nombre_completo_cliente varchar, correo_cliente varchar, telefono_cliente bigint, estado varchar);

-- --------------------------- identidad_accesos -----------------------------
CREATE OR REPLACE VIEW m_empleados AS
SELECT * FROM dblink(_conn('identidad'),
  'SELECT id_empleado, id_sede, num_documento, nombre_completo, cargo, correo, estado FROM empleados')
  AS t(id_empleado int, id_sede int, num_documento bigint, nombre_completo varchar, cargo varchar, correo varchar, estado varchar);

-- --------------------------- compras_abastecimiento ------------------------
CREATE OR REPLACE VIEW m_ordenes_compra AS
SELECT * FROM dblink(_conn('compras'),
  'SELECT id_orden_compra, id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado FROM ordenes_compra')
  AS t(id_orden_compra int, id_proveedor int, id_almacen_destino int, id_empleado int, fecha_orden date, fecha_estimada date, estado varchar);

CREATE OR REPLACE VIEW m_detalle_orden_compra AS
SELECT * FROM dblink(_conn('compras'),
  'SELECT id_orden_compra, id_producto, cantidad_solicitada, costo_unitario FROM detalle_orden_compra')
  AS t(id_orden_compra int, id_producto int, cantidad_solicitada int, costo_unitario numeric);

CREATE OR REPLACE VIEW m_recepciones_compra AS
SELECT * FROM dblink(_conn('compras'),
  'SELECT id_recepcion, id_orden_compra, fecha_recepcion, estado FROM recepciones_compra')
  AS t(id_recepcion int, id_orden_compra int, fecha_recepcion date, estado varchar);

CREATE OR REPLACE VIEW m_detalle_recepcion AS
SELECT * FROM dblink(_conn('compras'),
  'SELECT id_recepcion, id_producto, cantidad_recibida FROM detalle_recepcion')
  AS t(id_recepcion int, id_producto int, cantidad_recibida int);

-- --------------------------- inventarios_transferencias --------------------
CREATE OR REPLACE VIEW m_inventarios AS
SELECT * FROM dblink(_conn('inventarios'),
  'SELECT id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion FROM inventarios')
  AS t(id_sede int, id_almacen int, id_producto int, existencia_actual int, stock_minimo int, fecha_actualizacion date);

CREATE OR REPLACE VIEW m_transferencias AS
SELECT * FROM dblink(_conn('inventarios'),
  'SELECT id_transferencia, id_almacen_origen, id_almacen_destino, fecha_solicitud, fecha_despacho, fecha_recepcion, estado FROM transferencias')
  AS t(id_transferencia int, id_almacen_origen int, id_almacen_destino int, fecha_solicitud date, fecha_despacho date, fecha_recepcion date, estado varchar);

CREATE OR REPLACE VIEW m_detalle_transferencia AS
SELECT * FROM dblink(_conn('inventarios'),
  'SELECT id_transferencia, id_producto, cantidad_enviada, cantidad_recibida FROM detalle_transferencia')
  AS t(id_transferencia int, id_producto int, cantidad_enviada int, cantidad_recibida int);

-- --------------------------- ventas_pagos ----------------------------------
CREATE OR REPLACE VIEW m_pedidos_venta AS
SELECT * FROM dblink(_conn('ventas'),
  'SELECT id_pedido, id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado FROM pedidos_venta')
  AS t(id_pedido int, id_sede int, id_almacen int, id_cliente int, id_empleado int, fecha_pedido date, estado varchar, total_registrado numeric);

CREATE OR REPLACE VIEW m_detalle_pedido AS
SELECT * FROM dblink(_conn('ventas'),
  'SELECT id_pedido, id_producto, cantidad, precio_unitario FROM detalle_pedido')
  AS t(id_pedido int, id_producto int, cantidad int, precio_unitario numeric);

CREATE OR REPLACE VIEW m_pagos AS
SELECT * FROM dblink(_conn('ventas'),
  'SELECT id_pago, id_pedido, fecha_pago, valor, medio_pago, estado FROM pagos')
  AS t(id_pago int, id_pedido int, fecha_pago date, valor numeric, medio_pago varchar, estado varchar);

CREATE OR REPLACE VIEW m_devoluciones AS
SELECT * FROM dblink(_conn('ventas'),
  'SELECT id_devolucion, id_pedido, fecha_solicitud, motivo, estado FROM devoluciones')
  AS t(id_devolucion int, id_pedido int, fecha_solicitud date, motivo varchar, estado varchar);

CREATE OR REPLACE VIEW m_detalle_devolucion AS
SELECT * FROM dblink(_conn('ventas'),
  'SELECT id_devolucion, id_producto, cantidad, condicion_producto FROM detalle_devolucion')
  AS t(id_devolucion int, id_producto int, cantidad int, condicion_producto varchar);
