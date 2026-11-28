#!/usr/bin/env bash
# ============================================================================
# Gestiona la carga, configuración FDW, pruebas, consultas y Backend/.env
# contra las 6 bases de datos de Neon usando un archivo claves_neon.txt
# (sin almacenar credenciales en el repositorio).
#
# Uso:
#   ./neon-db.sh status    [ruta_claves]  # Verifica conexión y conteos en Neon
#   ./neon-db.sh init      [ruta_claves]  # Carga 01..04 + FDW + vistas en Neon
#   ./neon-db.sh pruebas   [ruta_claves]  # Ejecuta las 10 pruebas SQL/RBAC
#   ./neon-db.sh consultas [ruta_claves]  # Ejecuta las 20 consultas analíticas
#   ./neon-db.sh env       [ruta_claves]  # Genera Backend/.env para Neon
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ACCION="${1:-}"
CLAVES_FILE="${2:-$REPO_ROOT/claves_neon.txt}"

if [[ -z "$ACCION" ]]; then
    echo "Uso: ./neon-db.sh <status | init | pruebas | consultas | env> [ruta_claves]" >&2
    exit 1
fi

if [[ ! -f "$CLAVES_FILE" ]]; then
    echo "Error: no existe el archivo de claves: $CLAVES_FILE" >&2
    exit 1
fi

# Parsea las 6 URLs directas (DATABASE_URL=...) desde claves_neon.txt
eval "$(
python3 - "$CLAVES_FILE" <<'PY'
import re
import shlex
import sys
from urllib.parse import unquote, urlparse

path = sys.argv[1]
sections = {}
current = None

with open(path, encoding="utf-8") as fh:
    for raw in fh:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r'^DATABASE_URL="([^"]+)"$', line)
        if m and current:
            sections[current] = m.group(1)
        elif not line.startswith("DATABASE_URL"):
            current = line.lower()

mapping = {
    "catalogo": ("catalogo y terceros", "catalogo_terceros"),
    "compras": ("compras y abastecimiento", "compras_abastecimiento"),
    "inventarios": ("inventarios y transferencias", "inventarios_transferencias"),
    "ventas": ("compras y ventas", "ventas_pagos"),
    "identidad": ("identidad y accesos", "identidad_accesos"),
    "reportes": ("reportes", "reportes"),
}

# Acepta también etiqueta explícita "ventas y pagos"
if "ventas y pagos" in sections and "compras y ventas" not in sections:
    mapping["ventas"] = ("ventas y pagos", "ventas_pagos")

for key, (label, _) in mapping.items():
    if label not in sections:
        raise SystemExit(f"Falta la sección '{label}' con DATABASE_URL en {path}")
    url = sections[label]
    p = urlparse(url)
    print(f"URL_{key.upper()}={shlex.quote(url)}")
    print(f"HOST_{key.upper()}={shlex.quote(p.hostname or '')}")
    print(f"PORT_{key.upper()}={shlex.quote(str(p.port or 5432))}")
    print(f"DB_{key.upper()}={shlex.quote((p.path or '/neondb').lstrip('/'))}")
    print(f"USER_{key.upper()}={shlex.quote(unquote(p.username or 'neondb_owner'))}")
    print(f"PASS_{key.upper()}={shlex.quote(unquote(p.password or ''))}")
PY
)"

