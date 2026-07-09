#!/usr/bin/env bash
# fstek_audit/checks/ZOO/ZOO_05.sh - migrated measure logic for ЗОО.5.

MEASURE_CODE_DECL="ЗОО.5"
MEASURE_TITLE="Ограничение нагрузки"

check_zoo5() { check_rate_limit "$MEASURE_CODE.1"; check_dns_rate_limit "$MEASURE_CODE.2"; check_monitoring_stack "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zoo5
    finish_measure
}
