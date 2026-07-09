#!/usr/bin/env bash
# fstek_audit/checks/ZBD/ZBD_01.sh - migrated measure logic for ЗБД.1.

MEASURE_CODE_DECL="ЗБД.1"
MEASURE_TITLE="Идентификация и аутентификация точек беспроводного доступа"

check_zbd_common() {
    has_wireless_stack || { check_na "$MEASURE_CODE" "Беспроводная точка доступа/hostapd на системе не обнаружены"; return 1; }
    return 0
}

check_zbd1() { check_zbd_common || return; check_hostapd_secure "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Уникальность учетных данных пользователей Wi-Fi проверяется по RADIUS/IdP"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zbd1
    finish_measure
}