url_para_rol() {
    local svc="$1"
    local user="$2"
    local host="" db="" pass=""

    case "$svc" in
        catalogo_terceros)          host="$HOST_CATALOGO";    db="$DB_CATALOGO";    pass="$PASS_CATALOGO" ;;
        compras_abastecimiento)     host="$HOST_COMPRAS";     db="$DB_COMPRAS";     pass="$PASS_COMPRAS" ;;
        inventarios_transferencias) host="$HOST_INVENTARIOS"; db="$DB_INVENTARIOS"; pass="$PASS_INVENTARIOS" ;;
        ventas_pagos)               host="$HOST_VENTAS";      db="$DB_VENTAS";      pass="$PASS_VENTAS" ;;
        identidad_accesos)          host="$HOST_IDENTIDAD";   db="$DB_IDENTIDAD";   pass="$PASS_IDENTIDAD" ;;
        reportes)                   host="$HOST_REPORTES";    db="$DB_REPORTES";    pass="$PASS_REPORTES" ;;
        *) echo "Servicio desconocido: $svc" >&2; exit 1 ;;
    esac

    case "$user" in
        neondb_owner) ;;
        usr_catalogo_admin)      pass="Catalogo#Admin_2026" ;;
        usr_catalogo_lector)     pass="Catalogo#Lector_2026" ;;
        usr_compras_admin)       pass="Compras#Admin_2026" ;;
        usr_compras_operador)    pass="Compras#Oper_2026" ;;
        usr_compras_auditor)     pass="Compras#Audi_2026" ;;
        usr_inventario_admin)    pass="Invent#Admin_2026" ;;
        usr_inventario_operador) pass="Invent#Oper_2026" ;;
        usr_inventario_auditor)  pass="Invent#Audi_2026" ;;
        usr_ventas_admin)        pass="Ventas#Admin_2026" ;;
        usr_ventas_vendedor)     pass="Ventas#Vend_2026" ;;
        usr_ventas_gerencia)     pass="Ventas#Geren_2026" ;;
        usr_ventas_auditor)      pass="Ventas#Audi_2026" ;;
        usr_identidad_admin)     pass="Identidad#Admin_2026" ;;
        usr_identidad_auditor)   pass="Identidad#Auditor_2026" ;;
        usr_reportes_admin)      pass="Reportes#Admin_2026" ;;
        usr_reportes_gerencia)   pass="Reportes#Geren_2026" ;;
        usr_reportes_auditor)    pass="Reportes#Audi_2026" ;;
        usr_reportes_lector)     pass="Reportes#Lector_2026" ;;
        usr_reportes_app)        pass="Reportes#App_2026" ;;
        *) echo "Usuario desconocido: $user" >&2; exit 1 ;;
    esac

    python3 - "$user" "$pass" "$host" "$db" <<'PY'
import sys
from urllib.parse import quote
user, pwd, host, db = sys.argv[1:]
print(f"postgresql://{quote(user, safe='')}:{quote(pwd, safe='')}@{host}/{db}?sslmode=require")
PY
}

estado_neon() {
    local pares=(
        "catalogo_terceros:$URL_CATALOGO"
        "compras_abastecimiento:$URL_COMPRAS"
        "inventarios_transferencias:$URL_INVENTARIOS"
        "ventas_pagos:$URL_VENTAS"
        "identidad_accesos:$URL_IDENTIDAD"
        "reportes:$URL_REPORTES"
    )
    for par in "${pares[@]}"; do
        local nombre="${par%%:*}"
        local url="${par#*:}"
        echo "=== $nombre ==="
        psql "$url" -At -c "
            SELECT 'usuario=' || current_user || ' bd=' || current_database() || ' ver=' || split_part(version(), ' ', 2);
            SELECT 'tablas=' || COUNT(*) FILTER (WHERE table_type = 'BASE TABLE')
                || ' vistas=' || COUNT(*) FILTER (WHERE table_type = 'VIEW')
                || ' externas=' || COUNT(*) FILTER (WHERE table_type = 'FOREIGN')
            FROM information_schema.tables
            WHERE table_schema NOT IN ('pg_catalog', 'information_schema');
        "
    done
}

cargar_neon() {
    local operacionales=(
        "catalogo_terceros:$URL_CATALOGO"
        "compras_abastecimiento:$URL_COMPRAS"
        "inventarios_transferencias:$URL_INVENTARIOS"
        "ventas_pagos:$URL_VENTAS"
        "identidad_accesos:$URL_IDENTIDAD"
    )
    for par in "${operacionales[@]}"; do
        local svc="${par%%:*}"
        local url="${par#*:}"
        echo "→ Cargando $svc en Neon ..."
        for sql in 01_tablas.sql 02_constraints.sql 03_datos.sql 04_seguridad.sql; do
            psql "$url" -v ON_ERROR_STOP=1 -q -f "$SCRIPT_DIR/$svc/$sql"
        done
    done

    echo "→ Configurando reportes (FDW TLS + 12 vistas + seguridad) en Neon ..."
    local fdw_tmp
    fdw_tmp="$(mktemp)"
    trap 'rm -f "$fdw_tmp"' RETURN

    cat > "$fdw_tmp" <<SQL
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SCHEMA IF NOT EXISTS catalogo_terceros;
CREATE SCHEMA IF NOT EXISTS compras_abastecimiento;
CREATE SCHEMA IF NOT EXISTS inventarios_transferencias;
CREATE SCHEMA IF NOT EXISTS ventas_pagos;
CREATE SCHEMA IF NOT EXISTS identidad_accesos;
CREATE SCHEMA IF NOT EXISTS reportes;

DROP SERVER IF EXISTS srv_catalogo CASCADE;
CREATE SERVER srv_catalogo FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '$HOST_CATALOGO', port '$PORT_CATALOGO', dbname '$DB_CATALOGO', sslmode 'require');

