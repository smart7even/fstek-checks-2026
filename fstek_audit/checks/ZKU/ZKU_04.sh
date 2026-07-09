#!/usr/bin/env bash
# fstek_audit/checks/ZKU/ZKU_04.sh - migrated measure logic for ЗКУ.4.

MEASURE_CODE_DECL="ЗКУ.4"
MEASURE_TITLE="Мониторинг процессов и состояния устройства"

check_zku4() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_process_monitoring "$MEASURE_CODE.1"; check_open_listeners "$MEASURE_CODE.2"; check_monitoring_stack "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zku4
    finish_measure
}
