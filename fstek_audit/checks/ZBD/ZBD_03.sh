#!/usr/bin/env bash
# fstek_audit/checks/ZBD/ZBD_03.sh - migrated measure logic for ЗБД.3.

MEASURE_CODE_DECL="ЗБД.3"
MEASURE_TITLE="Защита пользовательских данных беспроводной сети"

check_zbd_common() {
    has_wireless_stack || { check_na "$MEASURE_CODE" "Беспроводная точка доступа/hostapd на системе не обнаружены"; return 1; }
    return 0
}

check_zbd3() { check_zbd_common || return; check_hostapd_secure "$MEASURE_CODE.1"; check_tls_config "$MEASURE_CODE.2"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zbd3
    finish_measure
}
