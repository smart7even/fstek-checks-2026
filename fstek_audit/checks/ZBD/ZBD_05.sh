#!/usr/bin/env bash
# fstek_audit/checks/ZBD/ZBD_05.sh - migrated measure logic for ЗБД.5.

MEASURE_CODE_DECL="ЗБД.5"
MEASURE_TITLE="Ограничение уровней сигналов беспроводного доступа"

check_zbd_common() {
    has_wireless_stack || { check_na "$MEASURE_CODE" "Беспроводная точка доступа/hostapd на системе не обнаружены"; return 1; }
    return 0
}

check_zbd5() { check_zbd_common || return; if grep_any "tx_power|country_code|ieee80211d" /etc/hostapd /etc/NetworkManager/system-connections 2>/dev/null; then check_info "$MEASURE_CODE.I1" "Обнаружены параметры tx_power/country_code/ieee80211d, но радиопокрытие и уровень сигнала требуют измерений"; else check_skip "$MEASURE_CODE.1" "Ограничение уровня радиосигнала требует измерений покрытия или подтвержденной конфигурации точки доступа"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zbd5
    finish_measure
}
