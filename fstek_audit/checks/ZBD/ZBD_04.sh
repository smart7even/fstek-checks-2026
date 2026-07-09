#!/usr/bin/env bash
# fstek_audit/checks/ZBD/ZBD_04.sh - migrated measure logic for ЗБД.4.

MEASURE_CODE_DECL="ЗБД.4"
MEASURE_TITLE="Контроль целостности точек беспроводного доступа"

check_zbd_common() {
    has_wireless_stack || { check_na "$MEASURE_CODE" "Беспроводная точка доступа/hostapd на системе не обнаружены"; return 1; }
    return 0
}

check_zbd4() { check_zbd_common || return; check_integrity_control "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Целостность прошивки точки доступа требует проверки средствами производителя"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zbd4
    finish_measure
}
