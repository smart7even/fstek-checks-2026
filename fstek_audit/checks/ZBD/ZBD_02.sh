#!/usr/bin/env bash
# fstek_audit/checks/ZBD/ZBD_02.sh - migrated measure logic for ЗБД.2.

MEASURE_CODE_DECL="ЗБД.2"
MEASURE_TITLE="Управление доступом к беспроводной сети"

check_zbd_common() {
    has_wireless_stack || { check_na "$MEASURE_CODE" "Беспроводная точка доступа/hostapd на системе не обнаружены"; return 1; }
    return 0
}

check_zbd2() { check_zbd_common || return; check_wireless_acl "$MEASURE_CODE.1"; check_firewall_active "$MEASURE_CODE.2"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zbd2
    finish_measure
}
