#!/usr/bin/env bash
# fstek_audit/checks/ZVT/ZVT_02.sh - migrated measure logic for ЗВТ.2.

MEASURE_CODE_DECL="ЗВТ.2"
MEASURE_TITLE="Управление доступом пользователей"

check_zvt2() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_web_auth_or_acl "$MEASURE_CODE.1"
    check_fail2ban_or_reaction "$MEASURE_CODE.2"
    check_rate_limit "$MEASURE_CODE.3"
    check_skip "$MEASURE_CODE.4" "Проверка прав при каждом запросе определяется логикой приложения и требует анализа кода/настроек приложения"
    check_skip "$MEASURE_CODE.5" "Исключение client-side-only аутентификации требует анализа приложения"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_skip "$MEASURE_CODE.6" "MFA привилегированных веб-пользователей проверяется в IdP/приложении"; else skip_enhancement "$MEASURE_CODE.6"; fi
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zvt2
    finish_measure
}
