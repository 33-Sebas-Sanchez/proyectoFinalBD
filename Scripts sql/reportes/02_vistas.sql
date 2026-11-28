-- ============================================================================
-- MICROSERVICIO: reportes
-- 02. Vistas de integración de fragmentos (UNION ALL) y 10 vistas SQL obligatorias
-- Motor: PostgreSQL 18 / Neon
-- ----------------------------------------------------------------------------
-- Vistas incluidas en el esquema `reportes`:
--   * Vistas de reconstrucción física de fragmentos (UNION ALL):
--       - vista_inventarios_fragmentos_union
--       - vista_pedidos_fragmentos_union
--   * 10 vistas SQL obligatorias del sistema:
--       1. vista_inventario_por_sede
--       2. vista_alertas_reabastecimiento
--       3. vista_productos_sin_inventario
--       4. vista_ventas_mensuales_por_sede
--       5. vista_pedidos_pendientes
--       6. vista_saldos_pendientes
--       7. vista_compras_pendientes
--       8. vista_transferencias_en_transito
--       9. vista_devoluciones_por_producto
--      10. vista_reporte_corporativo
-- ============================================================================

-- Reconstrucción explícita de los 5 fragmentos horizontales de inventarios
CREATE OR REPLACE VIEW reportes.vista_inventarios_fragmentos_union AS
SELECT 'inventarios_sede_1'::text AS fragmento_origen, * FROM inventarios_transferencias.inventarios_sede_1
UNION ALL
SELECT 'inventarios_sede_2'::text AS fragmento_origen, * FROM inventarios_transferencias.inventarios_sede_2
UNION ALL
SELECT 'inventarios_sede_3'::text AS fragmento_origen, * FROM inventarios_transferencias.inventarios_sede_3
UNION ALL
SELECT 'inventarios_sede_4'::text AS fragmento_origen, * FROM inventarios_transferencias.inventarios_sede_4
UNION ALL
SELECT 'inventarios_sede_5'::text AS fragmento_origen, * FROM inventarios_transferencias.inventarios_sede_5;

-- Reconstrucción explícita de los 5 fragmentos horizontales de pedidos_venta
CREATE OR REPLACE VIEW reportes.vista_pedidos_fragmentos_union AS
SELECT 'pedidos_venta_sede_1'::text AS fragmento_origen, * FROM ventas_pagos.pedidos_venta_sede_1
UNION ALL
SELECT 'pedidos_venta_sede_2'::text AS fragmento_origen, * FROM ventas_pagos.pedidos_venta_sede_2
UNION ALL
SELECT 'pedidos_venta_sede_3'::text AS fragmento_origen, * FROM ventas_pagos.pedidos_venta_sede_3
UNION ALL
SELECT 'pedidos_venta_sede_4'::text AS fragmento_origen, * FROM ventas_pagos.pedidos_venta_sede_4
UNION ALL
SELECT 'pedidos_venta_sede_5'::text AS fragmento_origen, * FROM ventas_pagos.pedidos_venta_sede_5;

-- 1. vista_inventario_por_sede
-- Procedencia: inventarios_transferencias (5 fragmentos) + catalogo_terceros
CREATE OR REPLACE VIEW reportes.vista_inventario_por_sede AS
SELECT
    inv.fragmento_origen,
    inv.id_sede,
    s.nombre_sede,
    inv.id_almacen,
    a.nombre_almacen,
    inv.id_producto,
    p.sku,
    p.nombre AS nombre_producto,
    c.nombre_categoria,
    inv.existencia_actual,
    inv.stock_minimo,
    p.precio_lista,
    ROUND((inv.existencia_actual * p.precio_lista)::numeric, 2) AS valorizacion_estimada,
    CASE
        WHEN inv.existencia_actual = 0 THEN 'Agotado'
        WHEN inv.existencia_actual < inv.stock_minimo THEN 'Bajo mínimo'
        ELSE 'Normal'
    END AS estado_stock,
    inv.fecha_actualizacion
FROM reportes.vista_inventarios_fragmentos_union inv
JOIN catalogo_terceros.sedes s       ON s.id_sede = inv.id_sede
JOIN catalogo_terceros.almacenes a   ON a.id_almacen = inv.id_almacen
JOIN catalogo_terceros.productos p   ON p.id_producto = inv.id_producto
JOIN catalogo_terceros.categorias c  ON c.id_categoria = p.id_categoria;

