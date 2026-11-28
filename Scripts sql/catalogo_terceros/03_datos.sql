-- ============================================================================
-- MICROSERVICIO: catalogo_terceros
-- 03. Datos de prueba reproducibles
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Volúmenes: Sedes 5 (1 Distribución) | Almacenes 8 | Categorías 6
--            Productos 100 | Proveedores 12 | Clientes 120
-- Idempotente: TRUNCATE inicial permite recargar.
-- ============================================================================

TRUNCATE TABLE
    producto_proveedor, clientes, proveedores, productos, categorias,
    almacenes, sedes
    RESTART IDENTITY CASCADE;

-- ---------------------- Sedes: 5 (incluye 1 Distribución) ------------------
INSERT INTO sedes (id_sede, nombre_sede, ciudad, direccion, tipo_sede, estado) VALUES
    (1, 'Sede Norte Bogotá',   'Bogotá',       'Calle 170 # 20-30',  'Ventas',       'Activo'),
    (2, 'Centro Distribución', 'Medellín',     'Carrera 50 # 10-15', 'Distribución', 'Activo'),
    (3, 'Sede Regional Cali',  'Cali',         'Avenida 6 # 25-40',  'Regional',     'Activo'),
    (4, 'Sede Sur Bogotá',     'Bogotá',       'Autopista Sur # 45', 'Ventas',       'Activo'),
    (5, 'Sede Barranquilla',   'Barranquilla', 'Calle 72 # 50-20',   'Ventas',       'Activo');

-- ---------------------- Almacenes: 8 ---------------------------------------
INSERT INTO almacenes (id_almacen, id_sede, nombre_almacen, tipo_almacen, estado) VALUES
    (1, 1, 'Almacén Principal Norte', 'Principal', 'Activo'),
    (2, 1, 'Tienda Norte',            'Tienda',    'Activo'),
    (3, 2, 'Bodega Central',          'Bodega',    'Activo'),
    (4, 2, 'Bodega Secundaria',       'Bodega',    'Activo'),
    (5, 3, 'Tienda Cali',             'Tienda',    'Activo'),
    (6, 3, 'Almacén Principal Cali',  'Principal', 'Activo'),
    (7, 4, 'Tienda Sur',              'Tienda',    'Activo'),
    (8, 5, 'Tienda Barranquilla',     'Tienda',    'Activo');

-- ---------------------- Categorías: 6 --------------------------------------
INSERT INTO categorias (id_categoria, nombre_categoria, descripcion, estado) VALUES
    (1, 'Bebidas',   'Bebidas gaseosas, jugos y agua',         'Activo'),
    (2, 'Snacks',    'Pasabocas y productos de paquete',       'Activo'),
    (3, 'Aseo',      'Productos de aseo y limpieza del hogar',  'Activo'),
    (4, 'Lácteos',   'Leche, quesos y derivados',              'Activo'),
    (5, 'Papelería', NULL,                                     'Activo'),
    (6, 'Abarrotes', 'Granos, enlatados y despensa',            'Activo');

-- ---------------------- Productos: 100 -------------------------------------
INSERT INTO productos (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado)
SELECT
    g,
    'SKU-' || lpad(g::text, 5, '0'),
    'Producto ' || g,
    ((g - 1) % 6) + 1,
    (ARRAY['Unidad','Gramo','Litro','Caja'])[((g - 1) % 4) + 1],
    (1000 + (g * 487) % 49000)::numeric(12,2),
    CASE WHEN g % 20 = 0 THEN 'Inactivo' ELSE 'Activo' END
FROM generate_series(1, 100) AS g;

-- ---------------------- Proveedores: 12 ------------------------------------
INSERT INTO proveedores (id_proveedor, identificacion_proveedor, razon_social, ciudad_proveedor, correo_proveedor, telefono_proveedor, estado)
SELECT
    g,
    900000000 + g * 111,
    'Proveedor Comercial ' || g || ' SAS',
    (ARRAY['Bogotá','Medellín','Cali','Barranquilla','Bucaramanga'])[((g - 1) % 5) + 1],
    'contacto' || g || '@proveedor.com',
    6010000000 + g * 1001,
    CASE WHEN g % 11 = 0 THEN 'Inactivo' ELSE 'Activo' END
FROM generate_series(1, 12) AS g;

-- ---------------------- Producto - Proveedor -------------------------------
INSERT INTO producto_proveedor (id_producto, id_proveedor, costo_referencia, plazo_entrega)
SELECT
    p.id_producto,
    ((p.id_producto - 1) % 12) + 1,
    round(p.precio_lista * 0.7, 2),
    1 + (p.id_producto % 10)
FROM productos p;

-- ---------------------- Clientes: 120 --------------------------------------
INSERT INTO clientes (id_cliente, tipo_documento, num_documento, nombre_completo_cliente, correo_cliente, telefono_cliente, estado)
SELECT
    g,
    (ARRAY['CC','NIT','CE','Pasaporte'])[((g - 1) % 4) + 1],
    1000000000 + g * 7919,
    'Cliente ' || g || ' Apellido',
    'cliente' || g || '@mail.com',
    3100000000 + g * 137,
    CASE WHEN g % 15 = 0 THEN 'Inactivo' ELSE 'Activo' END
FROM generate_series(1, 120) AS g;
