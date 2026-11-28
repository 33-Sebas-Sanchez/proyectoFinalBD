-- ============================================================================
-- MICROSERVICIO: reportes
-- 03. Veinte consultas SQL analíticas obligatorias (numeradas 01..20)
-- Motor: PostgreSQL 18 / Neon (ejecutar contra la base `reportes`)
-- ----------------------------------------------------------------------------
-- Fecha de corte reproducible del cierre cuatrimestral: 2026-11-30
-- Cobertura técnica requerida:
--   JOIN, LEFT JOIN, NOT EXISTS, subconsultas correlacionadas, GROUP BY, HAVING,
--   >= 4 CTEs (WITH), >= 3 funciones de ventana (DENSE_RANK, LAG, RANK),
--   >= 2 operaciones de conjuntos (UNION ALL, INTERSECT, EXCEPT).
-- ============================================================================

\echo '=== CONSULTA 01: Inventario por producto y sede (UNION ALL + JOIN) ==='
SELECT
    inv.id_sede,
    s.nombre_sede,
    a.nombre_almacen,
    p.sku,
    p.nombre AS producto,
    c.nombre_categoria AS categoria,
    inv.existencia_actual,
    inv.stock_minimo,
    ROUND((inv.existencia_actual * p.precio_lista)::numeric, 2) AS valorizacion_estimada
FROM reportes.vista_inventarios_fragmentos_union inv
JOIN catalogo_terceros.sedes s      ON s.id_sede = inv.id_sede
JOIN catalogo_terceros.almacenes a  ON a.id_almacen = inv.id_almacen
JOIN catalogo_terceros.productos p  ON p.id_producto = inv.id_producto
JOIN catalogo_terceros.categorias c ON c.id_categoria = p.id_categoria
ORDER BY inv.id_sede, a.id_almacen, valorizacion_estimada DESC;

\echo '=== CONSULTA 02: Alertas de reabastecimiento ==='
SELECT
    s.nombre_sede,
    a.nombre_almacen,
    p.sku,
    p.nombre AS producto,
    inv.existencia_actual,
    inv.stock_minimo,
    (inv.stock_minimo - inv.existencia_actual) AS faltante
FROM inventarios_transferencias.inventarios inv
JOIN catalogo_terceros.sedes s     ON s.id_sede = inv.id_sede
JOIN catalogo_terceros.almacenes a ON a.id_almacen = inv.id_almacen
JOIN catalogo_terceros.productos p ON p.id_producto = inv.id_producto
WHERE inv.existencia_actual = 0
   OR inv.existencia_actual < inv.stock_minimo
ORDER BY faltante DESC, inv.existencia_actual ASC, s.id_sede;

\echo '=== CONSULTA 03: Productos ausentes por sede (NOT EXISTS correlacionado) ==='
SELECT
    p.id_producto,
    p.sku,
    p.nombre AS producto,
    c.nombre_categoria,
    COUNT(s.id_sede) AS sedes_sin_registro,
    STRING_AGG(s.nombre_sede, ', ' ORDER BY s.id_sede) AS sedes_ausentes
FROM catalogo_terceros.productos p
JOIN catalogo_terceros.categorias c ON c.id_categoria = p.id_categoria
CROSS JOIN catalogo_terceros.sedes s
WHERE p.estado = 'Activo'
  AND NOT EXISTS (
      SELECT 1
      FROM inventarios_transferencias.inventarios inv
      WHERE inv.id_sede = s.id_sede
        AND inv.id_producto = p.id_producto
  )
GROUP BY p.id_producto, p.sku, p.nombre, c.nombre_categoria
ORDER BY sedes_sin_registro DESC, p.id_producto;

