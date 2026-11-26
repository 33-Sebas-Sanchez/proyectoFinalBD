-- ============================================================================
-- MICROSERVICIO: compras_abastecimiento
-- 03. Datos de prueba reproducibles
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Volúmenes: Órdenes 75 | Detalle OC 150 | Recepciones ~38 | Detalle recep ~76
-- Referencias lógicas (deben existir en sus servicios):
--   id_proveedor 1..12 ; id_almacen_destino 1..8 ; id_empleado 1..25 ;
--   id_producto 1..100
-- ============================================================================

TRUNCATE TABLE detalle_recepcion, recepciones_compra,
               detalle_orden_compra, ordenes_compra
    RESTART IDENTITY CASCADE;

-- ---------------------- Órdenes de compra: 75 ------------------------------
INSERT INTO ordenes_compra (id_orden_compra, id_proveedor, id_almacen_destino, id_empleado, fecha_orden, fecha_estimada, estado)
SELECT
    g,
    ((g - 1) % 12) + 1,
    ((g - 1) % 8) + 1,
    ((g - 1) % 25) + 1,
    DATE '2026-01-05' + (g % 40),
    DATE '2026-01-05' + (g % 40) + (3 + (g % 10)),
    (ARRAY['Pendiente','Recibida Parcial','Recibida Total','Cancelada'])[((g - 1) % 4) + 1]
FROM generate_series(1, 75) AS g;

-- ---------------------- Detalle orden de compra: 150 -----------------------
INSERT INTO detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario)
SELECT DISTINCT ON (cand.id_orden_compra, cand.id_producto)
    cand.id_orden_compra,
    cand.id_producto,
    10 + ((cand.id_orden_compra * 7 + cand.id_producto) % 190),
    -- costo determinístico (no hay acceso a productos de otra base): base + variación
    ((700 + (cand.id_producto * 341) % 34300))::numeric(12,2)
FROM (
    SELECT oc.id_orden_compra, prod.id_producto
    FROM ordenes_compra oc
    CROSS JOIN LATERAL (
        VALUES
            (((oc.id_orden_compra - 1) % 100) + 1),
            (((oc.id_orden_compra + 36) % 100) + 1)
    ) AS prod(id_producto)
) cand
ORDER BY cand.id_orden_compra, cand.id_producto;

-- ---------------------- Recepciones de compra ------------------------------
INSERT INTO recepciones_compra (id_recepcion, id_orden_compra, fecha_recepcion, estado)
SELECT
    row_number() OVER (ORDER BY oc.id_orden_compra),
    oc.id_orden_compra,
    oc.fecha_estimada,
    CASE oc.estado
        WHEN 'Recibida Total'   THEN 'Procesado'
        WHEN 'Recibida Parcial' THEN 'Parcial'
    END
FROM ordenes_compra oc
WHERE oc.estado IN ('Recibida Total', 'Recibida Parcial');

-- ---------------------- Detalle recepción ----------------------------------
INSERT INTO detalle_recepcion (id_recepcion, id_producto, cantidad_recibida)
SELECT
    r.id_recepcion,
    d.id_producto,
    CASE r.estado
        WHEN 'Procesado' THEN d.cantidad_solicitada
        ELSE (d.cantidad_solicitada / 2)
    END
FROM recepciones_compra r
JOIN detalle_orden_compra d ON d.id_orden_compra = r.id_orden_compra;
