#!/usr/bin/env bash
# fstek_audit/checks/AVZ/AVZ_01.sh - migrated measure logic for АВЗ.1.

MEASURE_CODE_DECL="АВЗ.1"
MEASURE_TITLE="Антивирусная защита устройств"

check_avz1() { check_av_installed "$MEASURE_CODE.1"; check_av_updates "$MEASURE_CODE.2"; check_av_scheduled_scan "$MEASURE_CODE.3"; check_av_on_access "$MEASURE_CODE.4"; check_skip "$MEASURE_CODE.5" "Перечень устройств, порядок реагирования и проверка после обновления баз подтверждаются эксплуатационной документацией"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_avz1
    finish_measure
}
