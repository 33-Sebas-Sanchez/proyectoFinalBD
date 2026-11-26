#!/usr/bin/env bash
# Ejecuta un microservicio en local con las credenciales de .env
set -euo pipefail

SERVICIO="${1:-}"
if [[ -z "$SERVICIO" ]]; then
    echo "Uso: ./run-local.sh <catalogo-service|compras-service|inventarios-service|ventas-service|identidad-service|reportes-service>"
    exit 1
fi

cd "$(dirname "$0")"

if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

case "$SERVICIO" in
    catalogo-service)    prefijo="CATALOGO" ;;
    compras-service)     prefijo="COMPRAS" ;;
    inventarios-service) prefijo="INVENTARIOS" ;;
    ventas-service)      prefijo="VENTAS" ;;
    identidad-service)   prefijo="IDENTIDAD" ;;
    reportes-service)    prefijo="REPORTES" ;;
    *)
        echo "Servicio desconocido: $SERVICIO"
        exit 1
        ;;
esac

url_var="${prefijo}_DB_URL"
user_var="${prefijo}_DB_USER"
password_var="${prefijo}_DB_PASSWORD"

export DB_URL="${!url_var:-}"
export DB_USER="${!user_var:-}"
export DB_PASSWORD="${!password_var:-}"

exec ./mvnw -q -pl "$SERVICIO" -am spring-boot:run