\echo '=== CONSULTA 04: Ranking Top 5 productos por sede y periodo (CTE + DENSE_RANK) ==='
WITH ventas_producto_mes AS (
    SELECT
        pv.id_sede,
        TO_CHAR(pv.fecha_pedido, 'YYYY-MM') AS periodo,
        dp.id_producto,
        SUM(dp.cantidad) AS unidades_vendidas,
        SUM(dp.cantidad * dp.precio_unitario) AS importe_vendido
    FROM ventas_pagos.pedidos_venta pv
    JOIN ventas_pagos.detalle_pedido dp
      ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
    WHERE pv.estado = 'Completado'
    GROUP BY pv.id_sede, TO_CHAR(pv.fecha_pedido, 'YYYY-MM'), dp.id_producto
),
ranking_sede AS (
    SELECT
        vpm.*,
        DENSE_RANK() OVER (
            PARTITION BY vpm.id_sede, vpm.periodo
            ORDER BY vpm.importe_vendido DESC, vpm.unidades_vendidas DESC
        ) AS puesto
    FROM ventas_producto_mes vpm
)
SELECT
    r.id_sede,
    s.nombre_sede,
    r.periodo,
    r.puesto,
    p.sku,
    p.nombre AS producto,
    r.unidades_vendidas,
    ROUND(r.importe_vendido::numeric, 2) AS importe_vendido
FROM ranking_sede r
JOIN catalogo_terceros.sedes s     ON s.id_sede = r.id_sede
JOIN catalogo_terceros.productos p ON p.id_producto = r.id_producto
WHERE r.puesto <= 5
ORDER BY r.id_sede, r.periodo, r.puesto, p.id_producto;

\echo '=== CONSULTA 05: Ventas mensuales y variación contra mes anterior (CTE + LAG) ==='
WITH ventas_mensuales AS (
    SELECT
        pv.id_sede,
        DATE_TRUNC('month', pv.fecha_pedido)::date AS mes_inicio,
        TO_CHAR(pv.fecha_pedido, 'YYYY-MM') AS periodo,
        COUNT(*) AS pedidos_completados,
        SUM(pv.total_registrado) AS total_vendido
    FROM ventas_pagos.pedidos_venta pv
    WHERE pv.estado = 'Completado'
    GROUP BY pv.id_sede, DATE_TRUNC('month', pv.fecha_pedido)::date, TO_CHAR(pv.fecha_pedido, 'YYYY-MM')
)
SELECT
    vm.id_sede,
    s.nombre_sede,
    vm.periodo,
    vm.pedidos_completados,
    ROUND(vm.total_vendido::numeric, 2) AS total_vendido,
    ROUND(LAG(vm.total_vendido) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes_inicio)::numeric, 2) AS mes_anterior,
    ROUND((vm.total_vendido - LAG(vm.total_vendido) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes_inicio))::numeric, 2) AS variacion_absoluta,
    ROUND(((vm.total_vendido - LAG(vm.total_vendido) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes_inicio))
           / NULLIF(LAG(vm.total_vendido) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes_inicio), 0) * 100)::numeric, 2) AS variacion_pct
FROM ventas_mensuales vm
JOIN catalogo_terceros.sedes s ON s.id_sede = vm.id_sede
ORDER BY vm.id_sede, vm.mes_inicio;

\echo '=== CONSULTA 06: Clientes con compras multisede (GROUP BY + HAVING) ==='
SELECT
    c.id_cliente,
    c.num_documento,
    c.nombre_completo_cliente,
    COUNT(DISTINCT pv.id_sede) AS sedes_visitadas,
    STRING_AGG(DISTINCT s.nombre_sede, ' | ' ORDER BY s.nombre_sede) AS detalle_sedes,
    COUNT(*) AS pedidos_completados,
    ROUND(SUM(pv.total_registrado)::numeric, 2) AS total_comprado
FROM ventas_pagos.pedidos_venta pv
JOIN catalogo_terceros.clientes c ON c.id_cliente = pv.id_cliente
JOIN catalogo_terceros.sedes s    ON s.id_sede = pv.id_sede
WHERE pv.estado = 'Completado'
GROUP BY c.id_cliente, c.num_documento, c.nombre_completo_cliente
HAVING COUNT(DISTINCT pv.id_sede) >= 2
ORDER BY sedes_visitadas DESC, total_comprado DESC, c.id_cliente;

