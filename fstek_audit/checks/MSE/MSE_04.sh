#!/usr/bin/env bash
# fstek_audit/checks/MSE/MSE_04.sh - migrated measure logic for МСЭ.4.

MEASURE_CODE_DECL="МСЭ.4"
MEASURE_TITLE="Маскирование системы"

check_mse4() { check_nat_masking "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Полнота маскирования топологии проверяется сетевой схемой и внешним сканированием"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_mse4
    finish_measure
}
