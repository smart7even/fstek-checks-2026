#!/usr/bin/env bash
# fstek_audit/checks/ZBD/ZBD_06.sh - migrated measure logic for ЗБД.6.

MEASURE_CODE_DECL="ЗБД.6"
MEASURE_TITLE="Регистрация, анализ и реагирование на события беспроводного доступа"

check_zbd_common() {
    has_wireless_stack || { check_na "$MEASURE_CODE" "Беспроводная точка доступа/hostapd на системе не обнаружены"; return 1; }
    return 0
}

check_zbd6() { check_zbd_common || return; check_wireless_logs "$MEASURE_CODE.1"; check_siem_forwarding "$MEASURE_CODE.2"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zbd6
    finish_measure
}