\echo '=== CONSULTA 07: Pedidos con pagos pendientes (CTE + LEFT JOIN) ==='
WITH pagos_confirmados AS (
    SELECT
        pg.id_sede,
        pg.id_pedido,
        SUM(pg.valor) AS acumulado_confirmado
    FROM ventas_pagos.pagos pg
    WHERE pg.estado = 'Confirmado'
    GROUP BY pg.id_sede, pg.id_pedido
)
SELECT
    pv.id_pedido,
    s.nombre_sede,
    c.nombre_completo_cliente AS cliente,
    pv.estado AS estado_pedido,
    pv.fecha_pedido,
    pv.total_registrado,
    COALESCE(pc.acumulado_confirmado, 0.00) AS pagos_confirmados,
    (pv.total_registrado - COALESCE(pc.acumulado_confirmado, 0.00)) AS saldo_por_pagar
FROM ventas_pagos.pedidos_venta pv
JOIN catalogo_terceros.sedes s    ON s.id_sede = pv.id_sede
JOIN catalogo_terceros.clientes c ON c.id_cliente = pv.id_cliente
LEFT JOIN pagos_confirmados pc    ON pc.id_sede = pv.id_sede AND pc.id_pedido = pv.id_pedido
WHERE pv.estado <> 'Cancelado'
  AND (pv.total_registrado - COALESCE(pc.acumulado_confirmado, 0.00)) > 0
ORDER BY (CASE WHEN COALESCE(pc.acumulado_confirmado, 0.00) > 0 THEN 0 ELSE 1 END),
         saldo_por_pagar DESC,
         pv.id_pedido;

\echo '=== CONSULTA 08: Pedidos con diversidad de productos (>= 3 distintos, HAVING) ==='
SELECT
    pv.id_sede,
    pv.id_pedido,
    s.nombre_sede,
    pv.fecha_pedido,
    pv.estado,
    COUNT(DISTINCT dp.id_producto) AS productos_distintos,
    SUM(dp.cantidad) AS total_unidades,
    pv.total_registrado AS importe_registrado
FROM ventas_pagos.pedidos_venta pv
JOIN ventas_pagos.detalle_pedido dp
  ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
JOIN catalogo_terceros.sedes s ON s.id_sede = pv.id_sede
GROUP BY pv.id_sede, pv.id_pedido, s.nombre_sede, pv.fecha_pedido, pv.estado, pv.total_registrado
HAVING COUNT(DISTINCT dp.id_producto) >= 3
ORDER BY productos_distintos DESC, importe_registrado DESC, pv.id_pedido;

\echo '=== CONSULTA 09: Pedidos antiguos sin completar (> 30 días respecto a 2026-11-30) ==='
SELECT
    pv.id_pedido,
    s.nombre_sede,
    c.nombre_completo_cliente AS cliente,
    e.nombre_completo AS vendedor,
    pv.fecha_pedido,
    (DATE '2026-11-30' - pv.fecha_pedido) AS dias_antiguedad,
    pv.total_registrado
FROM ventas_pagos.pedidos_venta pv
JOIN catalogo_terceros.sedes s     ON s.id_sede = pv.id_sede
JOIN catalogo_terceros.clientes c  ON c.id_cliente = pv.id_cliente
JOIN identidad_accesos.empleados e ON e.id_empleado = pv.id_empleado
WHERE pv.estado = 'Pendiente'
  AND (DATE '2026-11-30' - pv.fecha_pedido) > 30
ORDER BY dias_antiguedad DESC, pv.id_pedido;

\echo '=== CONSULTA 10: Demanda frente al inventario (subconsulta correlacionada + JOIN) ==='
SELECT
    pv.id_pedido,
    s.nombre_sede,
    a.nombre_almacen,
    p.sku,
    p.nombre AS producto,
    dp.cantidad AS cantidad_solicitada,
    inv.existencia_actual,
    (dp.cantidad - inv.existencia_actual) AS deficit_unidades
FROM ventas_pagos.pedidos_venta pv
JOIN ventas_pagos.detalle_pedido dp
  ON dp.id_sede = pv.id_sede AND dp.id_pedido = pv.id_pedido
