#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_08.sh - migrated measure logic for ЗМУ.8.

MEASURE_CODE_DECL="ЗМУ.8"
MEASURE_TITLE="Определение и контроль геопозиции мобильных устройств"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu8() { check_zmu_common || return; check_skip "$MEASURE_CODE.1" "Геопозиция мобильных устройств проверяется в MDM и требует согласованных политик"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu8
    finish_measure
}
