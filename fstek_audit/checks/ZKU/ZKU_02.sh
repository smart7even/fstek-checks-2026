#!/usr/bin/env bash
# fstek_audit/checks/ZKU/ZKU_02.sh - migrated measure logic for ЗКУ.2.

MEASURE_CODE_DECL="ЗКУ.2"
MEASURE_TITLE="Обеспечение целостности ПО конечного устройства"

check_zku2() { is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }; check_integrity_control "$MEASURE_CODE.1"; check_package_integrity_possible "$MEASURE_CODE.2"; check_skip "$MEASURE_CODE.3" "Эталонные контрольные суммы и утвержденный перечень ПО задаются оператором"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zku2
    finish_measure
}
