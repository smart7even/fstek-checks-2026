#!/bin/bash
# core/report.sh - local report artifacts (log + JSON summary).

FSTEK_OUTPUT_DIR=""
FSTEK_BATCH_ID=""
FSTEK_REPORT_LOG=""
FSTEK_REPORT_JSON=""
FSTEK_REPORT_STARTED_AT=""
FSTEK_REPORT_FINISHED_AT=""
FSTEK_REPORT_DURATION_SEC=0

fstek_json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

fstek_json_string() {
    printf '"%s"' "$(fstek_json_escape "$1")"
}

fstek_report_sanitize_token() {
    local value="$1"
    value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
    value="$(printf '%s' "$value" | sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//')"
    [ -n "$value" ] || value="host"
    printf '%s' "$value"
}

fstek_host_primary_ip() {
    local ip=""
    if command -v hostname >/dev/null 2>&1; then
        ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    fi
    if [ -z "$ip" ] && command -v ip >/dev/null 2>&1; then
        ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
    fi
    if [ -z "$ip" ]; then
        ip="$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" {print $2; exit}')"
    fi
    printf '%s' "${ip:-unknown}"
}

fstek_report_timestamp() {
    date +%Y%m%d-%H%M%S
}

fstek_report_default_batch_id() {
    local stamp hostname
    stamp="$(fstek_report_timestamp)"
    hostname="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
    fstek_report_file_basename "$hostname" "$stamp"
}

fstek_report_iso8601() {
    date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z
}

fstek_report_file_basename() {
    local hostname="$1" stamp="$2"
    printf '%s-%s' "$(fstek_report_sanitize_token "$hostname")" "$stamp"
}

fstek_report_prepare_output() {
    local output_dir="$1" batch_id="${2:-}" stamp hostname basename target_dir

    [ -n "$output_dir" ] || {
        fstek_log_error "Не задан каталог для отчёта (--output-dir)."
        return 1
    }

    stamp="$(fstek_report_timestamp)"
    hostname="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
    basename="$(fstek_report_file_basename "$hostname" "$stamp")"

    if [ -n "$batch_id" ]; then
        target_dir="$output_dir/$batch_id"
    else
        target_dir="$output_dir"
    fi

    mkdir -p "$target_dir" || {
        fstek_log_error "Не удалось создать каталог отчёта: $target_dir"
        return 1
    }

    FSTEK_OUTPUT_DIR="$target_dir"
    FSTEK_BATCH_ID="$batch_id"
    FSTEK_REPORT_LOG="$target_dir/${basename}.log"
    FSTEK_REPORT_JSON="$target_dir/${basename}.json"
    FSTEK_REPORT_STARTED_AT="$(fstek_report_iso8601)"
    FSTEK_REPORT_DURATION_SEC=0

    fstek_log_info "Отчёт: log=$FSTEK_REPORT_LOG json=$FSTEK_REPORT_JSON"
}

fstek_report_mark_finished() {
    local started finished
    FSTEK_REPORT_FINISHED_AT="$(fstek_report_iso8601)"
    started="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$FSTEK_REPORT_STARTED_AT" +%s 2>/dev/null || true)"
    finished="$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$FSTEK_REPORT_FINISHED_AT" +%s 2>/dev/null || true)"
    if [ -n "$started" ] && [ -n "$finished" ]; then
        FSTEK_REPORT_DURATION_SEC=$((finished - started))
        return 0
    fi
    started="$(date -d "$FSTEK_REPORT_STARTED_AT" +%s 2>/dev/null || true)"
    finished="$(date -d "$FSTEK_REPORT_FINISHED_AT" +%s 2>/dev/null || true)"
    if [ -n "$started" ] && [ -n "$finished" ]; then
        FSTEK_REPORT_DURATION_SEC=$((finished - started))
    fi
}

fstek_report_write_summary_json() {
    local exit_code="$1" overall_result="$2"
    local hostname ip class_mode security_class

    [ -n "$FSTEK_REPORT_JSON" ] || return 0

    fstek_report_mark_finished
    hostname="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo unknown)"
    ip="$(fstek_host_primary_ip)"

    if [ -n "$FSTEK_SECURITY_CLASS" ]; then
        security_class="$FSTEK_SECURITY_CLASS"
        class_mode="class"
    elif $WITH_ENHANCEMENTS; then
        security_class=""
        class_mode="all_enhancements"
    else
        security_class=""
        class_mode="base"
    fi

    cat >"$FSTEK_REPORT_JSON" <<EOF
{
  "schema": "fstek-audit-summary/v1",
  "batch_id": $(fstek_json_string "${FSTEK_BATCH_ID:-}"),
  "hostname": $(fstek_json_string "$hostname"),
  "primary_ip": $(fstek_json_string "$ip"),
  "os_label": $(fstek_json_string "${OS_LABEL:-Unknown}"),
  "os_type": $(fstek_json_string "${OS_TYPE:-generic}"),
  "os_supported": $( [ "${OS_SUPPORTED:-false}" = true ] && printf 'true' || printf 'false' ),
  "class_mode": $(fstek_json_string "$class_mode"),
  "security_class": $(fstek_json_string "$security_class"),
  "started_at": $(fstek_json_string "$FSTEK_REPORT_STARTED_AT"),
  "finished_at": $(fstek_json_string "$FSTEK_REPORT_FINISHED_AT"),
  "duration_sec": $FSTEK_REPORT_DURATION_SEC,
  "overall_result": $(fstek_json_string "$overall_result"),
  "exit_code": $exit_code,
  "selected_measures": ${SELECTED_COUNT:-0},
  "checks_total": ${TOTAL:-0},
  "pass": ${TOTAL_PASS:-0},
  "pass_high": ${TOTAL_PASS_HIGH:-0},
  "pass_medium": ${TOTAL_PASS_MEDIUM:-0},
  "fail": ${TOTAL_FAIL:-0},
  "skip": ${TOTAL_SKIP:-0},
  "info": ${TOTAL_INFO:-0},
  "na": ${TOTAL_NA:-0},
  "fail_percent": ${FAIL_PERCENT:-0},
  "log_file": $(fstek_json_string "$FSTEK_REPORT_LOG"),
  "json_file": $(fstek_json_string "$FSTEK_REPORT_JSON")
}
EOF
}
