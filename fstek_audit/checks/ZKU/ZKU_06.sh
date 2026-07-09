#!/usr/bin/env bash
# fstek_audit/checks/ZKU/ZKU_06.sh - migrated measure logic for ЗКУ.6.

MEASURE_CODE_DECL="ЗКУ.6"
MEASURE_TITLE="Анализ и реагирование на события безопасности"

check_zku6() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_auditd "$MEASURE_CODE.1"; check_siem_forwarding "$MEASURE_CODE.2"; check_fail2ban_or_reaction "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zku6
    finish_measure
}
