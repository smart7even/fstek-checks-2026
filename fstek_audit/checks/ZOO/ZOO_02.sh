#!/usr/bin/env bash
# fstek_audit/checks/ZOO/ZOO_02.sh - migrated measure logic for ЗОО.2.

MEASURE_CODE_DECL="ЗОО.2"
MEASURE_TITLE="Контроль и фильтрация входящего трафика"

check_zoo2() { check_firewall_active "$MEASURE_CODE.1"; check_rate_limit "$MEASURE_CODE.2"; check_waf "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zoo2
    finish_measure
}