DROP SERVER IF EXISTS srv_compras CASCADE;
CREATE SERVER srv_compras FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '$HOST_COMPRAS', port '$PORT_COMPRAS', dbname '$DB_COMPRAS', sslmode 'require');

DROP SERVER IF EXISTS srv_inventarios CASCADE;
CREATE SERVER srv_inventarios FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '$HOST_INVENTARIOS', port '$PORT_INVENTARIOS', dbname '$DB_INVENTARIOS', sslmode 'require');

DROP SERVER IF EXISTS srv_ventas CASCADE;
CREATE SERVER srv_ventas FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '$HOST_VENTAS', port '$PORT_VENTAS', dbname '$DB_VENTAS', sslmode 'require');

DROP SERVER IF EXISTS srv_identidad CASCADE;
CREATE SERVER srv_identidad FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '$HOST_IDENTIDAD', port '$PORT_IDENTIDAD', dbname '$DB_IDENTIDAD', sslmode 'require');

CREATE USER MAPPING FOR PUBLIC SERVER srv_catalogo
    OPTIONS (user 'usr_catalogo_lector', password 'Catalogo#Lector_2026');
CREATE USER MAPPING FOR PUBLIC SERVER srv_compras
    OPTIONS (user 'usr_compras_auditor', password 'Compras#Audi_2026');
CREATE USER MAPPING FOR PUBLIC SERVER srv_inventarios
    OPTIONS (user 'usr_inventario_auditor', password 'Invent#Audi_2026');
CREATE USER MAPPING FOR PUBLIC SERVER srv_ventas
    OPTIONS (user 'usr_ventas_auditor', password 'Ventas#Audi_2026');
CREATE USER MAPPING FOR PUBLIC SERVER srv_identidad
    OPTIONS (user 'usr_identidad_auditor', password 'Identidad#Auditor_2026');

IMPORT FOREIGN SCHEMA public FROM SERVER srv_catalogo    INTO catalogo_terceros;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_compras     INTO compras_abastecimiento;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_inventarios INTO inventarios_transferencias;
IMPORT FOREIGN SCHEMA public FROM SERVER srv_ventas      INTO ventas_pagos;
IMPORT FOREIGN SCHEMA public LIMIT TO (empleados, auditoria_accesos)
    FROM SERVER srv_identidad INTO identidad_accesos;

CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_1 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_1');
CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_2 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_2');
CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_3 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_3');
CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_4 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_4');
CREATE FOREIGN TABLE IF NOT EXISTS inventarios_transferencias.inventarios_sede_5 (
    id_sede INT, id_almacen INT, id_producto INT,
    existencia_actual INT, stock_minimo INT, fecha_actualizacion DATE
) SERVER srv_inventarios OPTIONS (schema_name 'public', table_name 'inventarios_sede_5');

CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_1 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_1');
CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_2 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_2');
CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_3 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_3');
CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_4 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_4');
CREATE FOREIGN TABLE IF NOT EXISTS ventas_pagos.pedidos_venta_sede_5 (
    id_pedido INT, id_sede INT, id_almacen INT, id_cliente INT,
    id_empleado INT, fecha_pedido DATE, estado VARCHAR(20), total_registrado NUMERIC(12,2)
) SERVER srv_ventas OPTIONS (schema_name 'public', table_name 'pedidos_venta_sede_5');
SQL

    psql "$URL_REPORTES" -v ON_ERROR_STOP=1 -q -f "$fdw_tmp"
    psql "$URL_REPORTES" -v ON_ERROR_STOP=1 -q -f "$SCRIPT_DIR/reportes/02_vistas.sql"
    psql "$URL_REPORTES" -v ON_ERROR_STOP=1 -q -f "$SCRIPT_DIR/reportes/04_seguridad.sql"
    echo "Las 6 bases en Neon quedaron inicializadas y pobladas."
}

run_sql() {
    local db="$1"
    local user="$2"
    local sql="$3"
    local url
    url="$(url_para_rol "$db" "$user")"
    psql "$url" -v ON_ERROR_STOP=1 -P pager=off -c "$sql"
}

