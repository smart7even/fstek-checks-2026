#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_03.sh - migrated measure logic for ЗМУ.3.

MEASURE_CODE_DECL="ЗМУ.3"
MEASURE_TITLE="Обеспечение целостности мобильных устройств"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu3() { check_zmu_common || return; check_integrity_control "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Контроль root/jailbreak и целостности мобильной ОС проверяется средствами MDM"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu3
    finish_measure
}