-- 2. vista_alertas_reabastecimiento
-- Procedencia: inventarios_transferencias (fragmentos) + catalogo_terceros
CREATE OR REPLACE VIEW reportes.vista_alertas_reabastecimiento AS
SELECT
    inv.fragmento_origen,
    inv.id_sede,
    s.nombre_sede,
    inv.id_almacen,
    a.nombre_almacen,
    inv.id_producto,
    p.sku,
    p.nombre AS nombre_producto,
    c.nombre_categoria,
    inv.existencia_actual,
    inv.stock_minimo,
    GREATEST(inv.stock_minimo - inv.existencia_actual, 0) AS faltante,
    CASE
        WHEN inv.existencia_actual = 0 THEN 'Crítica (Agotado)'
        ELSE 'Alerta (Bajo mínimo)'
    END AS nivel_alerta,
    inv.fecha_actualizacion
FROM reportes.vista_inventarios_fragmentos_union inv
JOIN catalogo_terceros.sedes s      ON s.id_sede = inv.id_sede
JOIN catalogo_terceros.almacenes a  ON a.id_almacen = inv.id_almacen
JOIN catalogo_terceros.productos p  ON p.id_producto = inv.id_producto
JOIN catalogo_terceros.categorias c ON c.id_categoria = p.id_categoria
WHERE inv.existencia_actual = 0
   OR inv.existencia_actual < inv.stock_minimo
ORDER BY faltante DESC, inv.existencia_actual ASC, inv.id_sede, inv.id_producto;

-- 3. vista_productos_sin_inventario (combinaciones producto-sede sin inventario)
-- Procedencia: catalogo_terceros + inventarios_transferencias
CREATE OR REPLACE VIEW reportes.vista_productos_sin_inventario AS
SELECT
    s.id_sede,
    s.nombre_sede,
    s.estado AS estado_sede,
    p.id_producto,
    p.sku,
    p.nombre AS nombre_producto,
    c.nombre_categoria,
    p.precio_lista
FROM catalogo_terceros.sedes s
CROSS JOIN catalogo_terceros.productos p
JOIN catalogo_terceros.categorias c ON c.id_categoria = p.id_categoria
WHERE p.estado = 'Activo'
  AND NOT EXISTS (
      SELECT 1
      FROM inventarios_transferencias.inventarios inv
      WHERE inv.id_sede = s.id_sede
        AND inv.id_producto = p.id_producto
  )
ORDER BY s.id_sede, p.id_producto;

-- 4. vista_ventas_mensuales_por_sede
-- Procedencia: ventas_pagos (5 fragmentos UNION ALL) + catalogo_terceros
CREATE OR REPLACE VIEW reportes.vista_ventas_mensuales_por_sede AS
WITH ventas_mes AS (
    SELECT
        pv.id_sede,
        DATE_TRUNC('month', pv.fecha_pedido)::date AS mes_inicio,
        TO_CHAR(pv.fecha_pedido, 'YYYY-MM') AS periodo,
        COUNT(*) AS pedidos_completados,
        COALESCE(SUM(pv.total_registrado), 0) AS total_vendido,
        ROUND(AVG(pv.total_registrado)::numeric, 2) AS ticket_promedio
    FROM reportes.vista_pedidos_fragmentos_union pv
    WHERE pv.estado = 'Completado'
    GROUP BY pv.id_sede, DATE_TRUNC('month', pv.fecha_pedido)::date, TO_CHAR(pv.fecha_pedido, 'YYYY-MM')
)
SELECT
    vm.id_sede,
    s.nombre_sede,
    vm.periodo,
    vm.pedidos_completados,
    vm.total_vendido,
    vm.ticket_promedio,
    LAG(vm.total_vendido) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes_inicio) AS venta_mes_anterior,
    vm.total_vendido - COALESCE(
        LAG(vm.total_vendido) OVER (PARTITION BY vm.id_sede ORDER BY vm.mes_inicio),
        vm.total_vendido
    ) AS variacion_absoluta
FROM ventas_mes vm
JOIN catalogo_terceros.sedes s ON s.id_sede = vm.id_sede
ORDER BY vm.id_sede, vm.mes_inicio;

