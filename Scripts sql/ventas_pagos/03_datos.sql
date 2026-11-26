-- ============================================================================
-- MICROSERVICIO: ventas_pagos
-- 03. Datos de prueba reproducibles
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Volúmenes: Pedidos 350 | Detalle pedido ~875 | Pagos ~117 | Devoluciones 25
-- Referencias lógicas: id_sede 1..5 ; id_almacen 1..8 ; id_cliente 1..120 ;
--   id_empleado 1..25 ; id_producto 1..100
--
-- IMPORTANTE: precio_unitario NO se puede leer de catalogo_terceros.productos
-- (vive en otra base). Se reproduce con la MISMA fórmula determinística que usa
-- el servicio de catálogo para precio_lista:
--     precio_lista(g) = 1000 + (g * 487) % 49000
-- Así los precios quedan coherentes entre ambos servicios.
--
-- total_registrado se calcula por UPDATE a partir del detalle real.
-- ============================================================================

TRUNCATE TABLE detalle_devolucion, devoluciones, pagos, detalle_pedido, pedidos_venta
    RESTART IDENTITY CASCADE;

-- ---------------------- Pedidos de venta: 350 ------------------------------
INSERT INTO pedidos_venta (id_pedido, id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado)
SELECT
    g,
    ((g - 1) % 5) + 1,
    ((g * 2 - 1) % 8) + 1,
    ((g - 1) % 120) + 1,
    ((g - 1) % 25) + 1,
    DATE '2026-02-01' + (g % 60),
    (ARRAY['Pendiente','Completado','Cancelado'])[((g - 1) % 3) + 1],
    0
FROM generate_series(1, 350) AS g;

-- ---------------------- Detalle pedido -------------------------------------
-- precio_unitario = fórmula de precio_lista del producto referenciado.
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT DISTINCT ON (cand.id_pedido, cand.id_producto)
    cand.id_pedido,
    cand.id_producto,
    1 + ((cand.id_pedido + cand.linea) % 9),
    (1000 + (cand.id_producto * 487) % 49000)::numeric(12,2)
FROM (
    SELECT
        pv.id_pedido,
        linea,
        (((pv.id_pedido * 3 + linea * 31) % 100) + 1) AS id_producto
    FROM pedidos_venta pv
    CROSS JOIN LATERAL generate_series(0, (pv.id_pedido % 4)) AS linea
) cand
ORDER BY cand.id_pedido, cand.id_producto, cand.linea;

-- ---------------------- total_registrado (UPDATE) --------------------------
UPDATE pedidos_venta pv
SET total_registrado = COALESCE(d.total, 0)
FROM (
    SELECT id_pedido, SUM(cantidad * precio_unitario) AS total
    FROM detalle_pedido
    GROUP BY id_pedido
) d
WHERE d.id_pedido = pv.id_pedido
  AND pv.estado <> 'Cancelado';

-- ---------------------- Pagos (1 por pedido Completado) --------------------
INSERT INTO pagos (id_pago, id_pedido, fecha_pago, valor, medio_pago, estado)
SELECT
    row_number() OVER (ORDER BY pv.id_pedido),
    pv.id_pedido,
    pv.fecha_pedido + 1,
    pv.total_registrado,
    (ARRAY['Efectivo','Tarjeta Debito','Tarjeta Credito','Transferencia'])[((pv.id_pedido - 1) % 4) + 1],
    'Confirmado'
FROM pedidos_venta pv
WHERE pv.estado = 'Completado'
  AND pv.total_registrado > 0;

-- ---------------------- Devoluciones: 25 -----------------------------------
-- Estado/motivo derivados de rn (correlativo 1..25) para variar los 3 estados.
INSERT INTO devoluciones (id_devolucion, id_pedido, fecha_solicitud, motivo, estado)
SELECT
    c.rn,
    c.id_pedido,
    c.fecha_pedido + 5,
    (ARRAY['Producto defectuoso','Cliente insatisfecho','Error en el pedido','Producto dañado en transporte'])[((c.rn - 1) % 4) + 1],
    (ARRAY['Solicitada','Aprobada','Rechazada'])[((c.rn - 1) % 3) + 1]
FROM (
    SELECT row_number() OVER (ORDER BY pv.id_pedido) AS rn, pv.id_pedido, pv.fecha_pedido
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
    WHERE dp2.id_pedido = dev.id_pedido
    ORDER BY dp2.id_producto
    LIMIT 1
) dp;
