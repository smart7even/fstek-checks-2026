#!/usr/bin/env bash
# fstek_audit/checks/ZOO/ZOO_03.sh - migrated measure logic for ЗОО.3.

MEASURE_CODE_DECL="ЗОО.3"
MEASURE_TITLE="Мониторинг состояния сервисов и интерфейсов"

check_zoo3() { check_monitoring_stack "$MEASURE_CODE.1"; check_open_listeners "$MEASURE_CODE.2"; check_siem_forwarding "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zoo3
    finish_measure
}
