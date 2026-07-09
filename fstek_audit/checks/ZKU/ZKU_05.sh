#!/usr/bin/env bash
# fstek_audit/checks/ZKU/ZKU_05.sh - migrated measure logic for ЗКУ.5.

MEASURE_CODE_DECL="ЗКУ.5"
MEASURE_TITLE="Контроль и фильтрация трафика на конечном устройстве"

check_zku5() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_firewall_active "$MEASURE_CODE.1"; check_open_listeners "$MEASURE_CODE.2"; check_firewall_logging "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zku5
    finish_measure
}