JOIN inventarios_transferencias.inventarios inv
  ON inv.id_almacen = pv.id_almacen AND inv.id_producto = dp.id_producto
JOIN catalogo_terceros.sedes s     ON s.id_sede = pv.id_sede
JOIN catalogo_terceros.almacenes a ON a.id_almacen = pv.id_almacen
JOIN catalogo_terceros.productos p ON p.id_producto = dp.id_producto
WHERE pv.estado = 'Pendiente'
  AND dp.cantidad > (
      SELECT inv2.existencia_actual
      FROM inventarios_transferencias.inventarios inv2
      WHERE inv2.id_almacen = pv.id_almacen
        AND inv2.id_producto = dp.id_producto
  )
ORDER BY deficit_unidades DESC, pv.id_pedido;

\echo '=== CONSULTA 11: Cumplimiento de proveedores (CTE + LEFT JOIN) ==='
WITH primera_recepcion AS (
    SELECT
        rc.id_orden_compra,
        MIN(rc.fecha_recepcion) AS fecha_recepcion_efectiva
    FROM compras_abastecimiento.recepciones_compra rc
    WHERE rc.estado <> 'Anulado'
    GROUP BY rc.id_orden_compra
)
SELECT
    pr.id_proveedor,
    pr.razon_social,
    COUNT(oc.id_orden_compra) AS total_ordenes,
    COUNT(fr.fecha_recepcion_efectiva) AS ordenes_recibidas,
    COUNT(*) FILTER (
        WHERE fr.fecha_recepcion_efectiva IS NOT NULL
          AND fr.fecha_recepcion_efectiva <= oc.fecha_estimada
    ) AS recibidas_a_tiempo,
    ROUND(
        AVG(GREATEST(fr.fecha_recepcion_efectiva - oc.fecha_estimada, 0))
            FILTER (WHERE fr.fecha_recepcion_efectiva IS NOT NULL)::numeric,
        2
    ) AS promedio_dias_retraso
FROM catalogo_terceros.proveedores pr
JOIN compras_abastecimiento.ordenes_compra oc ON oc.id_proveedor = pr.id_proveedor
LEFT JOIN primera_recepcion fr                ON fr.id_orden_compra = oc.id_orden_compra
WHERE oc.estado <> 'Cancelada'
GROUP BY pr.id_proveedor, pr.razon_social
ORDER BY promedio_dias_retraso DESC NULLS LAST, total_ordenes DESC;

\echo '=== CONSULTA 12: Compras pendientes de recibir (CTE + LEFT JOIN) ==='
WITH acumulado_recibido AS (
    SELECT
        rc.id_orden_compra,
        dr.id_producto,
        SUM(dr.cantidad_recibida) AS total_recibido
    FROM compras_abastecimiento.recepciones_compra rc
    JOIN compras_abastecimiento.detalle_recepcion dr ON dr.id_recepcion = rc.id_recepcion
    WHERE rc.estado <> 'Anulado'
    GROUP BY rc.id_orden_compra, dr.id_producto
)
SELECT
    oc.id_orden_compra,
    oc.estado,
    pr.razon_social AS proveedor,
    p.sku,
    p.nombre AS producto,
    doc.cantidad_solicitada,
    COALESCE(ar.total_recibido, 0) AS cantidad_recibida,
    (doc.cantidad_solicitada - COALESCE(ar.total_recibido, 0)) AS pendiente_por_recibir
FROM compras_abastecimiento.ordenes_compra oc
JOIN compras_abastecimiento.detalle_orden_compra doc ON doc.id_orden_compra = oc.id_orden_compra
JOIN catalogo_terceros.proveedores pr                ON pr.id_proveedor = oc.id_proveedor
JOIN catalogo_terceros.productos p                   ON p.id_producto = doc.id_producto
LEFT JOIN acumulado_recibido ar
       ON ar.id_orden_compra = doc.id_orden_compra
      AND ar.id_producto = doc.id_producto
