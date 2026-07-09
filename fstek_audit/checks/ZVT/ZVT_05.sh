#!/usr/bin/env bash
# fstek_audit/checks/ZVT/ZVT_05.sh - migrated measure logic for ЗВТ.5.

MEASURE_CODE_DECL="ЗВТ.5"
MEASURE_TITLE="Проверка файлов, передаваемых веб-приложениями, на вредоносное ПО"

check_zvt5() {
    has_web_stack || { check_na "$MEASURE_CODE" "Веб-сервер/веб-приложение не обнаружены"; return; }
    check_av_installed "$MEASURE_CODE.1"
    if grep_any "clamd|clamav|icap|virus|antivirus" /etc/nginx /etc/apache2 /etc/httpd /etc/squid /etc/c-icap 2>/dev/null; then
        check_pass "$MEASURE_CODE.2" "Обнаружена интеграция веб/прокси с антивирусной проверкой"
    else
        check_fail "$MEASURE_CODE.2" "Не обнаружена интеграция веб-приложения с антивирусной проверкой файлов"
    fi
    check_av_updates "$MEASURE_CODE.3"
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zvt5
    finish_measure
}
