#!/usr/bin/env bash
# fstek_audit/checks/ZKS/ZKS_03.sh - migrated measure logic for ЗКС.3.

MEASURE_CODE_DECL="ЗКС.3"
MEASURE_TITLE="Контроль доступа к внешним ресурсам"

check_zks3() { check_egress_control "$MEASURE_CODE.1"; check_firewall_logging "$MEASURE_CODE.2"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_proxy_categories "$MEASURE_CODE.3"; else skip_enhancement "$MEASURE_CODE.3"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zks3
    finish_measure
}
