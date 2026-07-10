#!/bin/bash
# Fleet orchestrator: ping/SSH availability, remote scan, local artifact collection.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR" || exit 2

INVENTORY_FILE=""
FLEET_CLASS=""
FLEET_BATCH_ID=""
FLEET_OUTPUT_ROOT=""
FLEET_PARALLEL=""
FLEET_PING_TIMEOUT=2
FLEET_CONNECT_TIMEOUT=10
FLEET_NO_DEPLOY=false
FLEET_NO_SFTP=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --inventory)
            shift
            [ "$#" -gt 0 ] || { echo "Ошибка: для --inventory нужен путь к файлу." >&2; exit 2; }
            INVENTORY_FILE="$1"
            ;;
        --inventory=*)
            INVENTORY_FILE="${1#*=}"
            ;;
        --class|--security-class|-c)
            shift
            [ "$#" -gt 0 ] || { echo "Ошибка: для --class нужно указать K1, K2 или K3." >&2; exit 2; }
            FLEET_CLASS="$1"
            ;;
        --class=*|--security-class=*)
            FLEET_CLASS="${1#*=}"
            ;;
        --batch-id)
            shift
            [ "$#" -gt 0 ] || { echo "Ошибка: для --batch-id нужен идентификатор." >&2; exit 2; }
            FLEET_BATCH_ID="$1"
            ;;
        --batch-id=*)
            FLEET_BATCH_ID="${1#*=}"
            ;;
        --output-dir)
            shift
            [ "$#" -gt 0 ] || { echo "Ошибка: для --output-dir нужен каталог." >&2; exit 2; }
            FLEET_OUTPUT_ROOT="$1"
            ;;
        --output-dir=*)
            FLEET_OUTPUT_ROOT="${1#*=}"
            ;;
        --parallel|-j)
            shift
            [ "$#" -gt 0 ] || { echo "Ошибка: для --parallel нужно указать число (0 = все сразу)." >&2; exit 2; }
            FLEET_PARALLEL="$1"
            ;;
        --parallel=*|-j=*)
            FLEET_PARALLEL="${1#*=}"
            ;;
        --no-deploy)
            FLEET_NO_DEPLOY=true
            ;;
        --no-sftp)
            FLEET_NO_SFTP=true
            ;;
        --help|-h)
            cat <<'EOF'
Usage: run_fleet.sh --inventory <file> [--class K1|K2|K3] [--batch-id <id>] [--output-dir <dir>] [--parallel N]

Runs check_all.sh on each host from the inventory via SSH (sudo -n on the VM by
default). Before each scan, rsyncs the local checks bundle from the controller
to FSTEK_REMOTE_REPO (FSTEK_AUTO_DEPLOY=true by default). Collects log/JSON
artifacts locally under output/fleet/<batch-id>/, and writes fleet-summary.csv.
Host scans run in parallel; --parallel 0 launches all hosts at once (default).
Use --no-deploy if the bundle is already managed on targets.
After the batch finishes, writes fleet-measures.csv and fleet-measure-rollups.csv.
Optional SFTP upload: FSTEK_SFTP_ENABLED=true (see config/sftp.example.conf).
EOF
            exit 0
            ;;
        *)
            echo "Ошибка: неизвестный аргумент: $1" >&2
            exit 2
            ;;
    esac
    shift
done

[ -n "$INVENTORY_FILE" ] || {
    echo "Ошибка: укажите --inventory <file>." >&2
    exit 2
}
[ -r "$INVENTORY_FILE" ] || {
    echo "Ошибка: inventory не найден: $INVENTORY_FILE" >&2
    exit 2
}

# shellcheck disable=SC1090
. "$INVENTORY_FILE"

FSTEK_FLEET_CLASS="${FSTEK_FLEET_CLASS:-$FLEET_CLASS}"
[ -n "$FSTEK_FLEET_CLASS" ] || {
    echo "Ошибка: задайте FSTEK_FLEET_CLASS в inventory или передайте --class." >&2
    exit 2
}

