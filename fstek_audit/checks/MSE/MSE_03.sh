#!/usr/bin/env bash
# fstek_audit/checks/MSE/MSE_03.sh - migrated measure logic for МСЭ.3.

MEASURE_CODE_DECL="МСЭ.3"
MEASURE_TITLE="Контроль сетевого доступа и фильтрация трафика"

check_mse3() { check_firewall_active "$MEASURE_CODE.1"; check_open_listeners "$MEASURE_CODE.2"; check_firewall_logging "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_mse3
    finish_measure
}
