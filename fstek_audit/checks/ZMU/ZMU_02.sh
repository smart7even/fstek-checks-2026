#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_02.sh - migrated measure logic for ЗМУ.2.

MEASURE_CODE_DECL="ЗМУ.2"
MEASURE_TITLE="Управление доступом пользователей к мобильным устройствам"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu2() { check_zmu_common || return; check_web_auth_or_acl "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Политики доступа мобильных устройств проверяются в MDM"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu2
    finish_measure
}
