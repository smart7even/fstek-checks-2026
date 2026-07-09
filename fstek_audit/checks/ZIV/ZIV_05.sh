#!/usr/bin/env bash
# fstek_audit/checks/ZIV/ZIV_05.sh - migrated measure logic for ЗИВ.5.

MEASURE_CODE_DECL="ЗИВ.5"
MEASURE_TITLE="Регистрация, анализ и реагирование на события безопасности IoT"

check_ziv_common() {
    has_iot_stack || { check_na "$MEASURE_CODE" "IoT-шлюз/платформа на данной Linux-системе не обнаружены"; return 1; }
    return 0
}

check_ziv5() { check_ziv_common || return; check_web_logs "$MEASURE_CODE.1"; check_siem_forwarding "$MEASURE_CODE.2"; check_fail2ban_or_reaction "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_ziv5
    finish_measure
}
