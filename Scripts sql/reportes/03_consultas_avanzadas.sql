-- ============================================================================
-- INSTANCIA: reportes
-- 02. Veinte (20) consultas analíticas avanzadas, numeradas
-- Motor: PostgreSQL (Neon) — se apoyan en las vistas-espejo m_* (dblink).
-- ============================================================================


-- ============================================================================
-- 1. Inventario por producto y sede (valorización estimada).
--    [tecnicas] JOIN múltiple, GROUP BY implícito no necesario (fila a fila).
-- ============================================================================
SELECT
    s.nombre_sede,
    a.nombre_almacen,
    p.nombre                          AS producto,
    c.nombre_categoria                AS categoria,
    i.existencia_actual,
    i.stock_minimo,
    (i.existencia_actual * p.precio_lista) AS valorizacion
FROM m_inventarios i
JOIN m_sedes      s ON s.id_sede      = i.id_sede
JOIN m_almacenes  a ON a.id_almacen   = i.id_almacen
JOIN m_productos  p ON p.id_producto  = i.id_producto
JOIN m_categorias c ON c.id_categoria = p.id_categoria
ORDER BY s.nombre_sede, a.nombre_almacen, p.nombre;

-- ============================================================================
-- 2. Alertas de reabastecimiento (existencia 0 o < stock mínimo).
--    [tecnicas] JOIN, filtro, orden por faltante.
-- ============================================================================
SELECT
    s.nombre_sede,
    a.nombre_almacen,
    p.nombre AS producto,
    i.existencia_actual,
    i.stock_minimo,
    (i.stock_minimo - i.existencia_actual) AS faltante
FROM m_inventarios i
JOIN m_sedes     s ON s.id_sede     = i.id_sede
JOIN m_almacenes a ON a.id_almacen  = i.id_almacen
JOIN m_productos p ON p.id_producto = i.id_producto
WHERE i.existencia_actual = 0
   OR i.existencia_actual < i.stock_minimo
ORDER BY faltante DESC;


-- ============================================================================
-- 3. Productos ausentes por sede (operación de conjuntos EXCEPT + NOT EXISTS).
--    [tecnicas] EXCEPT, NOT EXISTS, producto cartesiano controlado sede×producto.
-- ============================================================================
-- Todas las combinaciones (sede, producto activo) MENOS las que ya tienen inventario.
SELECT s.id_sede, s.nombre_sede, p.id_producto, p.nombre AS producto
FROM m_sedes s
CROSS JOIN m_productos p
WHERE p.estado = 'Activo'
EXCEPT
SELECT i.id_sede, s.nombre_sede, i.id_producto, p.nombre
FROM m_inventarios i
JOIN m_sedes s     ON s.id_sede     = i.id_sede
JOIN m_productos p ON p.id_producto = i.id_producto
ORDER BY id_sede, id_producto;

-- ============================================================================
-- 4. Ranking de los 5 productos más vendidos por sede (función de ventana).
--    [tecnicas] CTE, ROW_NUMBER() OVER (PARTITION BY ...), filtro top-5.
-- ============================================================================
WITH ventas_prod AS (
    SELECT
        pv.id_sede,
        dp.id_producto,
        SUM(dp.cantidad)                      AS unidades,
        SUM(dp.cantidad * dp.precio_unitario) AS importe
    FROM m_pedidos_venta pv
    JOIN m_detalle_pedido dp ON dp.id_pedido = pv.id_pedido
    WHERE pv.estado <> 'Cancelado'
    GROUP BY pv.id_sede, dp.id_producto
),
ranking AS (
    SELECT
        vp.*,
        ROW_NUMBER() OVER (PARTITION BY vp.id_sede ORDER BY vp.unidades DESC) AS puesto
    FROM ventas_prod vp
)
SELECT r.id_sede, s.nombre_sede, r.puesto, p.nombre AS producto, r.unidades, r.importe
FROM ranking r
JOIN m_sedes     s ON s.id_sede     = r.id_sede
JOIN m_productos p ON p.id_producto = r.id_producto
WHERE r.puesto <= 5
ORDER BY r.id_sede, r.puesto;


