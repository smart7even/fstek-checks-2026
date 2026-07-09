#!/usr/bin/env bash
# fstek_audit/checks/ZOO/ZOO_01.sh - migrated measure logic for ЗОО.1.

MEASURE_CODE_DECL="ЗОО.1"
MEASURE_TITLE="Защита от атак, направленных на отказ в обслуживании"

check_zoo1() { check_syn_cookies "$MEASURE_CODE.1"; check_firewall_active "$MEASURE_CODE.2"; check_rate_limit "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zoo1
    finish_measure
}
