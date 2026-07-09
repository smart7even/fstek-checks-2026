#!/usr/bin/env bash
# fstek_audit/checks/ZIV/ZIV_03.sh - migrated measure logic for ЗИВ.3.

MEASURE_CODE_DECL="ЗИВ.3"
MEASURE_TITLE="Защита данных IoT"

check_ziv_common() {
    has_iot_stack || { check_na "$MEASURE_CODE" "IoT-шлюз/платформа на данной Linux-системе не обнаружены"; return 1; }
    return 0
}

check_ziv3() { check_ziv_common || return; check_tls_config "$MEASURE_CODE.1"; check_strong_tls "$MEASURE_CODE.2"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_ziv3
    finish_measure
}