-- ============================================================================
-- 5. Ventas mensuales y variación vs mes anterior (LAG).
--    [tecnicas] CTE, LAG() OVER, cálculo de variación %.
-- ============================================================================
WITH ventas_mes AS (
    SELECT
        pv.id_sede,
        date_trunc('month', pv.fecha_pedido)::date AS mes,
        SUM(dp.cantidad * dp.precio_unitario)      AS importe
    FROM m_pedidos_venta pv
    JOIN m_detalle_pedido dp ON dp.id_pedido = pv.id_pedido
    WHERE pv.estado <> 'Cancelado'
    GROUP BY pv.id_sede, date_trunc('month', pv.fecha_pedido)
)
SELECT
    vm.id_sede,
    s.nombre_sede,
    vm.mes,
    vm.importe,
    LAG(vm.importe) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes) AS importe_mes_anterior,
    ROUND(
        100.0 * (vm.importe - LAG(vm.importe) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes))
        / NULLIF(LAG(vm.importe) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes), 0)
    , 2) AS variacion_pct
FROM ventas_mes vm
JOIN m_sedes s ON s.id_sede = vm.id_sede
ORDER BY vm.id_sede, vm.mes;


-- ============================================================================
-- 6. Clientes con compras multisede (UNION de evidencia + HAVING).
--    [tecnicas] GROUP BY, HAVING COUNT(DISTINCT ...) >= 2, operación de conjuntos.
-- ============================================================================
-- Se usa UNION para unificar pedidos completados y pendientes como "compras".
WITH compras AS (
    SELECT id_cliente, id_sede, total_registrado
    FROM m_pedidos_venta WHERE estado = 'Completado'
    UNION
    SELECT id_cliente, id_sede, total_registrado
    FROM m_pedidos_venta WHERE estado = 'Pendiente'
)
SELECT
    cl.id_cliente,
    cl.nombre_completo_cliente             AS cliente,
    count(DISTINCT c.id_sede)              AS sedes_visitadas,
    SUM(c.total_registrado)                AS total_comprado
FROM compras c
JOIN m_clientes cl ON cl.id_cliente = c.id_cliente
GROUP BY cl.id_cliente, cl.nombre_completo_cliente
HAVING count(DISTINCT c.id_sede) >= 2
ORDER BY sedes_visitadas DESC, total_comprado DESC;


-- ============================================================================
-- 7. Pedidos con pagos pendientes (LEFT JOIN + saldo).
--    [tecnicas] LEFT JOIN a pagos confirmados agregados, COALESCE.
-- ============================================================================
SELECT
    pv.id_pedido,
    cl.nombre_completo_cliente AS cliente,
    pv.total_registrado,
    COALESCE(pg.pagado, 0)                         AS pagos_confirmados,
    (pv.total_registrado - COALESCE(pg.pagado, 0)) AS saldo_por_pagar
FROM m_pedidos_venta pv
JOIN m_clientes cl ON cl.id_cliente = pv.id_cliente
LEFT JOIN (
    SELECT id_pedido, SUM(valor) AS pagado
    FROM m_pagos WHERE estado = 'Confirmado'
    GROUP BY id_pedido
) pg ON pg.id_pedido = pv.id_pedido
WHERE pv.estado <> 'Cancelado'
  AND (pv.total_registrado - COALESCE(pg.pagado, 0)) > 0
ORDER BY saldo_por_pagar DESC;


-- ============================================================================
-- 8. Pedidos con diversidad de productos (GROUP BY + HAVING >= 3).
--    [tecnicas] GROUP BY, HAVING COUNT(DISTINCT) >= 3.
-- ============================================================================
SELECT
    pv.id_pedido,
    pv.id_sede,
    count(DISTINCT dp.id_producto)        AS productos_distintos,
    SUM(dp.cantidad)                      AS unidades_totales,
    SUM(dp.cantidad * dp.precio_unitario) AS importe
FROM m_pedidos_venta pv
JOIN m_detalle_pedido dp ON dp.id_pedido = pv.id_pedido
GROUP BY pv.id_pedido, pv.id_sede
HAVING count(DISTINCT dp.id_producto) >= 3
ORDER BY productos_distintos DESC, importe DESC;

-- ============================================================================
-- 9. Pedidos antiguos sin completar (antigüedad > umbral).
--    [tecnicas] filtro por fecha, cálculo de días de antigüedad.
-- ============================================================================
SELECT
    pv.id_pedido,
    pv.id_sede,
    cl.nombre_completo_cliente AS cliente,
    pv.fecha_pedido,
    (CURRENT_DATE - pv.fecha_pedido) AS dias_antiguedad,
    pv.total_registrado
FROM m_pedidos_venta pv
JOIN m_clientes cl ON cl.id_cliente = pv.id_cliente
WHERE pv.estado = 'Pendiente'
  AND (CURRENT_DATE - pv.fecha_pedido) > 30    -- umbral configurable (30 días)
