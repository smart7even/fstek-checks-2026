#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_05.sh - migrated measure logic for ЗМУ.5.

MEASURE_CODE_DECL="ЗМУ.5"
MEASURE_TITLE="Антивирусная защита мобильных устройств"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu5() { check_zmu_common || return; check_av_installed "$MEASURE_CODE.1"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu5
    finish_measure
}
