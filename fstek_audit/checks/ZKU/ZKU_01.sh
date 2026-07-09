#!/usr/bin/env bash
# fstek_audit/checks/ZKU/ZKU_01.sh - migrated measure logic for ЗКУ.1.

MEASURE_CODE_DECL="ЗКУ.1"
MEASURE_TITLE="Управление доступом к конечным устройствам"

check_zku1() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_pam_auth "$MEASURE_CODE.1"; check_ssh_hardening "$MEASURE_CODE.2"; check_sudo_restricted "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zku1
    finish_measure
}
