-- ============================================================================
-- MICROSERVICIO: inventarios_transferencias
-- 03. Datos de prueba reproducibles (rango de 4 meses: ago–nov 2026)
-- Motor: PostgreSQL 18 / Neon
-- ----------------------------------------------------------------------------
-- Volúmenes: Inventarios 144 (18 prod x 8 almacenes) | Transferencias 30 | Detalle 60
-- Incluye casos de:
--   * Existencia en cero y bajo stock_minimo (alertas de reabastecimiento)
--   * Excedente en unas sedes y faltante del mismo producto en otras (redistribución)
--   * Productos con surtido distinto entre sedes (para EXCEPT / INTERSECT)
--   * Productos 85..95 con existencia positiva sin ventas recientes (baja rotación)
--   * Transferencias en tránsito ('Despachada') y diferencias enviado vs recibido
-- ============================================================================

TRUNCATE TABLE detalle_transferencia, transferencias, inventarios
    RESTART IDENTITY CASCADE;

-- ---------------------- Inventarios: 144 (18 productos x 8 almacenes) ------
-- Cada almacén almacena 18 productos (algunos compartidos entre sedes y otros propios),
-- generando alertas reales (existencia = 0 o < stock_minimo) y excedentes en otra sede.
INSERT INTO inventarios (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT
    alm.id_sede,
    alm.id_almacen,
    prod.id_producto,
    CASE
        -- Productos con quiebre total (existencia = 0) en algunas bodegas
        WHEN prod.slot IN (0, 1) AND alm.id_almacen IN (1, 5, 7) THEN 0
        -- Productos bajo stock mínimo (existencia > 0 pero < stock_minimo)
        WHEN prod.slot IN (2, 3, 4) AND alm.id_almacen IN (1, 2, 5, 6, 7) THEN 4 + ((alm.id_almacen + prod.id_producto) % 8)
        -- Centro de distribución (sede 2, almacenes 3 y 4) y bodegas alternativas con excedente alto
        WHEN alm.id_sede = 2 THEN 120 + ((alm.id_almacen * 17 + prod.id_producto * 3) % 260)
        ELSE 35 + ((alm.id_almacen * 13 + prod.id_producto * 7) % 180)
    END AS existencia_actual,
    18 + (prod.id_producto % 22) AS stock_minimo,
    DATE '2026-08-01' + ((alm.id_almacen * 11 + prod.id_producto) % 116)
FROM (
    SELECT * FROM (VALUES
        (1,1),(2,1),(3,2),(4,2),(5,3),(6,3),(7,4),(8,5)
    ) AS a(id_almacen, id_sede)
) alm
CROSS JOIN LATERAL (
    SELECT
        s AS slot,
        CASE
            -- Slots 0..14: cobertura rotada en 1..100 con traslapes entre sedes
            WHEN s < 15 THEN (((alm.id_almacen - 1) * 11 + s) % 84) + 1
            -- Slots 15..16: productos compartidos entre varias sedes (para redistribución y demanda)
            WHEN s = 15 THEN 1 + (alm.id_almacen % 5)
            WHEN s = 16 THEN 10 + (alm.id_almacen % 4)
            -- Slot 17: productos de baja rotación (85..95) con existencia positiva
            ELSE 85 + (alm.id_almacen % 11)
        END AS id_producto
    FROM generate_series(0, 17) AS s
) AS prod
ON CONFLICT (id_sede, id_almacen, id_producto) DO NOTHING;

-- ---------------------- Transferencias: 30 (ago–nov 2026) ------------------
INSERT INTO transferencias (id_transferencia, id_almacen_origen, id_almacen_destino, fecha_solicitud, fecha_despacho, fecha_recepcion, estado)
SELECT
    g,
    ((g - 1) % 8) + 1,
    (((g - 1) % 8 + 1 + (g % 7)) % 8) + 1,
    DATE '2026-08-05' + (g * 3 % 105),
    CASE WHEN st IN ('Despachada','Recibida') THEN DATE '2026-08-05' + (g * 3 % 105) + (1 + g % 3) END,
    CASE WHEN st = 'Recibida' THEN DATE '2026-08-05' + (g * 3 % 105) + (1 + g % 3) + (2 + g % 4) END,
    st
FROM (
    SELECT g, (ARRAY['Solicitada','Despachada','Recibida','Cancelada'])[((g - 1 + ((g - 1) / 8)) % 4) + 1] AS st
    FROM generate_series(1, 30) AS g
) s;

-- Garantiza origen <> destino
UPDATE transferencias SET id_almacen_destino = (id_almacen_destino % 8) + 1
WHERE id_almacen_origen = id_almacen_destino;
UPDATE transferencias SET id_almacen_destino = (id_almacen_destino % 8) + 1
WHERE id_almacen_origen = id_almacen_destino;

-- ---------------------- Detalle transferencia: 60 --------------------------
-- Incluye diferencias entre cantidad_enviada y cantidad_recibida en ~40% de las recibidas
INSERT INTO detalle_transferencia (id_transferencia, id_producto, cantidad_enviada, cantidad_recibida)
SELECT DISTINCT ON (cand.id_transferencia, cand.id_producto)
    cand.id_transferencia,
    cand.id_producto,
    cand.cant,
    CASE
        WHEN cand.estado = 'Recibida' AND (cand.id_transferencia + cand.id_producto) % 3 = 0
            THEN GREATEST(cand.cant - (1 + (cand.id_transferencia % 5)), 1)
        WHEN cand.estado = 'Recibida'
            THEN cand.cant
        ELSE NULL
    END
FROM (
    SELECT
        t.id_transferencia,
        prod.id_producto,
        t.estado,
        8 + ((t.id_transferencia * 3 + prod.id_producto) % 90) AS cant
    FROM transferencias t
    CROSS JOIN LATERAL (
        VALUES
            (((t.id_transferencia - 1) % 100) + 1),
            (((t.id_transferencia + 49) % 100) + 1)
    ) AS prod(id_producto)
) cand
ORDER BY cand.id_transferencia, cand.id_producto;
