#!/usr/bin/env bash
# fstek_audit/checks/ZKS/ZKS_02.sh - migrated measure logic for ЗКС.2.

MEASURE_CODE_DECL="ЗКС.2"
MEASURE_TITLE="Контроль атрибутов безопасности при сетевом взаимодействии"

check_zks2() { check_firewall_active "$MEASURE_CODE.1"; check_firewall_logging "$MEASURE_CODE.2"; check_skip "$MEASURE_CODE.3" "Перечень атрибутов безопасности субъектов задается оператором и проверяется по правилам/документации"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zks2
    finish_measure
}
