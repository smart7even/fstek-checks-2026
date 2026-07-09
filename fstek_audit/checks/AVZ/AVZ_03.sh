#!/usr/bin/env bash
# fstek_audit/checks/AVZ/AVZ_03.sh - migrated measure logic for АВЗ.3.

MEASURE_CODE_DECL="АВЗ.3"
MEASURE_TITLE="Антивирусная проверка сетевого трафика"

check_avz3() { check_av_installed "$MEASURE_CODE.1"; if service_active squid c-icap havp privoxy || grep_any "icap|clamav|virus|av_" /etc/squid /etc/c-icap /etc/nginx /etc/haproxy 2>/dev/null; then check_pass "$MEASURE_CODE.2" "Обнаружена антивирусная проверка сетевого трафика/ICAP"; else check_fail "$MEASURE_CODE.2" "Не обнаружена антивирусная проверка сетевого трафика"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_avz3
    finish_measure
}
