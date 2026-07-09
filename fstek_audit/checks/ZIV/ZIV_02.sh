#!/usr/bin/env bash
# fstek_audit/checks/ZIV/ZIV_02.sh - migrated measure logic for ЗИВ.2.

MEASURE_CODE_DECL="ЗИВ.2"
MEASURE_TITLE="Управление доступом IoT"

check_ziv_common() {
    has_iot_stack || { check_na "$MEASURE_CODE" "IoT-шлюз/платформа на данной Linux-системе не обнаружены"; return 1; }
    return 0
}

check_ziv2() { check_ziv_common || return; check_firewall_active "$MEASURE_CODE.1"; check_web_auth_or_acl "$MEASURE_CODE.2"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_ziv2
    finish_measure
}
