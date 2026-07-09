#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_01.sh - migrated measure logic for ЗМУ.1.

MEASURE_CODE_DECL="ЗМУ.1"
MEASURE_TITLE="Идентификация и аутентификация пользователей мобильных устройств"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu1() { check_zmu_common || return; check_pam_auth "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Параметры мобильной аутентификации проверяются в MDM"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu1
    finish_measure
}
