#!/usr/bin/env bash
# fstek_audit/checks/ZVT/ZVT_04.sh - migrated measure logic for ЗВТ.4.

MEASURE_CODE_DECL="ЗВТ.4"
MEASURE_TITLE="Регистрация событий безопасности в веб-приложениях и реагирование на них"

check_zvt4() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_web_logs "$MEASURE_CODE.1"
    check_firewall_logging "$MEASURE_CODE.2"
    check_siem_forwarding "$MEASURE_CODE.3"
    check_fail2ban_or_reaction "$MEASURE_CODE.4"
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zvt4
    finish_measure
}