-- 5. vista_pedidos_pendientes (fecha de corte cuatrimestral: 2026-11-30)
-- Procedencia: ventas_pagos + catalogo_terceros + identidad_accesos
CREATE OR REPLACE VIEW reportes.vista_pedidos_pendientes AS
SELECT
    pv.fragmento_origen,
    pv.id_pedido,
    pv.id_sede,
    s.nombre_sede,
    pv.id_almacen,
    a.nombre_almacen,
    pv.id_cliente,
    c.nombre_completo_cliente AS cliente,
    pv.id_empleado,
    e.nombre_completo AS vendedor,
    pv.fecha_pedido,
    (DATE '2026-11-30' - pv.fecha_pedido) AS dias_antiguedad,
    pv.total_registrado
FROM reportes.vista_pedidos_fragmentos_union pv
JOIN catalogo_terceros.sedes s       ON s.id_sede = pv.id_sede
JOIN catalogo_terceros.almacenes a   ON a.id_almacen = pv.id_almacen
JOIN catalogo_terceros.clientes c    ON c.id_cliente = pv.id_cliente
JOIN identidad_accesos.empleados e   ON e.id_empleado = pv.id_empleado
WHERE pv.estado = 'Pendiente'
ORDER BY pv.fecha_pedido ASC, pv.id_pedido ASC;

-- 6. vista_saldos_pendientes
-- Procedencia: ventas_pagos + catalogo_terceros
CREATE OR REPLACE VIEW reportes.vista_saldos_pendientes AS
WITH pagos_confirmados AS (
    SELECT
        pg.id_sede,
        pg.id_pedido,
        COALESCE(SUM(pg.valor), 0) AS total_pagado_confirmado,
        COUNT(*) AS cantidad_pagos_confirmados
    FROM ventas_pagos.pagos pg
    WHERE pg.estado = 'Confirmado'
    GROUP BY pg.id_sede, pg.id_pedido
)
SELECT
    pv.id_pedido,
    pv.id_sede,
    s.nombre_sede,
    pv.id_cliente,
    c.nombre_completo_cliente AS cliente,
    pv.fecha_pedido,
    pv.estado AS estado_pedido,
    pv.total_registrado,
    COALESCE(pc.total_pagado_confirmado, 0) AS pagos_confirmados,
    COALESCE(pc.cantidad_pagos_confirmados, 0) AS num_pagos_confirmados,
    (pv.total_registrado - COALESCE(pc.total_pagado_confirmado, 0)) AS saldo_pendiente
FROM ventas_pagos.pedidos_venta pv
JOIN catalogo_terceros.sedes s    ON s.id_sede = pv.id_sede
JOIN catalogo_terceros.clientes c ON c.id_cliente = pv.id_cliente
LEFT JOIN pagos_confirmados pc    ON pc.id_sede = pv.id_sede AND pc.id_pedido = pv.id_pedido
WHERE pv.estado <> 'Cancelado'
  AND (pv.total_registrado - COALESCE(pc.total_pagado_confirmado, 0)) > 0
ORDER BY saldo_pendiente DESC, pv.fecha_pedido ASC;

-- 7. vista_compras_pendientes
-- Procedencia: compras_abastecimiento + catalogo_terceros
CREATE OR REPLACE VIEW reportes.vista_compras_pendientes AS
WITH recibido_por_orden AS (
    SELECT
        rc.id_orden_compra,
        dr.id_producto,
        SUM(dr.cantidad_recibida) AS cantidad_recibida
    FROM compras_abastecimiento.recepciones_compra rc
    JOIN compras_abastecimiento.detalle_recepcion dr ON dr.id_recepcion = rc.id_recepcion
    WHERE rc.estado <> 'Anulado'
    GROUP BY rc.id_orden_compra, dr.id_producto
)
SELECT
    oc.id_orden_compra,
    oc.estado AS estado_orden,
    oc.fecha_orden,
    oc.fecha_estimada,
    pr.id_proveedor,
    pr.razon_social AS proveedor,
    a.id_almacen AS id_almacen_destino,
    a.nombre_almacen AS almacen_destino,
    p.id_producto,
    p.sku,
    p.nombre AS nombre_producto,
    doc.cantidad_solicitada,
    COALESCE(rpo.cantidad_recibida, 0) AS cantidad_recibida,
    GREATEST(doc.cantidad_solicitada - COALESCE(rpo.cantidad_recibida, 0), 0) AS cantidad_pendiente