expect_error() {
    local db="$1"
    local user="$2"
    local sql="$3"
    local expected_pattern="$4"
    local url
    url="$(url_para_rol "$db" "$user")"
    local out
    set +e
    out=$(psql "$url" -v ON_ERROR_STOP=1 -c "$sql" 2>&1)
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

ejecutar_pruebas_neon() {
    echo "=================================================================="
    echo "MATRIZ DE 10 PRUEBAS DE VERIFICACIÓN — NEON POSTGRESQL"
    echo "=================================================================="

    echo ""
    echo "[Prueba 1] Crear un producto válido y consultar su registro (rollback al final)"
    run_sql catalogo_terceros neondb_owner "
BEGIN;
INSERT INTO productos (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista, estado)
VALUES (999, 'SKU-99999', 'Producto Prueba Válida', 1, 'Unidad', 12500.00, 'Activo');
SELECT id_producto, sku, nombre, precio_lista, estado FROM productos WHERE id_producto = 999;
ROLLBACK;"

    echo ""
    echo "[Prueba 2] Intentar duplicar un SKU y comprobar rechazo UNIQUE (uq_productos_sku)"
    expect_error catalogo_terceros neondb_owner \
        "INSERT INTO productos (id_producto, sku, nombre, id_categoria, unidad_medida, precio_lista) VALUES (998, 'SKU-00001', 'Duplicado', 1, 'Unidad', 5000);" \
        "uq_productos_sku|duplicate key|23505"

    echo ""
    echo "[Prueba 3] Intentar registrar cantidad negativa y comprobar rechazo CHECK (ck_detalle_pedido_cantidad)"
    expect_error ventas_pagos neondb_owner \
        "INSERT INTO detalle_pedido (id_sede, id_pedido, id_producto, cantidad, precio_unitario) VALUES (1, 1, 99, -5, 1000);" \
        "ck_detalle_pedido_cantidad|check constraint|23514"

    echo ""
    echo "[Prueba 4] Intentar referenciar clave inexistente en FK local (fk_detalle_oc_orden)"
    expect_error compras_abastecimiento neondb_owner \
        "INSERT INTO detalle_orden_compra (id_orden_compra, id_producto, cantidad_solicitada, costo_unitario) VALUES (99999, 1, 10, 5000);" \
        "fk_detalle_oc_orden|foreign key|23503"

    echo ""
    echo "[Prueba 5] Consultar fragmentos de dos sedes por separado y comprobar disyunción"
    run_sql inventarios_transferencias neondb_owner "
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
    run_sql reportes neondb_owner "
SELECT
    (SELECT COUNT(*) FROM reportes.vista_inventarios_fragmentos_union) AS total_vista_union,
    (SELECT COUNT(*) FROM inventarios_transferencias.inventarios)     AS total_tabla_particionada,
    (SELECT COUNT(DISTINCT id_sede) FROM reportes.vista_inventarios_fragmentos_union) AS sedes_cubiertas;"

    echo ""
    echo "[Prueba 7] Consulta avanzada con CTE y función de ventana (LAG + DENSE_RANK)"
    run_sql reportes neondb_owner "
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
    run_sql reportes neondb_owner "
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
    echo "[Prueba 9] Comprobar accesos permitidos y denegados para roles RBAC en Neon"
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
    echo "  9i) Permitido/Denegado: usr_reportes_admin lee esquemas FDW y neondb_owner no puede escribir vía FDW"
    run_sql reportes usr_reportes_admin "SELECT COUNT(*) AS pedidos_fdw FROM ventas_pagos.pedidos_venta;"
    expect_error reportes neondb_owner \
        "INSERT INTO ventas_pagos.pedidos_venta (id_pedido, id_sede, id_almacen, id_cliente, id_empleado, fecha_pedido, estado, total_registrado) VALUES (900002, 1, 1, 1, 11, '2026-11-27', 'Pendiente', 0);" \
        "permission denied"

    echo ""
    echo "[Prueba 10] Verificar reporte corporativo sin duplicación por relaciones 1:N"
    run_sql reportes neondb_owner "
SELECT
    SUM(rc.unidades_inventario)      AS corp_unidades_inv,
    (SELECT SUM(existencia_actual) FROM inventarios_transferencias.inventarios) AS directo_unidades_inv,
    SUM(rc.monto_ventas_completadas) AS corp_ventas,
    (SELECT ROUND(SUM(total_registrado)::numeric, 2) FROM ventas_pagos.pedidos_venta WHERE estado = 'Completado') AS directo_ventas
FROM reportes.vista_reporte_corporativo rc;"

    echo ""
    echo "TODAS LAS 10 PRUEBAS DE VERIFICACIÓN EN NEON PASARON EXITOSAMENTE."
}

generar_env() {
    local env_path="$REPO_ROOT/Backend/.env"
    cat > "$env_path" <<ENV
# Configuración de las 6 bases de datos en Neon (generado desde claves_neon.txt)
CATALOGO_DB_URL=jdbc:postgresql://${HOST_CATALOGO}/${DB_CATALOGO}?sslmode=require
CATALOGO_DB_USER=${USER_CATALOGO}
CATALOGO_DB_PASSWORD=${PASS_CATALOGO}

COMPRAS_DB_URL=jdbc:postgresql://${HOST_COMPRAS}/${DB_COMPRAS}?sslmode=require
COMPRAS_DB_USER=${USER_COMPRAS}
COMPRAS_DB_PASSWORD=${PASS_COMPRAS}

INVENTARIOS_DB_URL=jdbc:postgresql://${HOST_INVENTARIOS}/${DB_INVENTARIOS}?sslmode=require
INVENTARIOS_DB_USER=${USER_INVENTARIOS}
INVENTARIOS_DB_PASSWORD=${PASS_INVENTARIOS}

VENTAS_DB_URL=jdbc:postgresql://${HOST_VENTAS}/${DB_VENTAS}?sslmode=require
VENTAS_DB_USER=${USER_VENTAS}
VENTAS_DB_PASSWORD=${PASS_VENTAS}

IDENTIDAD_DB_URL=jdbc:postgresql://${HOST_IDENTIDAD}/${DB_IDENTIDAD}?sslmode=require
IDENTIDAD_DB_USER=${USER_IDENTIDAD}
IDENTIDAD_DB_PASSWORD=${PASS_IDENTIDAD}

REPORTES_DB_URL=jdbc:postgresql://${HOST_REPORTES}/${DB_REPORTES}?sslmode=require
REPORTES_DB_USER=usr_reportes_app
REPORTES_DB_PASSWORD=Reportes#App_2026

CATALOGO_URL=http://localhost:8081
COMPRAS_URL=http://localhost:8082
INVENTARIOS_URL=http://localhost:8083
VENTAS_URL=http://localhost:8084
IDENTIDAD_URL=http://localhost:8085
ENV
    echo "Generado $env_path apuntando a Neon."
}

case "$ACCION" in
    status)    estado_neon ;;
    init)      cargar_neon ;;
    pruebas)   ejecutar_pruebas_neon ;;
    consultas) psql "$URL_REPORTES" -v ON_ERROR_STOP=1 -P pager=off -f "$SCRIPT_DIR/reportes/03_consultas_analiticas.sql" ;;
    env)       generar_env ;;
    *)
        echo "Acción desconocida: $ACCION" >&2
        echo "Uso: ./neon-db.sh <status | init | pruebas | consultas | env> [ruta_claves]" >&2
        exit 1
        ;;
esac
