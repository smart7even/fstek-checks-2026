#!/usr/bin/env bash
# fstek_audit/checks/ZVT/ZVT_03.sh - migrated measure logic for ЗВТ.3.

MEASURE_CODE_DECL="ЗВТ.3"
MEASURE_TITLE="Контроль и фильтрация трафика веб-приложений"

check_zvt3() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_waf "$MEASURE_CODE.1"
    check_rate_limit "$MEASURE_CODE.2"
    check_skip "$MEASURE_CODE.3" "Полнота сигнатур SQL/XSS/команд и проверка чувствительных данных в запросах требует анализа WAF-политик"
    if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then
        check_waf "$MEASURE_CODE.4"
    else
        skip_enhancement "$MEASURE_CODE.4"
    fi
    if fstek_enhancement_enabled "$MEASURE_CODE" "2"; then
        check_api_schema_validation "$MEASURE_CODE.5"
    else
        skip_enhancement "$MEASURE_CODE.5"
    fi
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zvt3
    finish_measure
}