FROM compras_abastecimiento.ordenes_compra oc
JOIN compras_abastecimiento.detalle_orden_compra doc ON doc.id_orden_compra = oc.id_orden_compra
JOIN catalogo_terceros.proveedores pr                ON pr.id_proveedor = oc.id_proveedor
JOIN catalogo_terceros.almacenes a                   ON a.id_almacen = oc.id_almacen_destino
JOIN catalogo_terceros.productos p                   ON p.id_producto = doc.id_producto
LEFT JOIN recibido_por_orden rpo
       ON rpo.id_orden_compra = doc.id_orden_compra
      AND rpo.id_producto = doc.id_producto
WHERE oc.estado IN ('Pendiente', 'Recibida Parcial')
  AND (doc.cantidad_solicitada - COALESCE(rpo.cantidad_recibida, 0)) > 0
ORDER BY oc.fecha_estimada ASC, oc.id_orden_compra, p.id_producto;

-- 8. vista_transferencias_en_transito (fecha de corte cuatrimestral: 2026-11-30)
-- Procedencia: inventarios_transferencias + catalogo_terceros
CREATE OR REPLACE VIEW reportes.vista_transferencias_en_transito AS
SELECT
    t.id_transferencia,
    t.id_almacen_origen,
    ao.nombre_almacen AS almacen_origen,
    so.nombre_sede AS sede_origen,
    t.id_almacen_destino,
    ad.nombre_almacen AS almacen_destino,
    sd.nombre_sede AS sede_destino,
    t.fecha_solicitud,
    t.fecha_despacho,
    (DATE '2026-11-30' - t.fecha_despacho) AS dias_en_transito,
    COUNT(dt.id_producto) AS productos_distintos,
    COALESCE(SUM(dt.cantidad_enviada), 0) AS total_unidades_enviadas
FROM inventarios_transferencias.transferencias t
JOIN inventarios_transferencias.detalle_transferencia dt ON dt.id_transferencia = t.id_transferencia
JOIN catalogo_terceros.almacenes ao ON ao.id_almacen = t.id_almacen_origen
JOIN catalogo_terceros.sedes so     ON so.id_sede = ao.id_sede
JOIN catalogo_terceros.almacenes ad ON ad.id_almacen = t.id_almacen_destino
JOIN catalogo_terceros.sedes sd     ON sd.id_sede = ad.id_sede
WHERE t.estado = 'Despachada'
  AND t.fecha_despacho IS NOT NULL
  AND t.fecha_recepcion IS NULL
GROUP BY
    t.id_transferencia, t.id_almacen_origen, ao.nombre_almacen, so.nombre_sede,
    t.id_almacen_destino, ad.nombre_almacen, sd.nombre_sede,
    t.fecha_solicitud, t.fecha_despacho
ORDER BY dias_en_transito DESC, t.id_transferencia;

-- 9. vista_devoluciones_por_producto
-- Procedencia: ventas_pagos + catalogo_terceros (CTEs separadas evitan duplicación 1:N)
CREATE OR REPLACE VIEW reportes.vista_devoluciones_por_producto AS
WITH vendido AS (
    SELECT
        dp.id_producto,
        SUM(dp.cantidad) AS unidades_vendidas
    FROM ventas_pagos.detalle_pedido dp
    JOIN ventas_pagos.pedidos_venta pv
      ON pv.id_sede = dp.id_sede AND pv.id_pedido = dp.id_pedido
    WHERE pv.estado = 'Completado'
    GROUP BY dp.id_producto
),
devuelto AS (
    SELECT
        dd.id_producto,
        COUNT(DISTINCT d.id_devolucion) AS num_devoluciones,
        SUM(dd.cantidad) AS unidades_devueltas,
        SUM(CASE WHEN d.estado = 'Aprobada' THEN dd.cantidad ELSE 0 END) AS unidades_aprobadas
    FROM ventas_pagos.detalle_devolucion dd
    JOIN ventas_pagos.devoluciones d ON d.id_devolucion = dd.id_devolucion
    GROUP BY dd.id_producto
)
SELECT
    p.id_producto,
    p.sku,
    p.nombre AS nombre_producto,
    c.nombre_categoria,
    COALESCE(v.unidades_vendidas, 0) AS unidades_vendidas,
    dev.num_devoluciones,
    dev.unidades_devueltas,
    dev.unidades_aprobadas,
    ROUND(
        (dev.unidades_devueltas::numeric / NULLIF(v.unidades_vendidas, 0)) * 100,
        2
    ) AS porcentaje_devolucion
