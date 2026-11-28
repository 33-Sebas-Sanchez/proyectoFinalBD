#!/usr/bin/env bash
# ============================================================================
# Ejecuta las 10 pruebas mínimas de verificación (Sección 11 del proyecto)
# contra las 6 bases de datos PostgreSQL locales.
# ============================================================================
set -euo pipefail

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5433}"

if ! pg_isready -h "$PGHOST" -p "$PGPORT" -U postgres >/dev/null 2>&1 && pg_isready -h /tmp -p "$PGPORT" -U postgres >/dev/null 2>&1; then
    PGHOST="/tmp"
fi

run_sql() {
    local db="$1"
    local user="$2"
    local sql="$3"
    psql -h "$PGHOST" -p "$PGPORT" -U "$user" -d "$db" -v ON_ERROR_STOP=1 -P pager=off -c "$sql"
}

expect_error() {
    local db="$1"
    local user="$2"
    local sql="$3"
    local expected_pattern="$4"
    local out
    set +e
    out=$(psql -h "$PGHOST" -p "$PGPORT" -U "$user" -d "$db" -v ON_ERROR_STOP=1 -c "$sql" 2>&1)
    local rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
        echo "FALLO: se esperaba error ($expected_pattern), pero la sentencia tuvo éxito." >&2
        exit 1
    fi
    if ! echo "$out" | grep -qiE "$expected_pattern"; then
        echo "FALLO: el error obtenido no coincide con '$expected_pattern':" >&2
        echo "$out" >&2
        exit 1
    fi
    echo "OK (rechazado como se esperaba): $(echo "$out" | head -n 1)"
}

echo "=================================================================="
echo "MATRIZ DE 10 PRUEBAS DE VERIFICACIÓN — POSTGRESQL LOCAL"
echo "=================================================================="

echo ""
echo "[Prueba 1] Crear un producto válido y consultar su registro (rollback al final)"
run_sql catalogo_terceros postgres "
BEGIN;
INSERT INTO productos (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado)
VALUES (999, 'SKU-99999', 'Producto Prueba Válida', 1, 'Unidad', 12500.00, 'Activo');
SELECT id_producto, sku, nombre, precio_lista, estado FROM productos WHERE id_producto = 999;
ROLLBACK;"

echo ""
echo "[Prueba 2] Intentar duplicar un SKU y comprobar rechazo UNIQUE (uq_productos_sku)"
expect_error catalogo_terceros postgres \
    "INSERT INTO productos (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista) VALUES (998, 'SKU-00001', 'Duplicado', 1, 'Unidad', 5000);" \
    "uq_productos_sku|duplicate key|23505"

echo ""
echo "[Prueba 3] Intentar registrar cantidad negativa y comprobar rechazo CHECK (ck_detalle_pedido_cantidad)"
expect_error ventas_pagos postgres \
    "INSERT INTO detalle_pedido (id_sede, id_pedido, id_producto, cantidad, precio_unitario) VALUES (1, 1, 99, -5, 1000);" \
    "ck_detalle_pedido_cantidad|check constraint|23514"

echo ""
echo "[Prueba 4] Intentar referenciar clave inexistente en FK local (fk_detalle_oc_orden)"
expect_error compras_abastecimiento postgres \
    "INSERT INTO detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario) VALUES (99999, 1, 10, 5000);" \
    "fk_detalle_oc_orden|foreign key|23503"

echo ""
echo "[Prueba 5] Consultar fragmentos de dos sedes por separado y comprobar disyunción"
run_sql inventarios_transferencias postgres "
SELECT 'inventarios_sede_1' AS fragmento, COUNT(*) AS filas, MIN(id_sede) AS min_sede, MAX(id_sede) AS max_sede FROM inventarios_sede_1
UNION ALL
SELECT 'inventarios_sede_3' AS fragmento, COUNT(*) AS filas, MIN(id_sede) AS min_sede, MAX(id_sede) AS max_sede FROM inventarios_sede_3;

SELECT 'interseccion_filas_entre_sede_1_y_sede_3' AS verificacion,
       COUNT(*) AS filas_comunes
FROM (
    SELECT id_sede, id_almacen, id_producto FROM inventarios_sede_1
    INTERSECT
    SELECT id_sede, id_almacen, id_producto FROM inventarios_sede_3
) x;"

echo ""
echo "[Prueba 6] Vista consolidada de inventarios reúne los 5 fragmentos (UNION ALL)"
run_sql reportes postgres "
SELECT
    (SELECT COUNT(*) FROM reportes.vista_inventarios_fragmentos_union) AS total_vista_union,
    (SELECT COUNT(*) FROM inventarios_transferencias.inventarios)     AS total_tabla_particionada,
    (SELECT COUNT(DISTINCT id_sede) FROM reportes.vista_inventarios_fragmentos_union) AS sedes_cubiertas;"