WHERE oc.estado IN ('Pendiente', 'Recibida Parcial')
  AND (doc.cantidad_solicitada - COALESCE(ar.total_recibido, 0)) > 0
ORDER BY oc.id_orden_compra, p.id_producto;

\echo '=== CONSULTA 13: Transferencias en tránsito (corte 2026-11-30) ==='
SELECT
    t.id_transferencia,
    ao.nombre_almacen || ' (' || so.nombre_sede || ')' AS origen,
    ad.nombre_almacen || ' (' || sd.nombre_sede || ')' AS destino,
    t.fecha_solicitud,
    t.fecha_despacho,
    (DATE '2026-11-30' - t.fecha_despacho) AS dias_transcurridos,
    STRING_AGG(p.sku || ' (' || dt.cantidad_enviada || ' uds)', ', ' ORDER BY p.id_producto) AS productos_en_transito
FROM inventarios_transferencias.transferencias t
JOIN inventarios_transferencias.detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN catalogo_terceros.almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN catalogo_terceros.sedes so     ON so.id_sede = ao.id_sede
JOIN catalogo_terceros.almacenes ad ON ad.id_almacen = t.id_almacen_destino
JOIN catalogo_terceros.sedes sd     ON sd.id_sede = ad.id_sede
JOIN catalogo_terceros.productos p  ON p.id_producto = dt.id_producto
WHERE t.estado = 'Despachada'
  AND t.fecha_recepcion IS NULL
GROUP BY t.id_transferencia, ao.nombre_almacen, so.nombre_sede, ad.nombre_almacen, sd.nombre_sede,
         t.fecha_solicitud, t.fecha_despacho
ORDER BY dias_transcurridos DESC, t.id_transferencia;

\echo '=== CONSULTA 14: Diferencias entre enviado y recibido en transferencias ==='
SELECT
    t.id_transferencia,
    t.fecha_recepcion,
    ao.nombre_almacen AS almacen_origen,
    ad.nombre_almacen AS almacen_destino,
    p.sku,
    p.nombre AS producto,
    dt.cantidad_enviada,
    dt.cantidad_recibida,
    (dt.cantidad_enviada - dt.cantidad_recibida) AS diferencia_unidades
FROM inventarios_transferencias.transferencias t
JOIN inventarios_transferencias.detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN catalogo_terceros.almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN catalogo_terceros.almacenes ad ON ad.id_almacen = t.id_almacen_destino
JOIN catalogo_terceros.productos p  ON p.id_producto = dt.id_producto
WHERE dt.cantidad_recibida IS NOT NULL
  AND dt.cantidad_recibida <> dt.cantidad_enviada
ORDER BY diferencia_unidades DESC, t.id_transferencia;

\echo '=== CONSULTA 15: Redistribución de productos entre sedes (CTE excedente vs faltante) ==='
WITH stock_por_sede AS (
    SELECT
        inv.id_sede,
        s.nombre_sede,
        inv.id_producto,
        SUM(inv.existencia_actual) AS existencia_sede,
        SUM(inv.stock_minimo)      AS stock_minimo_sede
    FROM inventarios_transferencias.inventarios inv
    JOIN catalogo_terceros.sedes s ON s.id_sede = inv.id_sede
    GROUP BY inv.id_sede, s.nombre_sede, inv.id_producto
)
SELECT
    p.id_producto,
    p.sku,
    p.nombre AS producto,
    ex.nombre_sede AS sede_con_excedente,
    (ex.existencia_sede - ex.stock_minimo_sede) AS excedente_disponible,
    fa.nombre_sede AS sede_con_faltante,
    (fa.stock_minimo_sede - fa.existencia_sede) AS faltante_requerido
FROM stock_por_sede ex
JOIN stock_por_sede fa
  ON fa.id_producto = ex.id_producto
 AND fa.id_sede <> ex.id_sede
JOIN catalogo_terceros.productos p ON p.id_producto = ex.id_producto
WHERE ex.existencia_sede > ex.stock_minimo_sede + 20
  AND fa.existencia_sede < fa.stock_minimo_sede
ORDER BY faltante_requerido DESC, excedente_disponible DESC, p.id_producto;

