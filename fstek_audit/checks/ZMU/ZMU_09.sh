#!/usr/bin/env bash
# fstek_audit/checks/ZMU/ZMU_09.sh - migrated measure logic for ЗМУ.9.

MEASURE_CODE_DECL="ЗМУ.9"
MEASURE_TITLE="Регистрация, анализ и реагирование на события безопасности мобильных устройств"

check_zmu_common() {
    has_mdm_stack || { check_na "$MEASURE_CODE" "MDM/управление мобильными устройствами на данной Linux-системе не обнаружено"; return 1; }
    return 0
}

check_zmu9() { check_zmu_common || return; check_siem_forwarding "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Состав мобильных событий безопасности проверяется в MDM"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zmu9
    finish_measure
}
