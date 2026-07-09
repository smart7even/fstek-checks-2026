#!/usr/bin/env bash
# fstek_audit/checks/MSE/MSE_02.sh - migrated measure logic for МСЭ.2.

MEASURE_CODE_DECL="МСЭ.2"
MEASURE_TITLE="Организация демилитаризованной зоны"

check_mse2() { check_dmz "$MEASURE_CODE.1"; check_firewall_active "$MEASURE_CODE.2"; check_network_segmentation "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_mse2
    finish_measure
}