\echo '=== CONSULTA 16: Productos de baja rotación (stock > 0 sin ventas confirmadas 90 días antes de 2026-11-30, NOT EXISTS) ==='
SELECT
    p.id_producto,
    p.sku,
    p.nombre AS producto,
    c.nombre_categoria,
    SUM(inv.existencia_actual) AS existencia_total,
    MAX(inv.fecha_actualizacion) AS ultima_actualizacion_stock
FROM inventarios_transferencias.inventarios inv
JOIN catalogo_terceros.productos p  ON p.id_producto = inv.id_producto
JOIN catalogo_terceros.categorias c ON c.id_categoria = p.id_categoria
WHERE inv.existencia_actual > 0
  AND NOT EXISTS (
      SELECT 1
      FROM ventas_pagos.detalle_pedido dp
      JOIN ventas_pagos.pedidos_venta pv
        ON pv.id_sede = dp.id_sede AND pv.id_pedido = dp.id_pedido
      WHERE dp.id_producto = inv.id_producto
        AND pv.estado = 'Completado'
        AND pv.fecha_pedido >= (DATE '2026-11-30' - INTERVAL '90 days')
  )
GROUP BY p.id_producto, p.sku, p.nombre, c.nombre_categoria
ORDER BY existencia_total DESC, p.id_producto;

\echo '=== CONSULTA 17A: Devoluciones por producto (CTEs separadas) ==='
WITH ventas_prod AS (
    SELECT
        dp.id_producto,
        SUM(dp.cantidad) AS unidades_vendidas
    FROM ventas_pagos.detalle_pedido dp
    JOIN ventas_pagos.pedidos_venta pv
      ON pv.id_sede = dp.id_sede AND pv.id_pedido = dp.id_pedido
    WHERE pv.estado = 'Completado'
      AND pv.fecha_pedido BETWEEN DATE '2026-07-28' AND DATE '2026-11-30'
    GROUP BY dp.id_producto
),
devoluciones_prod AS (
    SELECT
        dd.id_producto,
        COUNT(DISTINCT d.id_devolucion) AS cantidad_devoluciones,
        SUM(dd.cantidad) AS unidades_devueltas
    FROM ventas_pagos.detalle_devolucion dd
    JOIN ventas_pagos.devoluciones d ON d.id_devolucion = dd.id_devolucion
    WHERE d.fecha_solicitud BETWEEN DATE '2026-07-28' AND DATE '2026-12-10'
    GROUP BY dd.id_producto
)
SELECT
    p.id_producto,
    p.sku,
    p.nombre AS producto,
    c.nombre_categoria AS categoria,
    COALESCE(vp.unidades_vendidas, 0) AS unidades_vendidas,
    dp.cantidad_devoluciones,
    dp.unidades_devueltas,
    ROUND((dp.unidades_devueltas::numeric / NULLIF(vp.unidades_vendidas, 0)) * 100, 2) AS porcentaje_devolucion
FROM devoluciones_prod dp
JOIN catalogo_terceros.productos p  ON p.id_producto = dp.id_producto
JOIN catalogo_terceros.categorias c ON c.id_categoria = p.id_categoria
LEFT JOIN ventas_prod vp            ON vp.id_producto = dp.id_producto
ORDER BY porcentaje_devolucion DESC NULLS LAST, dp.unidades_devueltas DESC;

