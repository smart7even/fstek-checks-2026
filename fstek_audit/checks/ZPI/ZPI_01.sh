#!/usr/bin/env bash
# fstek_audit/checks/ZPI/ZPI_01.sh - migrated measure logic for ЗПИ.1.

MEASURE_CODE_DECL="ЗПИ.1"
MEASURE_TITLE="Защита данных API"

check_zpi1() {
    has_api_stack || { check_na "$MEASURE_CODE" "API-шлюз/reverse proxy не обнаружен"; return; }
    check_tls_config "$MEASURE_CODE.1"
    check_strong_tls "$MEASURE_CODE.2"
    check_api_gateway "$MEASURE_CODE.3"
    check_web_logs "$MEASURE_CODE.4"
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zpi1
    finish_measure
}
