-- ============================================================================
-- INSTANCIA: reportes
-- 01. Diez (10) vistas de solo lectura consolidadas
-- Motor: PostgreSQL (Neon) — se apoyan en las vistas-espejo m_* (dblink).
-- ============================================================================

-- 1) vista_inventario_por_sede
--    Existencias con sede, almacén, producto, categoría y valorización.
CREATE OR REPLACE VIEW vista_inventario_por_sede AS
SELECT
    s.id_sede,
    s.nombre_sede,
    a.id_almacen,
    a.nombre_almacen,
    p.id_producto,
    p.nombre                      AS producto,
    c.nombre_categoria            AS categoria,
    i.existencia_actual,
    i.stock_minimo,
    p.precio_lista,
    (i.existencia_actual * p.precio_lista) AS valorizacion
FROM m_inventarios i
JOIN m_sedes      s ON s.id_sede      = i.id_sede
JOIN m_almacenes  a ON a.id_almacen   = i.id_almacen
JOIN m_productos  p ON p.id_producto  = i.id_producto
JOIN m_categorias c ON c.id_categoria = p.id_categoria;

-- 2) vista_alertas_reabastecimiento
--    Productos con existencia 0 o por debajo del stock mínimo.
CREATE OR REPLACE VIEW vista_alertas_reabastecimiento AS
SELECT
    i.id_sede,
    s.nombre_sede,
    i.id_almacen,
    i.id_producto,
    p.nombre                       AS producto,
    i.existencia_actual,
    i.stock_minimo,
    (i.stock_minimo - i.existencia_actual) AS faltante
FROM m_inventarios i
JOIN m_sedes     s ON s.id_sede     = i.id_sede
JOIN m_productos p ON p.id_producto = i.id_producto
WHERE i.existencia_actual = 0
   OR i.existencia_actual < i.stock_minimo;

-- 3) vista_productos_sin_inventario
--    Productos activos sin registro de inventario en NINGÚN almacén.
CREATE OR REPLACE VIEW vista_productos_sin_inventario AS
SELECT
    p.id_producto,
    p.sku,
    p.nombre AS producto,
    p.estado
FROM m_productos p
WHERE p.estado = 'Activo'
  AND NOT EXISTS (
        SELECT 1 FROM m_inventarios i WHERE i.id_producto = p.id_producto
  );

-- 4) vista_ventas_mensuales_por_sede
--    Ventas (importe y unidades) agrupadas por sede y mes.
CREATE OR REPLACE VIEW vista_ventas_mensuales_por_sede AS
SELECT
    pv.id_sede,
    s.nombre_sede,
    date_trunc('month', pv.fecha_pedido)::date AS mes,
    count(DISTINCT pv.id_pedido)               AS num_pedidos,
    SUM(dp.cantidad)                           AS unidades,
    SUM(dp.cantidad * dp.precio_unitario)      AS importe
FROM m_pedidos_venta pv
JOIN m_sedes         s  ON s.id_sede  = pv.id_sede
JOIN m_detalle_pedido dp ON dp.id_pedido = pv.id_pedido
WHERE pv.estado <> 'Cancelado'
GROUP BY pv.id_sede, s.nombre_sede, date_trunc('month', pv.fecha_pedido);

-- 5) vista_pedidos_pendientes
--    Pedidos en estado 'Pendiente' con cliente y sede.
CREATE OR REPLACE VIEW vista_pedidos_pendientes AS
SELECT
    pv.id_pedido,
    pv.id_sede,
    s.nombre_sede,
    pv.id_cliente,
    cl.nombre_completo_cliente AS cliente,
    pv.fecha_pedido,
    pv.total_registrado
FROM m_pedidos_venta pv
JOIN m_sedes    s  ON s.id_sede    = pv.id_sede
JOIN m_clientes cl ON cl.id_cliente = pv.id_cliente
WHERE pv.estado = 'Pendiente';

-- 6) vista_saldos_pendientes
--    Saldo por cobrar = total_registrado - pagos confirmados.
CREATE OR REPLACE VIEW vista_saldos_pendientes AS
SELECT
    pv.id_pedido,
    pv.id_sede,
    cl.nombre_completo_cliente AS cliente,
    pv.total_registrado,
    COALESCE(pg.pagado, 0)                        AS pagado_confirmado,
    (pv.total_registrado - COALESCE(pg.pagado, 0)) AS saldo
