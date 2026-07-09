#!/usr/bin/env bash
# fstek_audit/checks/ZKS/ZKS_04.sh - migrated measure logic for ЗКС.4.

MEASURE_CODE_DECL="ЗКС.4"
MEASURE_TITLE="Контекстная проверка исходящего трафика"

check_zks4() { check_dlp "$MEASURE_CODE.1"; check_egress_control "$MEASURE_CODE.2"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_dlp "$MEASURE_CODE.3"; else skip_enhancement "$MEASURE_CODE.3"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zks4
    finish_measure
}
