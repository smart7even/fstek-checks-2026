#!/usr/bin/env bash
# fstek_audit/checks/ZIV/ZIV_04.sh - migrated measure logic for ЗИВ.4.

MEASURE_CODE_DECL="ЗИВ.4"
MEASURE_TITLE="Контроль целостности IoT"

check_ziv_common() {
    has_iot_stack || { check_na "$MEASURE_CODE" "IoT-шлюз/платформа на данной Linux-системе не обнаружены"; return 1; }
    return 0
}

check_ziv4() { check_ziv_common || return; check_integrity_control "$MEASURE_CODE.1"; check_package_integrity_possible "$MEASURE_CODE.2"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_ziv4
    finish_measure
}
