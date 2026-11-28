#!/usr/bin/env bash
# Arranca, detiene o consulta el estado de los 6 microservicios en local (sin Docker).
set -euo pipefail

cd "$(dirname "$0")"

SERVICIOS=(
    "catalogo-service:CATALOGO:8081"
    "compras-service:COMPRAS:8082"
    "inventarios-service:INVENTARIOS:8083"
    "ventas-service:VENTAS:8084"
    "identidad-service:IDENTIDAD:8085"
    "reportes-service:REPORTES:8086"
)

RUNTIME_DIR=".runtime"

cargar_env() {
    if [[ -f .env ]]; then
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
    else
        echo "Aviso: Backend/.env no existe; se usarán los valores por defecto de localhost."
    fi
}

resolver_java() {
    if [[ -x "$HOME/.local/opt/jdk-25.0.5.1+2/bin/java" ]]; then
        export JAVA_HOME="$HOME/.local/opt/jdk-25.0.5.1+2"
        echo "$JAVA_HOME/bin/java"
    else
        command -v java
    fi
}

compilar_si_falta() {
    local forzar="${1:-false}"
    local falta=false
    for entrada in "${SERVICIOS[@]}"; do
        IFS=':' read -r nombre _ _ <<< "$entrada"
        if [[ ! -f "$nombre/target/$nombre-0.0.1-SNAPSHOT.jar" ]]; then
            falta=true
            break
        fi
    done
    if [[ "$forzar" == "true" || "$falta" == "true" ]]; then
        echo "Empaquetando microservicios..."
        ./mvnw -q -B -DskipTests package
    fi
}

arrancar() {
    local forzar_build="${1:-false}"
    cargar_env
    local java_bin
    java_bin="$(resolver_java)"
    compilar_si_falta "$forzar_build"
    mkdir -p "$RUNTIME_DIR"

    for entrada in "${SERVICIOS[@]}"; do
        IFS=':' read -r nombre prefijo puerto <<< "$entrada"
        local pid_file="$RUNTIME_DIR/$nombre.pid"
        if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
            echo "$nombre ya está corriendo (PID $(cat "$pid_file"), puerto $puerto)"
            continue
        fi

        local url_var="${prefijo}_DB_URL"
        local user_var="${prefijo}_DB_USER"
        local pass_var="${prefijo}_DB_PASSWORD"
        local jar="$nombre/target/$nombre-0.0.1-SNAPSHOT.jar"
        local log="$RUNTIME_DIR/$nombre.log"

        local env_args=()
        [[ -n "${!url_var:-}" ]] && env_args+=("DB_URL=${!url_var}")
        [[ -n "${!user_var:-}" ]] && env_args+=("DB_USER=${!user_var}")
        [[ -n "${!pass_var:-}" ]] && env_args+=("DB_PASSWORD=${!pass_var}")

        env "${env_args[@]}" \
            nohup "$java_bin" -XX:MaxRAMPercentage=25 -jar "$jar" >"$log" 2>&1 &
        echo $! > "$pid_file"
        echo "Iniciado $nombre en puerto $puerto (PID $!, log: $log)"
    done

    echo "Esperando apertura de puertos HTTP (en frío puede tardar hasta ~80 s)..."
    for entrada in "${SERVICIOS[@]}"; do
        IFS=':' read -r nombre _ puerto <<< "$entrada"
        local listo=false
        for _ in $(seq 1 120); do
            if curl -sf "http://localhost:$puerto/api/health" >/dev/null 2>&1; then
                listo=true
                break
            fi
            sleep 1
        done
        if [[ "$listo" == "true" ]]; then
            echo "  ✓ $nombre listo en http://localhost:$puerto/api/health"
        else
            echo "  ! $nombre aún iniciando; revisa $RUNTIME_DIR/$nombre.log"
        fi
    done
}

detener() {
    if [[ ! -d "$RUNTIME_DIR" ]]; then
        echo "No hay servicios registrados en $RUNTIME_DIR."
        return 0
    fi
    for entrada in "${SERVICIOS[@]}"; do
        IFS=':' read -r nombre _ _ <<< "$entrada"
        local pid_file="$RUNTIME_DIR/$nombre.pid"
        if [[ -f "$pid_file" ]]; then
            local pid
            pid="$(cat "$pid_file")"
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid"
                echo "Detenido $nombre (PID $pid)"
            fi
            rm -f "$pid_file"
        fi
    done
}

estado() {
    for entrada in "${SERVICIOS[@]}"; do
        IFS=':' read -r nombre _ puerto <<< "$entrada"
        local pid_file="$RUNTIME_DIR/$nombre.pid"
        if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
            if curl -sf "http://localhost:$puerto/api/health" >/dev/null 2>&1; then
                echo "$nombre : activo y respondiendo (PID $(cat "$pid_file"), http://localhost:$puerto/api/health)"
            else
                echo "$nombre : iniciando sin puerto HTTP abierto aún (PID $(cat "$pid_file"), puerto $puerto)"
            fi
        else
            echo "$nombre : detenido"
        fi
    done
}

case "${1:-}" in
    start)
        arrancar "$([[ "${2:-}" == "--build" ]] && echo true || echo false)"
        ;;
    stop)
        detener
        ;;
    status)
        estado
        ;;
    *)
        echo "Uso: ./run-all.sh <start [--build] | stop | status>"
        exit 1
        ;;
esac