FSTEK_REMOTE_REPO="${FSTEK_REMOTE_REPO:-/opt/fstek-checks-2026}"
FSTEK_SSH_USER="${FSTEK_SSH_USER:-root}"
FSTEK_SSH_PORT="${FSTEK_SSH_PORT:-22}"
FSTEK_SSH_KEY="${FSTEK_SSH_KEY:-}"
FSTEK_SSH_PASSWORD_ENV="${FSTEK_SSH_PASSWORD_ENV:-FSTEK_SSH_PASSWORD}"
FSTEK_SSH_AUTH="${FSTEK_SSH_AUTH:-auto}"
FSTEK_REMOTE_SUDO="${FSTEK_REMOTE_SUDO:-true}"
FSTEK_AUTO_DEPLOY="${FSTEK_AUTO_DEPLOY:-true}"
FSTEK_DEPLOY_SOURCE="${FSTEK_DEPLOY_SOURCE:-$ROOT_DIR}"
if $FLEET_NO_DEPLOY; then
    FSTEK_AUTO_DEPLOY=false
fi
FSTEK_PING_TIMEOUT="${FSTEK_PING_TIMEOUT:-$FLEET_PING_TIMEOUT}"
FSTEK_SSH_CONNECT_TIMEOUT="${FSTEK_SSH_CONNECT_TIMEOUT:-$FLEET_CONNECT_TIMEOUT}"
FSTEK_FLEET_PARALLEL="${FSTEK_FLEET_PARALLEL:-${FLEET_PARALLEL:-0}}"
FSTEK_SFTP_ENABLED="${FSTEK_SFTP_ENABLED:-false}"
FSTEK_SFTP_HOST="${FSTEK_SFTP_HOST:-}"
FSTEK_SFTP_USER="${FSTEK_SFTP_USER:-$FSTEK_SSH_USER}"
FSTEK_SFTP_PORT="${FSTEK_SFTP_PORT:-$FSTEK_SSH_PORT}"
FSTEK_SFTP_KEY="${FSTEK_SFTP_KEY:-$FSTEK_SSH_KEY}"
FSTEK_SFTP_PASSWORD_ENV="${FSTEK_SFTP_PASSWORD_ENV:-$FSTEK_SSH_PASSWORD_ENV}"
FSTEK_SFTP_AUTH="${FSTEK_SFTP_AUTH:-$FSTEK_SSH_AUTH}"
FSTEK_SFTP_REMOTE_DIR="${FSTEK_SFTP_REMOTE_DIR:-/home/bob/fstek-fleet-inbox}"
FSTEK_KEEP_LOCAL="${FSTEK_KEEP_LOCAL:-true}"
if $FLEET_NO_SFTP; then
    FSTEK_SFTP_ENABLED=false
fi

case "$FSTEK_SSH_AUTH" in
    auto|key|password) ;;
    *)
        echo "Ошибка: FSTEK_SSH_AUTH должен быть auto, key или password." >&2
        exit 2
        ;;
esac

if ! [[ "$FSTEK_FLEET_PARALLEL" =~ ^[0-9]+$ ]]; then
    echo "Ошибка: FSTEK_FLEET_PARALLEL/--parallel должен быть неотрицательным числом." >&2
    exit 2
fi

[ -n "${FSTEK_FLEET_HOSTS[*]-}" ] || {
    echo "Ошибка: inventory не определяет FSTEK_FLEET_HOSTS." >&2
    exit 2
}

# shellcheck disable=SC1091
. "$SCRIPT_DIR/core/load.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/core/fleet.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/core/aggregate.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/core/sftp.sh"

if fstek_fleet_bool "$FSTEK_SFTP_ENABLED"; then
    [ -n "$FSTEK_SFTP_HOST" ] || {
        echo "Ошибка: FSTEK_SFTP_ENABLED=true, но FSTEK_SFTP_HOST не задан." >&2
        exit 2
    }
fi

if fstek_fleet_bool "$FSTEK_AUTO_DEPLOY"; then
    command -v rsync >/dev/null 2>&1 || {
        echo "Ошибка: для auto-deploy нужен rsync на controller." >&2
        exit 2
    }
fi

FLEET_BATCH_ID="${FLEET_BATCH_ID:-${FSTEK_BATCH_ID:-$(fstek_report_timestamp)}}"
FLEET_OUTPUT_ROOT="${FLEET_OUTPUT_ROOT:-$SCRIPT_DIR/output/fleet}"
FLEET_OUTPUT_DIR="$FLEET_OUTPUT_ROOT/$FLEET_BATCH_ID"
ROWS_DIR="$FLEET_OUTPUT_DIR/.rows"
mkdir -p "$FLEET_OUTPUT_DIR" "$ROWS_DIR" || exit 2

