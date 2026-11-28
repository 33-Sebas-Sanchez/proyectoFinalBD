-- ============================================================================
-- MICROSERVICIO: ventas_pagos
-- 03. Datos de prueba reproducibles (rango de 4 meses: ago–nov 2026)
-- Motor: PostgreSQL 18 / Neon
-- ----------------------------------------------------------------------------
-- Volúmenes: Pedidos 350 | Detalle pedido ~980 | Pagos ~220 | Devoluciones 25
-- Referencias lógicas:
--   almacen -> sede: (1,1),(2,1),(3,2),(4,2),(5,3),(6,3),(7,4),(8,5)
--   id_cliente 1..120 ; vendedores id_empleado 11..23 ; id_producto 1..100
--   precio_lista(p) = 1000 + (p * 487) % 49000
-- Cobertura de casos de prueba:
--   * 4 meses completos (2026-07-28 .. 2026-11-25) para series mensuales y LAG()
--   * Pedidos con pagos totales, pagos parciales (abonos), pendientes y rechazados
--   * Pedidos pendientes antiguos (>30 días) y pedidos con demanda > stock
--   * Productos 85..95 sin ventas confirmadas en los últimos 90 días
-- ============================================================================

TRUNCATE TABLE detalle_devolucion, devoluciones, pagos, detalle_pedido, pedidos_venta
    RESTART IDENTITY CASCADE;

-- ---------------------- Pedidos de venta: 350 ------------------------------
-- Almacenes 1..8 emparejados exactamente con su sede propietaria
INSERT INTO pedidos_venta (id_pedido, id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
SELECT
    g,
    alm.id_sede,
    alm.id_almacen,
    -- Factor coprimo + desplazamiento por bloque para generar compras multisede reales
    (((g - 1) * 7 + ((g - 1) / 8) * 5) % 120) + 1,
    -- Vendedores reales (11..23) distribuidos entre sedes
    11 + ((g - 1 + ((g - 1) / 8)) % 13),
    -- 120 días de histórico: jul 28 .. nov 25 de 2026 (4 meses)
    DATE '2026-07-28' + ((g * 7) % 121),
    CASE (((g - 1) * 5 + ((g - 1) / 8)) % 6)
        WHEN 0 THEN 'Cancelado'
        WHEN 3 THEN 'Pendiente'
        ELSE 'Completado'
    END,
    0
FROM generate_series(1, 350) AS g
JOIN (
    VALUES (0,1,1),(1,1,2),(2,2,3),(3,2,4),(4,3,5),(5,3,6),(6,4,7),(7,5,8)
) AS alm(idx, id_sede, id_almacen) ON alm.idx = (g - 1) % 8;

-- ---------------------- Detalle pedido -------------------------------------
-- Rango de productos 1..84 para ventas normales (dejando 85..95 sin ventas en los últimos 90 días),
-- más líneas específicas de alta cantidad en pedidos pendientes para probar demanda > inventario.
INSERT INTO detalle_pedido (id_sede, id_pedido, id_producto, cantidad, precio_unitario)
SELECT DISTINCT ON (cand.id_pedido, cand.id_producto)
    cand.id_sede,
    cand.id_pedido,
    cand.id_producto,
    cand.cantidad,
    (1000 + (cand.id_producto * 487) % 49000)::numeric(12,2)
FROM (
    SELECT
        pv.id_sede,
        pv.id_pedido,
        linea,
        CASE
            -- En algunos pedidos pendientes (linea 0), incluye productos con alerta de stock
            -- y cantidades altas (> existencia) para probar consulta de demanda vs inventario
            WHEN pv.estado = 'Pendiente' AND linea = 0 AND pv.id_pedido % 9 = 0
                THEN 1 + (pv.id_almacen % 5)
            -- Pedidos antiguos (>90 días antes del 2026-11-27) pueden incluir prod 85..95
            WHEN pv.fecha_pedido < DATE '2026-08-25' AND linea = 0 AND pv.id_pedido % 10 = 1
                THEN 85 + (pv.id_pedido % 11)
            ELSE (((pv.id_pedido * 3 + linea * 29) % 84) + 1)
        END AS id_producto,
        CASE
            WHEN pv.estado = 'Pendiente' AND linea = 0 AND pv.id_pedido % 9 = 0
                THEN 120 + (pv.id_pedido % 80)
            ELSE 1 + ((pv.id_pedido + linea) % 9)
        END AS cantidad
    FROM pedidos_venta pv
    CROSS JOIN LATERAL generate_series(0, (pv.id_pedido % 5)) AS linea
) cand
ORDER BY cand.id_pedido, cand.id_producto, cand.linea;

-- ---------------------- total_registrado (UPDATE) --------------------------
UPDATE pedidos_venta pv
SET total_registrado = COALESCE(d.total, 0)
FROM (
    SELECT id_sede, id_pedido, SUM(cantidad * precio_unitario) AS total
    FROM detalle_pedido
    GROUP BY id_sede, id_pedido
) d
WHERE d.id_sede = pv.id_sede
  AND d.id_pedido = pv.id_pedido;

-- ---------------------- Pagos: totales, parciales y múltiples --------------
-- 1) Pedidos Completados (mayoría pagados al 100%, algunos en 2 cuotas y otros con saldo pendiente)
INSERT INTO pagos (id_pago, id_sede, id_pedido, fecha_pago, valor, medio_pago, estado)
WITH base_pagos AS (
    -- Primer abono o pago total de pedidos Completados
    SELECT
        pv.id_sede,
        pv.id_pedido,
        pv.fecha_pedido + 1 AS fecha_pago,
        CASE
            WHEN pv.id_pedido % 5 = 0 THEN round(pv.total_registrado * 0.60, 2)  -- pago parcial (deja 40% pendiente)
            WHEN pv.id_pedido % 4 = 0 THEN round(pv.total_registrado * 0.50, 2)  -- primera de dos cuotas
            ELSE pv.total_registrado
        END AS valor,
        (ARRAY['Efectivo','Tarjeta Debito','Tarjeta Credito','Transferencia'])[((pv.id_pedido - 1) % 4) + 1] AS medio_pago,
        'Confirmado' AS estado
    FROM pedidos_venta pv
    WHERE pv.estado = 'Completado' AND pv.total_registrado > 0

    UNION ALL

    -- Segunda cuota confirmada (completa el 100% en múltiplos de 4 que no son múltiplos de 5)
    SELECT
        pv.id_sede,
        pv.id_pedido,
        pv.fecha_pedido + 6 AS fecha_pago,
        pv.total_registrado - round(pv.total_registrado * 0.50, 2) AS valor,
        (ARRAY['Transferencia','Tarjeta Credito','Efectivo','Tarjeta Debito'])[((pv.id_pedido) % 4) + 1] AS medio_pago,
        'Confirmado' AS estado
    FROM pedidos_venta pv
    WHERE pv.estado = 'Completado'
      AND pv.total_registrado > 0
      AND pv.id_pedido % 4 = 0
      AND pv.id_pedido % 5 <> 0

    UNION ALL

    -- Abonos parciales confirmados y pagos pendientes/rechazados sobre pedidos Pendientes
    SELECT
        pv.id_sede,
        pv.id_pedido,
        pv.fecha_pedido + 2 AS fecha_pago,
        round(pv.total_registrado * 0.35, 2) AS valor,
        (ARRAY['Transferencia','Tarjeta Debito','Efectivo','Tarjeta Credito'])[((pv.id_pedido) % 4) + 1] AS medio_pago,
        CASE
            WHEN pv.id_pedido % 2 = 0 THEN 'Confirmado'
            WHEN pv.id_pedido % 9 = 0 THEN 'Rechazado'
            ELSE 'Pendiente'
        END AS estado
    FROM pedidos_venta pv
    WHERE pv.estado = 'Pendiente' AND pv.total_registrado > 0
)
SELECT
    row_number() OVER (ORDER BY id_pedido, fecha_pago, valor),
    id_sede,
    id_pedido,
    fecha_pago,
    valor,
    medio_pago,
    estado
