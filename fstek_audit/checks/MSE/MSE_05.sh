#!/usr/bin/env bash
# fstek_audit/checks/MSE/MSE_05.sh - migrated measure logic for МСЭ.5.

MEASURE_CODE_DECL="МСЭ.5"
MEASURE_TITLE="Создание ложных систем"

check_mse5() { check_honeypot "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Сценарии эксплуатации ложных систем определяются оператором"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_mse5
    finish_measure
}