SUMMARY_CSV="$FLEET_OUTPUT_DIR/fleet-summary.csv"
SCAN_STARTED_AT="$(fstek_report_iso8601)"

{
    printf 'scan_started_at,batch_id,hostname,ip,ping_ok,ssh_ok,scan_status,overall_result,exit_code,log_file,json_file,error_message\n'
} >"$SUMMARY_CSV"

HOST_LINES=()
HOST_INDEX=0
for host_line in "${FSTEK_FLEET_HOSTS[@]}"; do
    case "$host_line" in
        ""|\#*) continue ;;
    esac
    HOST_INDEX=$((HOST_INDEX + 1))
    HOST_LINES+=("$host_line")
done

TOTAL_HOSTS=${#HOST_LINES[@]}
PIDS=()
ROW_FILES=()

echo ">>> Fleet batch: $FLEET_BATCH_ID"
echo ">>> Class: $FSTEK_FLEET_CLASS"
echo ">>> Output: $FLEET_OUTPUT_DIR"
echo ">>> Hosts: $TOTAL_HOSTS"
if [ "$FSTEK_FLEET_PARALLEL" -eq 0 ]; then
    echo ">>> Parallelism: all hosts at once"
else
    echo ">>> Parallelism: up to $FSTEK_FLEET_PARALLEL concurrent scans"
fi
if fstek_fleet_bool "$FSTEK_REMOTE_SUDO"; then
    echo ">>> Remote run: sudo -n ./check_all.sh"
else
    echo ">>> Remote run: ./check_all.sh (no sudo)"
fi
if fstek_fleet_bool "$FSTEK_AUTO_DEPLOY"; then
    echo ">>> Deploy: rsync $FSTEK_DEPLOY_SOURCE/ -> FSTEK_REMOTE_REPO on each host"
else
    echo ">>> Deploy: skipped (--no-deploy or FSTEK_AUTO_DEPLOY=false)"
fi
echo ">>> SSH auth policy: $FSTEK_SSH_AUTH (key first, then password env in auto mode)"
if fstek_fleet_bool "$FSTEK_SFTP_ENABLED"; then
    echo ">>> SFTP upload: ${FSTEK_SFTP_USER}@${FSTEK_SFTP_HOST}:${FSTEK_SFTP_REMOTE_DIR}/<batch-id>/"
else
    echo ">>> SFTP upload: disabled"
fi

host_idx=0
for host_line in "${HOST_LINES[@]}"; do
    host_idx=$((host_idx + 1))
    host_token="$(fstek_fleet_parse_host_line "$host_line" "$FSTEK_SSH_USER" "$FSTEK_SSH_PORT" "$FSTEK_REMOTE_REPO"; fstek_report_sanitize_token "$FLEET_HOSTNAME")"
    row_file="$ROWS_DIR/$(printf '%04d-%s.csv' "$host_idx" "$host_token")"
    ROW_FILES+=("$row_file")

    if [ "$FSTEK_FLEET_PARALLEL" -gt 0 ] && [ "${#PIDS[@]}" -ge "$FSTEK_FLEET_PARALLEL" ]; then
        wait "${PIDS[0]}"
        PIDS=("${PIDS[@]:1}")
    fi

    (
        fstek_fleet_process_host \
            "$host_line" \
            "$FLEET_BATCH_ID" \
            "$FLEET_OUTPUT_DIR" \
            "$SCAN_STARTED_AT" \
            "$FSTEK_SSH_USER" \
            "$FSTEK_SSH_PORT" \
            "$FSTEK_REMOTE_REPO" \
            "$FSTEK_SSH_KEY" \
            "$FSTEK_SSH_PASSWORD_ENV" \
            "$FSTEK_SSH_AUTH" \
            "$FSTEK_PING_TIMEOUT" \
            "$FSTEK_SSH_CONNECT_TIMEOUT" \
            "$FSTEK_FLEET_CLASS" \
            "$FSTEK_REMOTE_SUDO" \
            "$FSTEK_AUTO_DEPLOY" \
            "$FSTEK_DEPLOY_SOURCE" \
            "$row_file"
    ) &
    PIDS+=("$!")
done

for pid in "${PIDS[@]}"; do
    wait "$pid"
done

for row_file in "${ROW_FILES[@]}"; do
    [ -f "$row_file" ] && cat "$row_file" >>"$SUMMARY_CSV"
done
rm -rf "$ROWS_DIR"

REACHABLE_HOSTS=0
SCANNED_HOSTS=0
FAILED_HOSTS=0
for host_line in "${HOST_LINES[@]}"; do
    fstek_fleet_parse_host_line "$host_line" "$FSTEK_SSH_USER" "$FSTEK_SSH_PORT" "$FSTEK_REMOTE_REPO"
    host_dir="$FLEET_OUTPUT_DIR/$(fstek_report_sanitize_token "$FLEET_HOSTNAME")"
    if [ ! -f "$host_dir/.fleet-status" ]; then
        FAILED_HOSTS=$((FAILED_HOSTS + 1))
        continue
    fi
    # shellcheck disable=SC1090
    . "$host_dir/.fleet-status"
    if [ "$ssh_ok" = true ]; then
        REACHABLE_HOSTS=$((REACHABLE_HOSTS + 1))
    fi
    if [ "$scan_status" = "scanned" ]; then
        SCANNED_HOSTS=$((SCANNED_HOSTS + 1))
    fi
    if [ "$scan_status" != "scanned" ] || [ "$overall_result" != "OK" ]; then
        FAILED_HOSTS=$((FAILED_HOSTS + 1))
    fi
done

echo -e "\n>>> Fleet summary: $SUMMARY_CSV"
echo ">>> Hosts total/reachable/scanned/failed: $TOTAL_HOSTS/$REACHABLE_HOSTS/$SCANNED_HOSTS/$FAILED_HOSTS"

MEASURES_CSV="$FLEET_OUTPUT_DIR/fleet-measures.csv"
ROLLUPS_CSV="$FLEET_OUTPUT_DIR/fleet-measure-rollups.csv"
if fstek_aggregate_batch "$FLEET_OUTPUT_DIR" "$FLEET_BATCH_ID" "$MEASURES_CSV" "$ROLLUPS_CSV"; then
    echo ">>> Fleet measures: $MEASURES_CSV"
    echo ">>> Fleet rollups: $ROLLUPS_CSV"
else
    echo ">>> Fleet aggregate: failed to build CSV rollups" >&2
    FAILED_HOSTS=$((FAILED_HOSTS + 1))
fi

SFTP_UPLOAD_OK=true
if fstek_fleet_bool "$FSTEK_SFTP_ENABLED"; then
    if fstek_sftp_resolve_auth "$FSTEK_SFTP_KEY" "$FSTEK_SFTP_PASSWORD_ENV" "$FSTEK_SFTP_AUTH"; then
        if fstek_sftp_upload_batch "$FLEET_OUTPUT_DIR" "$FSTEK_SFTP_USER" "$FSTEK_SFTP_HOST" "$FSTEK_SFTP_PORT" "$FSTEK_SFTP_REMOTE_DIR" "$FSTEK_SFTP_KEY" "$FSTEK_SFTP_PASSWORD_ENV" "$FSTEK_SFTP_AUTH_MODE" "$FSTEK_SSH_CONNECT_TIMEOUT"; then
            echo ">>> SFTP upload: OK -> ${FSTEK_SFTP_HOST}:${FSTEK_SFTP_REMOTE_DIR}/${FLEET_BATCH_ID}/"
        else
            echo ">>> SFTP upload: FAIL" >&2
            SFTP_UPLOAD_OK=false
            FAILED_HOSTS=$((FAILED_HOSTS + 1))
        fi
    else
        echo ">>> SFTP upload: FAIL (no SFTP credentials)" >&2
        SFTP_UPLOAD_OK=false
        FAILED_HOSTS=$((FAILED_HOSTS + 1))
    fi
fi

if ! fstek_fleet_bool "$FSTEK_KEEP_LOCAL"; then
    rm -rf "$FLEET_OUTPUT_DIR"
    echo ">>> Local batch removed (FSTEK_KEEP_LOCAL=false)"
fi

if [ "$FAILED_HOSTS" -gt 0 ]; then
    exit 1
fi
exit 0
