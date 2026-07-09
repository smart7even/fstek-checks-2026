#!/usr/bin/env bash
# fstek_audit/checks/ZKU/ZKU_03.sh - migrated measure logic for ЗКУ.3.

MEASURE_CODE_DECL="ЗКУ.3"
MEASURE_TITLE="Антивирусная защита и обнаружение/предотвращение вторжений"

check_zku3() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_av_installed "$MEASURE_CODE.1"; check_av_updates "$MEASURE_CODE.2"; check_ids_installed "$MEASURE_CODE.3"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zku3
    finish_measure
}
