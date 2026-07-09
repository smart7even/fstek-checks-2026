#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_04.sh - migrated measure logic for ЗМУ.4.

MEASURE_CODE_DECL="ЗМУ.4"
MEASURE_TITLE="Защита данных мобильных устройств"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu4() { check_zmu_common || return; check_tls_config "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Шифрование данных на мобильном устройстве проверяется в MDM"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu4
    finish_measure
}