ORDER BY dias_antiguedad DESC;


-- ============================================================================
-- 10. Demanda frente al inventario (subconsulta CORRELACIONADA).
--     [tecnicas] subconsulta correlacionada contra inventario del mismo almacén.
-- ============================================================================
SELECT
    pv.id_pedido,
    pv.id_sede,
    pv.id_almacen,
    dp.id_producto,
    dp.cantidad       AS cantidad_pedida,
    (SELECT i.existencia_actual
       FROM m_inventarios i
      WHERE i.id_almacen  = pv.id_almacen
        AND i.id_producto = dp.id_producto) AS existencia
FROM m_pedidos_venta pv
JOIN m_detalle_pedido dp ON dp.id_pedido = pv.id_pedido
WHERE pv.estado = 'Pendiente'
  AND dp.cantidad > COALESCE(
        (SELECT i.existencia_actual
           FROM m_inventarios i
          WHERE i.id_almacen  = pv.id_almacen
            AND i.id_producto = dp.id_producto), 0)
ORDER BY pv.id_pedido;

-- ============================================================================
-- 11. Cumplimiento de proveedores (CTE + agregados).
--     [tecnicas] CTE, LEFT JOIN, AVG, conteos condicionales.
-- ============================================================================
WITH recepcion_orden AS (
    SELECT
        oc.id_orden_compra,
        oc.id_proveedor,
        oc.fecha_estimada,
        MIN(rc.fecha_recepcion) AS fecha_recepcion_real
    FROM m_ordenes_compra oc
    LEFT JOIN m_recepciones_compra rc ON rc.id_orden_compra = oc.id_orden_compra
    GROUP BY oc.id_orden_compra, oc.id_proveedor, oc.fecha_estimada
)
SELECT
    pr.id_proveedor,
    pr.razon_social AS proveedor,
    count(*)                                                              AS total_ordenes,
    count(*) FILTER (WHERE ro.fecha_recepcion_real <= ro.fecha_estimada)  AS recibidas_a_tiempo,
    count(*) FILTER (WHERE ro.fecha_recepcion_real IS NULL)               AS sin_recepcion,
    ROUND(AVG(GREATEST(ro.fecha_recepcion_real - ro.fecha_estimada, 0))
          FILTER (WHERE ro.fecha_recepcion_real IS NOT NULL), 2)          AS promedio_dias_retraso
FROM recepcion_orden ro
JOIN m_proveedores pr ON pr.id_proveedor = ro.id_proveedor
GROUP BY pr.id_proveedor, pr.razon_social
ORDER BY recibidas_a_tiempo DESC, promedio_dias_retraso;

-- ============================================================================
-- 12. Compras pendientes de recibir (solicitado vs recibido).
--     [tecnicas] LEFT JOIN a recepción agregada por producto, diferencia.
-- ============================================================================
SELECT
    doc.id_orden_compra,
    oc.estado AS estado_orden,
    doc.id_producto,
    doc.cantidad_solicitada,
    COALESCE(rec.recibido, 0)                       AS cantidad_recibida,
    (doc.cantidad_solicitada - COALESCE(rec.recibido, 0)) AS pendiente
FROM m_detalle_orden_compra doc
JOIN m_ordenes_compra oc ON oc.id_orden_compra = doc.id_orden_compra
LEFT JOIN (
    SELECT rc.id_orden_compra, dr.id_producto, SUM(dr.cantidad_recibida) AS recibido
    FROM m_detalle_recepcion dr
    JOIN m_recepciones_compra rc ON rc.id_recepcion = dr.id_recepcion
    GROUP BY rc.id_orden_compra, dr.id_producto
) rec ON rec.id_orden_compra = doc.id_orden_compra AND rec.id_producto = doc.id_producto
WHERE (doc.cantidad_solicitada - COALESCE(rec.recibido, 0)) > 0
ORDER BY doc.id_orden_compra, doc.id_producto;


-- ============================================================================
-- 13. Transferencias en tránsito (despachadas, no recibidas).
--     [tecnicas] JOIN a almacenes origen/destino, días transcurridos.
-- ============================================================================
SELECT
    t.id_transferencia,
    ao.nombre_almacen AS origen,
    ad.nombre_almacen AS destino,
    dt.id_producto,
    dt.cantidad_enviada,
    t.fecha_despacho,
    (CURRENT_DATE - t.fecha_despacho) AS dias_transcurridos
