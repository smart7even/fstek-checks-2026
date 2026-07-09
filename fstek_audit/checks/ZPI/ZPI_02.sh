#!/usr/bin/env bash
# fstek_audit/checks/ZPI/ZPI_02.sh - migrated measure logic for ЗПИ.2.

MEASURE_CODE_DECL="ЗПИ.2"
MEASURE_TITLE="Управление доступом пользователей и приложений API"

check_zpi2() {
    has_api_stack || { check_na "$MEASURE_CODE" "API-шлюз/reverse proxy не обнаружен"; return; }
    check_web_auth_or_acl "$MEASURE_CODE.1"
    check_rate_limit "$MEASURE_CODE.2"
    check_skip "$MEASURE_CODE.3" "Разграничение прав приложений и пользователей требует проверки IdP/API-приложения"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_skip "$MEASURE_CODE.4" "MFA/API access policy проверяется в IdP/API-шлюзе"; else skip_enhancement "$MEASURE_CODE.4"; fi
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zpi2
    finish_measure
}