echo ""
echo "[Prueba 7] Consulta avanzada con CTE y función de ventana (LAG + DENSE_RANK)"
run_sql reportes postgres "
WITH resumen AS (
    SELECT id_sede, TO_CHAR(fecha_pedido, 'YYYY-MM') AS mes, SUM(total_registrado) AS total
    FROM ventas_pagos.pedidos_venta
    WHERE estado = 'Completado'
    GROUP BY id_sede, TO_CHAR(fecha_pedido, 'YYYY-MM')
)
SELECT id_sede, mes, ROUND(total::numeric, 2) AS total,
       ROUND(LAG(total) OVER (PARTITION BY id_sede ORDER BY mes)::numeric, 2) AS mes_anterior,
       DENSE_RANK() OVER (PARTITION BY mes ORDER BY total DESC) AS rank_sede_mes
FROM resumen
ORDER BY mes, rank_sede_mes
LIMIT 12;"

echo ""
echo "[Prueba 8] Comparar dos sedes mediante EXCEPT e INTERSECT"
run_sql reportes postgres "
SELECT 'solo_sede_1' AS tipo, COUNT(*) AS cantidad FROM (
    SELECT id_producto FROM inventarios_transferencias.inventarios_sede_1
    EXCEPT
    SELECT id_producto FROM inventarios_transferencias.inventarios_sede_3
) a
UNION ALL
SELECT 'comunes_sede_1_y_3' AS tipo, COUNT(*) AS cantidad FROM (
    SELECT id_producto FROM inventarios_transferencias.inventarios_sede_1
    INTERSECT
    SELECT id_producto FROM inventarios_transferencias.inventarios_sede_3
) b;"

echo ""
echo "[Prueba 9] Comprobar accesos permitidos y denegados para dos roles"
echo "  9a) Permitido: usr_ventas_vendedor consulta pedidos_venta en ventas_pagos"
run_sql ventas_pagos usr_ventas_vendedor "SELECT COUNT(*) AS pedidos_visibles FROM pedidos_venta;"
echo "  9b) Denegado: usr_ventas_vendedor intenta DELETE en pagos"
expect_error ventas_pagos usr_ventas_vendedor \
    "DELETE FROM pagos WHERE id_pago = 1;" \
    "permission denied"
echo "  9c) Permitido: usr_identidad_auditor consulta auditoria_accesos"
run_sql identidad_accesos usr_identidad_auditor "SELECT COUNT(*) AS registros_auditoria FROM auditoria_accesos;"
echo "  9d) Denegado: usr_identidad_auditor intenta consultar usuarios (password_hash)"
expect_error identidad_accesos usr_identidad_auditor \
    "SELECT * FROM usuarios LIMIT 1;" \
    "permission denied"
echo "  9e) Denegado: usr_inventario_auditor intenta UPDATE en inventarios"
expect_error inventarios_transferencias usr_inventario_auditor \
    "UPDATE inventarios SET existencia_actual = 0 WHERE id_almacen = 1;" \
    "permission denied"
echo "  9f) Permitido: usr_reportes_gerencia consulta vista_reporte_corporativo en reportes"
run_sql reportes usr_reportes_gerencia "SELECT id_sede, nombre_sede, monto_ventas_completadas FROM reportes.vista_reporte_corporativo;"
echo "  9g) Denegado: usr_identidad_admin intenta UPDATE y DELETE en auditoria_accesos (inmutabilidad)"
expect_error identidad_accesos usr_identidad_admin \
    "UPDATE auditoria_accesos SET accion = 'HACK' WHERE id_auditoria = 1;" \
    "permission denied"
expect_error identidad_accesos usr_identidad_admin \
    "DELETE FROM auditoria_accesos WHERE id_auditoria = 1;" \
    "permission denied"
echo "  9h) Permitido/Denegado: usr_reportes_app lee vistas pero no puede escribir vía FDW ni leer tablas FDW"
run_sql reportes usr_reportes_app "SELECT id_sede, nombre_sede, monto_ventas_completadas FROM reportes.vista_reporte_corporativo;"
expect_error reportes usr_reportes_app \
    "INSERT INTO ventas_pagos.pedidos_venta (id_pedido, id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado) VALUES (900002, 1, 1, 1, 11, '2026-11-27', 'Pendiente', 0);" \
    "permission denied"
echo "  9i) Permitido/Denegado: usr_reportes_admin lee esquemas FDW y postgres no puede escribir vía FDW"
run_sql reportes usr_reportes_admin "SELECT COUNT(*) AS pedidos_fdw FROM ventas_pagos.pedidos_venta;"
expect_error reportes postgres \
    "INSERT INTO ventas_pagos.pedidos_venta (id_pedido, id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado) VALUES (900002, 1, 1, 1, 11, '2026-11-27', 'Pendiente', 0);" \
    "permission denied"

echo ""
echo "[Prueba 10] Verificar reporte corporativo sin duplicación por relaciones 1:N"
run_sql reportes postgres "
SELECT
    SUM(rc.unidades_inventario)      AS corp_unidades_inv,
    (SELECT SUM(existencia_actual) FROM inventarios_transferencias.inventarios) AS directo_unidades_inv,
    SUM(rc.monto_ventas_completadas) AS corp_ventas,
    (SELECT ROUND(SUM(total_registrado)::numeric, 2) FROM ventas_pagos.pedidos_venta WHERE estado = 'Completado') AS directo_ventas
FROM reportes.vista_reporte_corporativo rc;"

echo ""
echo "TODAS LAS 10 PRUEBAS DE VERIFICACIÓN PASARON EXITOSAMENTE."
