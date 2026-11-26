-- ============================================================================
-- MICROSERVICIO: inventarios_transferencias
-- 03. Datos de prueba reproducibles
-- Motor: PostgreSQL (Neon)
-- ----------------------------------------------------------------------------
-- Volúmenes: Inventarios 120 | Transferencias 30 | Detalle transf. 60
-- Referencias lógicas: id_sede 1..5 ; id_almacen 1..8 ; id_producto 1..100
-- ============================================================================

TRUNCATE TABLE detalle_transferencia, transferencias, inventarios
    RESTART IDENTITY CASCADE;

-- ---------------------- Inventarios: 120 (15 productos x 8 almacenes) ------
INSERT INTO inventarios (id_sede, id_almacen, id_producto, existencia_actual, stock_minimo, fecha_actualizacion)
SELECT
    alm.id_sede,
    alm.id_almacen,
    prod.id_producto,
    50 + ((alm.id_almacen * 13 + prod.id_producto) % 450),
    10 + (prod.id_producto % 30),
    DATE '2026-03-01' + (prod.id_producto % 20)
FROM (
    -- mapa almacen -> sede (igual que en catalogo_terceros)
    SELECT * FROM (VALUES
        (1,1),(2,1),(3,2),(4,2),(5,3),(6,3),(7,4),(8,5)
    ) AS a(id_almacen, id_sede)
) alm
CROSS JOIN LATERAL (
    SELECT (((alm.id_almacen - 1) * 15 + s) % 100) + 1 AS id_producto
    FROM generate_series(0, 14) AS s
) AS prod;

-- ---------------------- Transferencias: 30 ---------------------------------
INSERT INTO transferencias (id_transferencia, id_almacen_origen, id_almacen_destino, fecha_solicitud, fecha_despacho, fecha_recepcion, estado)
SELECT
    g,
    ((g - 1) % 8) + 1,
    (((g - 1) % 8 + 1 + (g % 7)) % 8) + 1,
    DATE '2026-03-01' + (g % 25),
    CASE WHEN st IN ('Despachada','Recibida') THEN DATE '2026-03-01' + (g % 25) + (1 + g % 3) END,
    CASE WHEN st = 'Recibida' THEN DATE '2026-03-01' + (g % 25) + (1 + g % 3) + (1 + g % 3) END,
    st
FROM (
    SELECT g, (ARRAY['Solicitada','Despachada','Recibida','Cancelada'])[((g - 1) % 4) + 1] AS st
    FROM generate_series(1, 30) AS g
) s;

-- Garantiza origen <> destino (dos pasadas por si el +1 vuelve a coincidir).
UPDATE transferencias SET id_almacen_destino = (id_almacen_destino % 8) + 1
WHERE id_almacen_origen = id_almacen_destino;
UPDATE transferencias SET id_almacen_destino = (id_almacen_destino % 8) + 1
WHERE id_almacen_origen = id_almacen_destino;

-- ---------------------- Detalle transferencia: 60 -------------------------
INSERT INTO detalle_transferencia (id_transferencia, id_producto, cantidad_enviada, cantidad_recibida)
SELECT DISTINCT ON (cand.id_transferencia, cand.id_producto)
    cand.id_transferencia,
    cand.id_producto,
    cand.cant,
    CASE WHEN cand.estado = 'Recibida' THEN cand.cant ELSE NULL END
FROM (
    SELECT
        t.id_transferencia,
        prod.id_producto,
        t.estado,
        5 + ((t.id_transferencia * 3 + prod.id_producto) % 95) AS cant
    FROM transferencias t
    CROSS JOIN LATERAL (
        VALUES
            (((t.id_transferencia - 1) % 100) + 1),
            (((t.id_transferencia + 49) % 100) + 1)
    ) AS prod(id_producto)
) cand
ORDER BY cand.id_transferencia, cand.id_producto;
