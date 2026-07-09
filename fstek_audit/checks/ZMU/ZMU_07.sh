#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_07.sh - migrated measure logic for ЗМУ.7.

MEASURE_CODE_DECL="ЗМУ.7"
MEASURE_TITLE="Ограничение и контроль функциональности мобильных устройств"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu7() { check_zmu_common || return; check_skip "$MEASURE_CODE.1" "Ограничения камер, Bluetooth, NFC, USB и иных функций проверяются в MDM"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu7
    finish_measure
}