FROM m_pedidos_venta pv
JOIN m_clientes cl ON cl.id_cliente = pv.id_cliente
LEFT JOIN (
    SELECT id_pedido, SUM(valor) AS pagado
    FROM m_pagos
    WHERE estado = 'Confirmado'
    GROUP BY id_pedido
) pg ON pg.id_pedido = pv.id_pedido
WHERE pv.estado <> 'Cancelado'
  AND (pv.total_registrado - COALESCE(pg.pagado, 0)) > 0;

-- 7) vista_compras_pendientes
--    Órdenes de compra no recibidas totalmente.
CREATE OR REPLACE VIEW vista_compras_pendientes AS
SELECT
    oc.id_orden_compra,
    oc.id_proveedor,
    pr.razon_social          AS proveedor,
    oc.id_almacen_destino,
    oc.fecha_orden,
    oc.fecha_estimada,
    oc.estado
FROM m_ordenes_compra oc
JOIN m_proveedores pr ON pr.id_proveedor = oc.id_proveedor
WHERE oc.estado IN ('Pendiente', 'Recibida Parcial');

-- 8) vista_transferencias_en_transito
--    Traslados despachados pero aún no recibidos.
CREATE OR REPLACE VIEW vista_transferencias_en_transito AS
SELECT
    t.id_transferencia,
    t.id_almacen_origen,
    ao.nombre_almacen  AS almacen_origen,
    t.id_almacen_destino,
    ad.nombre_almacen  AS almacen_destino,
    t.fecha_solicitud,
    t.fecha_despacho,
    (CURRENT_DATE - t.fecha_despacho) AS dias_en_transito
FROM m_transferencias t
JOIN m_almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN m_almacenes ad ON ad.id_almacen = t.id_almacen_destino
WHERE t.estado = 'Despachada';

-- 9) vista_devoluciones_por_producto
--    Unidades devueltas por producto y categoría.
CREATE OR REPLACE VIEW vista_devoluciones_por_producto AS
SELECT
    p.id_producto,
    p.nombre            AS producto,
    c.nombre_categoria  AS categoria,
    count(DISTINCT d.id_devolucion) AS num_devoluciones,
    SUM(dd.cantidad)                AS unidades_devueltas
FROM m_detalle_devolucion dd
JOIN m_devoluciones d ON d.id_devolucion = dd.id_devolucion
JOIN m_productos    p ON p.id_producto   = dd.id_producto
JOIN m_categorias   c ON c.id_categoria  = p.id_categoria
GROUP BY p.id_producto, p.nombre, c.nombre_categoria;

-- 10) vista_reporte_corporativo
--     Consolidado por sede (CTE agregadas por sede para evitar cartesianos).
CREATE OR REPLACE VIEW vista_reporte_corporativo AS
WITH inv AS (
    SELECT id_sede, SUM(existencia_actual) AS unidades_inventario
    FROM m_inventarios
    GROUP BY id_sede
),
inv_val AS (
    SELECT i.id_sede, SUM(i.existencia_actual * p.precio_lista) AS valor_inventario
    FROM m_inventarios i
    JOIN m_productos p ON p.id_producto = i.id_producto
    GROUP BY i.id_sede
),
ven AS (
    SELECT id_sede,
           count(*)                        AS num_pedidos,
           SUM(total_registrado)           AS total_vendido,
           count(*) FILTER (WHERE estado = 'Pendiente') AS pedidos_pendientes
    FROM m_pedidos_venta
    GROUP BY id_sede
)
SELECT
    s.id_sede,
    s.nombre_sede,
    COALESCE(inv.unidades_inventario, 0) AS unidades_inventario,
    COALESCE(iv.valor_inventario, 0)     AS valor_inventario,
    COALESCE(ven.num_pedidos, 0)         AS num_pedidos,
    COALESCE(ven.total_vendido, 0)       AS total_vendido,
    COALESCE(ven.pedidos_pendientes, 0)  AS pedidos_pendientes
FROM m_sedes s
LEFT JOIN inv     ON inv.id_sede = s.id_sede
LEFT JOIN inv_val iv ON iv.id_sede = s.id_sede
LEFT JOIN ven     ON ven.id_sede = s.id_sede;
