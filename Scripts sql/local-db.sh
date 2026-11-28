#!/usr/bin/env bash
# ============================================================================
# Gestiona una instancia local de PostgreSQL para los 6 microservicios
# (catalogo_terceros, compras_abastecimiento, inventarios_transferencias,
#  ventas_pagos, identidad_accesos y reportes) y carga todos los scripts SQL.
#
# Uso:
#   ./local-db.sh start      # Inicializa .pgdata/ si falta y arranca PostgreSQL
#   ./local-db.sh stop       # Detiene PostgreSQL local
#   ./local-db.sh status     # Muestra estado y bases de datos
#   ./local-db.sh init       # Recrea las 6 bases y ejecuta los scripts SQL
#   ./local-db.sh consultas  # Ejecuta las 20 consultas analíticas en reportes
#   ./local-db.sh pruebas    # Ejecuta la matriz de pruebas de verificación
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PGDATA="${PGDATA:-$REPO_ROOT/.pgdata}"
PGLOG="$PGDATA/postgres.log"
PGPORT="${PGPORT:-5433}"
PGHOST="${PGHOST:-localhost}"
PGUSER="${PGUSER:-postgres}"

SERVICIOS=(
    "catalogo_terceros"
    "compras_abastecimiento"
    "inventarios_transferencias"
    "ventas_pagos"
    "identidad_accesos"
)

TODAS_LAS_BD=(
    "${SERVICIOS[@]}"
    "reportes"
)

psql_exec() {
    local db="$1"
    shift
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$db" -v ON_ERROR_STOP=1 "$@"
}

inicializar_cluster() {
    if [[ -f "$PGDATA/PG_VERSION" ]]; then
        return 0
    fi
    echo "Inicializando clúster PostgreSQL local en $PGDATA ..."
    mkdir -p "$PGDATA"
    initdb -D "$PGDATA" -U "$PGUSER" --auth=trust -E UTF8 --locale=C >/dev/null
    {
        echo "listen_addresses = 'localhost'"
        echo "port = $PGPORT"
        echo "unix_socket_directories = '/tmp'"
        echo "logging_collector = off"
    } >> "$PGDATA/postgresql.conf"
}

arrancar() {
    inicializar_cluster
    if pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1 || pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
        echo "PostgreSQL local ya está activo en $PGHOST:$PGPORT"
        return 0
    fi
    if pg_isready -h /tmp -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
        PGHOST="/tmp"
        echo "PostgreSQL local ya está activo vía socket /tmp:$PGPORT"
        return 0
    fi
    echo "Iniciando PostgreSQL local en $PGHOST:$PGPORT ..."
    pg_ctl -D "$PGDATA" -l "$PGLOG" -o "-p $PGPORT -k /tmp" start >/dev/null
    for _ in $(seq 1 20); do
        if pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" >/dev/null 2>&1; then
            echo "PostgreSQL listo en $PGHOST:$PGPORT"
            return 0
        fi
        sleep 0.3
    done
    echo "Error: PostgreSQL no respondió a tiempo. Revisa $PGLOG" >&2
    exit 1
}

detener() {
    if [[ ! -f "$PGDATA/PG_VERSION" ]]; then
        echo "No existe clúster inicializado en $PGDATA"
        return 0
    fi
    if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
        pg_ctl -D "$PGDATA" -m fast stop >/dev/null
        echo "PostgreSQL local detenido"
    else
        echo "PostgreSQL local ya estaba detenido"
    fi
}

estado() {
    if [[ -f "$PGDATA/PG_VERSION" ]] && pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
        echo "PostgreSQL local: ACTIVO ($PGHOST:$PGPORT, datos en $PGDATA)"
        psql_exec postgres -c "\l"
    else
        echo "PostgreSQL local: DETENIDO (datos en $PGDATA)"
    fi
}

cargar_bases() {
    arrancar
    echo "Creando/reiniciando las 6 bases de datos..."
    for db in "${TODAS_LAS_BD[@]}"; do
        psql_exec postgres -c "DROP DATABASE IF EXISTS $db WITH (FORCE);" >/dev/null
        psql_exec postgres -c "CREATE DATABASE $db ENCODING 'UTF8';" >/dev/null
    done

    for svc in "${SERVICIOS[@]}"; do
        echo "→ Cargando $svc ..."
        for sql in 01_tablas.sql 02_constraints.sql 03_datos.sql 04_seguridad.sql; do
            psql_exec "$svc" -f "$SCRIPT_DIR/$svc/$sql" >/dev/null
        done
    done

    echo "→ Cargando reportes (FDW + 10 vistas + seguridad) ..."
    psql_exec reportes -f "$SCRIPT_DIR/reportes/01_fdw_integracion.sql" >/dev/null
    psql_exec reportes -f "$SCRIPT_DIR/reportes/02_vistas.sql" >/dev/null
    psql_exec reportes -f "$SCRIPT_DIR/reportes/04_seguridad.sql" >/dev/null
    echo "Las 6 bases de datos quedaron inicializadas y pobladas."
}

ejecutar_consultas() {
    arrancar
    psql_exec reportes -P pager=off -f "$SCRIPT_DIR/reportes/03_consultas_analiticas.sql"
}

ejecutar_pruebas() {
    arrancar
    PGHOST="$PGHOST" PGPORT="$PGPORT" bash "$SCRIPT_DIR/reportes/ejecutar_pruebas.sh"
}

case "${1:-}" in
    start)     arrancar ;;
    stop)      detener ;;
    status)    estado ;;
    init|reset) cargar_bases ;;
    consultas) ejecutar_consultas ;;
    pruebas)   ejecutar_pruebas ;;
    *)
        echo "Uso: ./local-db.sh <start | stop | status | init | consultas | pruebas>"
        exit 1
        ;;
esac
