#!/usr/bin/env bash
# fstek_audit/checks/AVZ/AVZ_02.sh - migrated measure logic for АВЗ.2.

MEASURE_CODE_DECL="АВЗ.2"
MEASURE_TITLE="Антивирусная защита электронной почты"

check_avz2() { has_mail_stack || { check_na "$MEASURE_CODE" "Почтовый сервер не обнаружен"; return; }; check_av_installed "$MEASURE_CODE.1"; if grep_any "clamav|clamd|amavis|rspamd.*antivirus|milter.*(clam|av|virus)|virus" /etc/postfix /etc/exim /etc/dovecot /etc/amavis /etc/rspamd 2>/dev/null; then check_pass "$MEASURE_CODE.2" "Обнаружена интеграция почты с антивирусной проверкой"; else check_fail "$MEASURE_CODE.2" "Не обнаружена интеграция почты с антивирусной проверкой"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_avz2
    finish_measure
}
