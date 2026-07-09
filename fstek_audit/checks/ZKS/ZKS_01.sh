#!/usr/bin/env bash
# fstek_audit/checks/ZKS/ZKS_01.sh - migrated measure logic for ЗКС.1.

MEASURE_CODE_DECL="ЗКС.1"
MEASURE_TITLE="Защита данных при передаче по каналам связи"

check_zks1() { check_vpn_or_crypto "$MEASURE_CODE.1"; check_tls_config "$MEASURE_CODE.2"; check_strong_tls "$MEASURE_CODE.3"; check_firewall_active "$MEASURE_CODE.4"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zks1
    finish_measure
}