FROM m_transferencias t
JOIN m_almacenes ao            ON ao.id_almacen = t.id_almacen_origen
JOIN m_almacenes ad            ON ad.id_almacen = t.id_almacen_destino
JOIN m_detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
WHERE t.estado = 'Despachada'
ORDER BY dias_transcurridos DESC;

-- ============================================================================
-- 14. Diferencias entre enviado y recibido por producto.
--     [tecnicas] filtro sobre cantidad_recibida <> cantidad_enviada.
-- ============================================================================
SELECT
    t.id_transferencia,
    t.estado,
    dt.id_producto,
    dt.cantidad_enviada,
    dt.cantidad_recibida,
    (dt.cantidad_enviada - dt.cantidad_recibida) AS diferencia
FROM m_detalle_transferencia dt
JOIN m_transferencias t ON t.id_transferencia = dt.id_transferencia
WHERE dt.cantidad_recibida IS NOT NULL
  AND dt.cantidad_recibida <> dt.cantidad_enviada
ORDER BY ABS(dt.cantidad_enviada - dt.cantidad_recibida) DESC;

-- ============================================================================
-- 15. Redistribución de productos (excedente en una sede, faltante en otra).
--     [tecnicas] CTE, self-join entre sedes para el mismo producto.
-- ============================================================================
WITH stock_sede AS (
    SELECT id_sede, id_producto,
           SUM(existencia_actual) AS existencia,
           SUM(stock_minimo)      AS minimo
    FROM m_inventarios
    GROUP BY id_sede, id_producto
)
SELECT
    e.id_producto,
    p.nombre              AS producto,
    e.id_sede             AS sede_excedente,
    e.existencia          AS existencia_excedente,
    f.id_sede             AS sede_faltante,
    f.existencia          AS existencia_faltante
FROM stock_sede e
JOIN stock_sede f ON f.id_producto = e.id_producto AND f.id_sede <> e.id_sede
JOIN m_productos p ON p.id_producto = e.id_producto
WHERE e.existencia > e.minimo          -- sede con excedente
  AND f.existencia < f.minimo          -- sede con faltante
ORDER BY e.id_producto, e.id_sede, f.id_sede;

-- ============================================================================
-- 16. Productos de baja rotación (existencia > 0, sin ventas en 90 días).
--     [tecnicas] CTE, NOT EXISTS con subconsulta correlacionada por fecha.
-- ============================================================================
WITH con_stock AS (
    SELECT DISTINCT id_producto
    FROM m_inventarios
    WHERE existencia_actual > 0
)
SELECT
    p.id_producto,
    p.nombre AS producto
FROM con_stock cs
JOIN m_productos p ON p.id_producto = cs.id_producto
WHERE NOT EXISTS (
    SELECT 1
    FROM m_pedidos_venta pv
    JOIN m_detalle_pedido dp ON dp.id_pedido = pv.id_pedido
    WHERE dp.id_producto = cs.id_producto
      AND pv.estado = 'Completado'
      AND pv.fecha_pedido >= CURRENT_DATE - INTERVAL '90 days'
)
ORDER BY p.id_producto;

-- ============================================================================
-- 17. Devoluciones por producto y categoría (% de devolución).
--     [tecnicas] CTE (vendido vs devuelto), LEFT JOIN, razón porcentual.
-- ============================================================================
WITH vendido AS (
    SELECT dp.id_producto, SUM(dp.cantidad) AS unidades_vendidas
    FROM m_pedidos_venta pv
    JOIN m_detalle_pedido dp ON dp.id_pedido = pv.id_pedido
    WHERE pv.estado = 'Completado'
    GROUP BY dp.id_producto
),
devuelto AS (
    SELECT dd.id_producto, SUM(dd.cantidad) AS unidades_devueltas
    FROM m_detalle_devolucion dd
    JOIN m_devoluciones d ON d.id_devolucion = dd.id_devolucion
    GROUP BY dd.id_producto
)
SELECT
    p.id_producto,
    p.nombre            AS producto,
    c.nombre_categoria  AS categoria,
    COALESCE(v.unidades_vendidas, 0)   AS vendidas,
    COALESCE(dv.unidades_devueltas, 0) AS devueltas,
    ROUND(100.0 * COALESCE(dv.unidades_devueltas, 0)
          / NULLIF(v.unidades_vendidas, 0), 2) AS pct_devolucion
FROM m_productos p
JOIN m_categorias c ON c.id_categoria = p.id_categoria
LEFT JOIN vendido  v  ON v.id_producto  = p.id_producto
LEFT JOIN devuelto dv ON dv.id_producto = p.id_producto
WHERE COALESCE(dv.unidades_devueltas, 0) > 0
ORDER BY pct_devolucion DESC NULLS LAST;


