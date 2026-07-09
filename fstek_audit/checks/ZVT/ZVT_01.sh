#!/usr/bin/env bash
# fstek_audit/checks/ZVT/ZVT_01.sh - migrated measure logic for ЗВТ.1.

MEASURE_CODE_DECL="ЗВТ.1"
MEASURE_TITLE="Защита пользовательских данных"

check_zvt1() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_tls_config "$MEASURE_CODE.1"
    check_web_auth_or_acl "$MEASURE_CODE.2"
    check_firewall_active "$MEASURE_CODE.3"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1" "2" "3" "4"; then
        check_no_cache_headers "$MEASURE_CODE.4"
        check_skip "$MEASURE_CODE.5" "Автозаполнение HTML-форм достоверно проверяется только по исходному коду веб-приложения"
        check_web_security_headers "$MEASURE_CODE.6"
        check_clickjacking_headers "$MEASURE_CODE.7"
    else
        skip_enhancement "$MEASURE_CODE.4"; skip_enhancement "$MEASURE_CODE.5"; skip_enhancement "$MEASURE_CODE.6"; skip_enhancement "$MEASURE_CODE.7"
    fi
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zvt1
    finish_measure
}