FROM devuelto dev
JOIN catalogo_terceros.productos p  ON p.id_producto = dev.id_producto
JOIN catalogo_terceros.categorias c ON c.id_categoria = p.id_categoria
LEFT JOIN vendido v                 ON v.id_producto = dev.id_producto
ORDER BY porcentaje_devolucion DESC NULLS LAST, dev.unidades_devueltas DESC;

-- 10. vista_reporte_corporativo
-- Procedencia: 5 microservicios operacionales agregados por sede en CTEs independientes
CREATE OR REPLACE VIEW reportes.vista_reporte_corporativo AS
WITH inv_sede AS (
    SELECT
        inv.id_sede,
        COUNT(DISTINCT inv.id_producto) AS productos_en_inventario,
        COALESCE(SUM(inv.existencia_actual), 0) AS unidades_inventario,
        COALESCE(SUM(inv.existencia_actual * p.precio_lista), 0) AS valor_inventario,
        COUNT(*) FILTER (WHERE inv.existencia_actual = 0 OR inv.existencia_actual < inv.stock_minimo) AS alertas_stock
    FROM inventarios_transferencias.inventarios inv
    JOIN catalogo_terceros.productos p ON p.id_producto = inv.id_producto
    GROUP BY inv.id_sede
),
ventas_sede AS (
    SELECT
        pv.id_sede,
        COUNT(*) FILTER (WHERE pv.estado = 'Completado') AS pedidos_completados,
        COUNT(*) FILTER (WHERE pv.estado = 'Pendiente')  AS pedidos_pendientes,
        COALESCE(SUM(pv.total_registrado) FILTER (WHERE pv.estado = 'Completado'), 0) AS monto_ventas_completadas
    FROM ventas_pagos.pedidos_venta pv
    GROUP BY pv.id_sede
),
compras_sede AS (
    SELECT
        a.id_sede,
        COUNT(DISTINCT oc.id_orden_compra) AS total_ordenes_compra,
        COUNT(DISTINCT oc.id_orden_compra) FILTER (WHERE oc.estado IN ('Pendiente', 'Recibida Parcial')) AS ordenes_pendientes
    FROM compras_abastecimiento.ordenes_compra oc
    JOIN catalogo_terceros.almacenes a ON a.id_almacen = oc.id_almacen_destino
    GROUP BY a.id_sede
),
transf_sede AS (
    SELECT
        a.id_sede,
        COUNT(DISTINCT t.id_transferencia) AS transferencias_emitidas,
        COUNT(DISTINCT t.id_transferencia) FILTER (WHERE t.estado = 'Despachada') AS transferencias_en_transito
    FROM inventarios_transferencias.transferencias t
    JOIN catalogo_terceros.almacenes a ON a.id_almacen = t.id_almacen_origen
    GROUP BY a.id_sede
),
prod_activos AS (
    SELECT COUNT(*) AS total_productos_activos
    FROM catalogo_terceros.productos
    WHERE estado = 'Activo'
)
SELECT
    s.id_sede,
    s.nombre_sede,
    s.tipo_sede,
    s.estado AS estado_sede,
    pa.total_productos_activos,
    COALESCE(i.productos_en_inventario, 0) AS productos_en_inventario,
    COALESCE(i.unidades_inventario, 0)     AS unidades_inventario,
    ROUND(COALESCE(i.valor_inventario, 0)::numeric, 2) AS valor_inventario,
    COALESCE(i.alertas_stock, 0)           AS alertas_stock,
    COALESCE(v.pedidos_completados, 0)     AS pedidos_completados,
    COALESCE(v.pedidos_pendientes, 0)      AS pedidos_pendientes,
    ROUND(COALESCE(v.monto_ventas_completadas, 0)::numeric, 2) AS monto_ventas_completadas,
    COALESCE(c.total_ordenes_compra, 0)    AS total_ordenes_compra,
    COALESCE(c.ordenes_pendientes, 0)      AS ordenes_compra_pendientes,
    COALESCE(tr.transferencias_emitidas, 0)    AS transferencias_emitidas,
    COALESCE(tr.transferencias_en_transito, 0) AS transferencias_en_transito
FROM catalogo_terceros.sedes s
CROSS JOIN prod_activos pa
LEFT JOIN inv_sede i     ON i.id_sede = s.id_sede
LEFT JOIN ventas_sede v  ON v.id_sede = s.id_sede
LEFT JOIN compras_sede c ON c.id_sede = s.id_sede
LEFT JOIN transf_sede tr ON tr.id_sede = s.id_sede
ORDER BY s.id_sede;