-- ============================================================================
-- 18. Comparación de surtido entre dos sedes (INTERSECT y EXCEPT).
--     [tecnicas] operaciones de conjuntos INTERSECT / EXCEPT.
-- ============================================================================
-- Productos COMUNES a la sede 1 y la sede 3 (INTERSECT):
SELECT id_producto FROM m_inventarios WHERE id_sede = 1
INTERSECT
SELECT id_producto FROM m_inventarios WHERE id_sede = 3;

-- Productos que están en la sede 1 pero NO en la sede 3 (EXCEPT):
SELECT id_producto FROM m_inventarios WHERE id_sede = 1
EXCEPT
SELECT id_producto FROM m_inventarios WHERE id_sede = 3;


-- ============================================================================
-- 19. Clasificación de vendedores por sede (RANK).
--     [tecnicas] agregación por empleado, RANK() OVER (PARTITION BY sede).
-- ============================================================================
WITH ventas_emp AS (
    SELECT
        pv.id_sede,
        pv.id_empleado,
        SUM(pv.total_registrado) AS total_vendido
    FROM m_pedidos_venta pv
    WHERE pv.estado = 'Completado'
    GROUP BY pv.id_sede, pv.id_empleado
)
SELECT
    ve.id_sede,
    s.nombre_sede,
    e.nombre_completo AS vendedor,
    ve.total_vendido,
    RANK() OVER (PARTITION BY ve.id_sede ORDER BY ve.total_vendido DESC) AS puesto
FROM ventas_emp ve
JOIN m_sedes     s ON s.id_sede     = ve.id_sede
JOIN m_empleados e ON e.id_empleado = ve.id_empleado
ORDER BY ve.id_sede, puesto;


-- ============================================================================
-- 20. Consolidado corporativo por sede (CTE para evitar conteos duplicados).
--     [tecnicas] múltiples CTE agregadas por sede + LEFT JOIN de consolidación.
-- ============================================================================
WITH prod_activos AS (
    -- productos activos son globales; se repiten por sede como catálogo potencial
    SELECT count(*) AS n_productos_activos FROM m_productos WHERE estado = 'Activo'
),
inv AS (
    SELECT i.id_sede,
           SUM(i.existencia_actual)                  AS unidades_inventario,
           SUM(i.existencia_actual * p.precio_lista) AS valor_inventario
    FROM m_inventarios i
    JOIN m_productos p ON p.id_producto = i.id_producto
    GROUP BY i.id_sede
),
ven AS (
    SELECT id_sede,
           count(*)                                      AS num_pedidos,
           SUM(total_registrado)                         AS total_vendido,
           count(*) FILTER (WHERE estado = 'Pendiente')  AS pedidos_pendientes
    FROM m_pedidos_venta
    GROUP BY id_sede
),
comp AS (
    SELECT ad.id_sede, count(*) AS num_ordenes_compra
    FROM m_ordenes_compra oc
    JOIN m_almacenes ad ON ad.id_almacen = oc.id_almacen_destino
    GROUP BY ad.id_sede
),
transf AS (
    SELECT ao.id_sede, count(*) AS num_transferencias_salida
    FROM m_transferencias t
    JOIN m_almacenes ao ON ao.id_almacen = t.id_almacen_origen
    GROUP BY ao.id_sede
)
SELECT
    s.id_sede,
    s.nombre_sede,
    (SELECT n_productos_activos FROM prod_activos) AS productos_activos,
    COALESCE(inv.unidades_inventario, 0)  AS unidades_inventario,
    COALESCE(inv.valor_inventario, 0)     AS valor_inventario,
    COALESCE(ven.num_pedidos, 0)          AS pedidos,
    COALESCE(ven.total_vendido, 0)        AS total_vendido,
    COALESCE(ven.pedidos_pendientes, 0)   AS pedidos_pendientes,
    COALESCE(comp.num_ordenes_compra, 0)  AS ordenes_compra,
    COALESCE(transf.num_transferencias_salida, 0) AS transferencias_salida
FROM m_sedes s
LEFT JOIN inv    ON inv.id_sede    = s.id_sede
LEFT JOIN ven    ON ven.id_sede    = s.id_sede
LEFT JOIN comp   ON comp.id_sede   = s.id_sede
LEFT JOIN transf ON transf.id_sede = s.id_sede
ORDER BY s.id_sede;
