#!/usr/bin/env bash
# fstek_audit/checks/MSE/MSE_01.sh - migrated measure logic for МСЭ.1.

MEASURE_CODE_DECL="МСЭ.1"
MEASURE_TITLE="Сегментация сети"

check_mse1() { check_network_segmentation "$MEASURE_CODE.1"; check_firewall_active "$MEASURE_CODE.2"; check_firewall_logging "$MEASURE_CODE.3"; check_segmentation_documentation "$MEASURE_CODE.4"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_microsegmentation "$MEASURE_CODE.5"; else skip_enhancement "$MEASURE_CODE.5"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_mse1
    finish_measure
}