FROM base_pagos
WHERE valor > 0;

-- ---------------------- Devoluciones: 25 -----------------------------------
INSERT INTO devoluciones (id_devolucion, id_sede, id_pedido, fecha_solicitud, motivo, estado)
SELECT
    c.rn,
    c.id_sede,
    c.id_pedido,
    c.fecha_pedido + 4,
    (ARRAY['Producto defectuoso','Cliente insatisfecho','Error en el pedido','Producto dañado en transporte'])[((c.rn - 1) % 4) + 1],
    (ARRAY['Solicitada','Aprobada','Rechazada'])[((c.rn - 1) % 3) + 1]
FROM (
    SELECT row_number() OVER (ORDER BY pv.id_pedido) AS rn, pv.id_sede, pv.id_pedido, pv.fecha_pedido
    FROM pedidos_venta pv
    WHERE pv.estado = 'Completado'
    ORDER BY pv.id_pedido
    LIMIT 25
) c;

-- ---------------------- Detalle devolución ---------------------------------
INSERT INTO detalle_devolucion (id_devolucion, id_producto, cantidad, condicion_producto)
SELECT
    dev.id_devolucion,
    dp.id_producto,
    1,
    (ARRAY['Buen Estado','Defectuoso','Dañado'])[((dev.id_devolucion - 1) % 3) + 1]
FROM devoluciones dev
CROSS JOIN LATERAL (
    SELECT id_producto
    FROM detalle_pedido dp2
    WHERE dp2.id_sede = dev.id_sede AND dp2.id_pedido = dev.id_pedido
    ORDER BY dp2.id_producto
    LIMIT 1
) dp;