\echo '=== CONSULTA 17B: Devoluciones consolidadas por categoría (CTEs separadas) ==='
WITH ventas_cat AS (
    SELECT
        p.id_categoria,
        SUM(dp.cantidad) AS unidades_vendidas
    FROM ventas_pagos.detalle_pedido dp
    JOIN ventas_pagos.pedidos_venta pv
      ON pv.id_sede = dp.id_sede AND pv.id_pedido = dp.id_pedido
    JOIN catalogo_terceros.productos p ON p.id_producto = dp.id_producto
    WHERE pv.estado = 'Completado'
      AND pv.fecha_pedido BETWEEN DATE '2026-07-28' AND DATE '2026-11-30'
    GROUP BY p.id_categoria
),
dev_cat AS (
    SELECT
        p.id_categoria,
        COUNT(DISTINCT d.id_devolucion) AS cantidad_devoluciones,
        SUM(dd.cantidad) AS unidades_devueltas
    FROM ventas_pagos.detalle_devolucion dd
    JOIN ventas_pagos.devoluciones d   ON d.id_devolucion = dd.id_devolucion
    JOIN catalogo_terceros.productos p ON p.id_producto = dd.id_producto
    WHERE d.fecha_solicitud BETWEEN DATE '2026-07-28' AND DATE '2026-12-10'
    GROUP BY p.id_categoria
)
SELECT
    c.id_categoria,
    c.nombre_categoria AS categoria,
    COALESCE(vc.unidades_vendidas, 0) AS unidades_vendidas,
    COALESCE(dc.cantidad_devoluciones, 0) AS cantidad_devoluciones,
    COALESCE(dc.unidades_devueltas, 0) AS unidades_devueltas,
    ROUND((COALESCE(dc.unidades_devueltas, 0)::numeric / NULLIF(vc.unidades_vendidas, 0)) * 100, 2) AS porcentaje_devolucion
FROM catalogo_terceros.categorias c
LEFT JOIN ventas_cat vc ON vc.id_categoria = c.id_categoria
LEFT JOIN dev_cat dc    ON dc.id_categoria = c.id_categoria
ORDER BY porcentaje_devolucion DESC NULLS LAST, c.id_categoria;

\echo '=== CONSULTA 18A: Comparación de surtido — Productos en Sede 1 pero NO en Sede 3 (EXCEPT) ==='
SELECT p.id_producto, p.sku, p.nombre
FROM inventarios_transferencias.inventarios_sede_1 i1
JOIN catalogo_terceros.productos p ON p.id_producto = i1.id_producto
EXCEPT
SELECT p.id_producto, p.sku, p.nombre
FROM inventarios_transferencias.inventarios_sede_3 i3
JOIN catalogo_terceros.productos p ON p.id_producto = i3.id_producto
ORDER BY id_producto;

\echo '=== CONSULTA 18B: Comparación de surtido — Productos comunes entre Sede 1 y Sede 3 (INTERSECT) ==='
SELECT p.id_producto, p.sku, p.nombre
FROM inventarios_transferencias.inventarios_sede_1 i1
JOIN catalogo_terceros.productos p ON p.id_producto = i1.id_producto
INTERSECT
SELECT p.id_producto, p.sku, p.nombre
FROM inventarios_transferencias.inventarios_sede_3 i3
JOIN catalogo_terceros.productos p ON p.id_producto = i3.id_producto
ORDER BY id_producto;

\echo '=== CONSULTA 19: Clasificación de vendedores por sede (CTE + RANK) ==='
WITH ventas_vendedor AS (
    SELECT
        pv.id_sede,
        pv.id_empleado,
        COUNT(*) AS pedidos_completados,
        SUM(pv.total_registrado) AS total_vendido
    FROM ventas_pagos.pedidos_venta pv
    WHERE pv.estado = 'Completado'
    GROUP BY pv.id_sede, pv.id_empleado
)
SELECT
    vv.id_sede,
    s.nombre_sede,
    RANK() OVER (PARTITION BY vv.id_sede ORDER BY vv.total_vendido DESC) AS puesto_en_sede,
    e.id_empleado,
    e.nombre_completo AS vendedor,
    vv.pedidos_completados,
    ROUND(vv.total_vendido::numeric, 2) AS total_vendido
FROM ventas_vendedor vv
JOIN catalogo_terceros.sedes s     ON s.id_sede = vv.id_sede
JOIN identidad_accesos.empleados e ON e.id_empleado = vv.id_empleado
ORDER BY vv.id_sede, puesto_en_sede, e.id_empleado;

\echo '=== CONSULTA 20: Consolidado corporativo por sede (CTEs agregadas sin duplicación) ==='
SELECT * FROM reportes.vista_reporte_corporativo;
