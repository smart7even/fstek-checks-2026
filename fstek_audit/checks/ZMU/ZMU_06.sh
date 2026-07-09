#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_06.sh - migrated measure logic for ЗМУ.6.

MEASURE_CODE_DECL="ЗМУ.6"
MEASURE_TITLE="Контроль приложений мобильных устройств"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu6() { check_zmu_common || return; check_skip "$MEASURE_CODE.1" "Белые/черные списки мобильных приложений проверяются в MDM"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu6
    finish_measure
}
