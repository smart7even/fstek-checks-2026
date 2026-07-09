#!/usr/bin/env bash
# fstek_audit/checks/ZPI/ZPI_03.sh - migrated measure logic for ЗПИ.3.

MEASURE_CODE_DECL="ЗПИ.3"
MEASURE_TITLE="Проверка на соответствие спецификации API"

check_zpi3() {
    has_api_stack || { check_na "$MEASURE_CODE" "API-шлюз/reverse proxy не обнаружен"; return; }
    check_openapi_spec "$MEASURE_CODE.1"
    check_api_schema_validation "$MEASURE_CODE.2"
    check_waf "$MEASURE_CODE.3"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_rate_limit "$MEASURE_CODE.4"; else skip_enhancement "$MEASURE_CODE.4"; fi
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zpi3
    finish_measure
}
