#!/usr/bin/env bash
# fstek_audit/checks/ZOO/ZOO_04.sh - migrated measure logic for ЗОО.4.

MEASURE_CODE_DECL="ЗОО.4"
MEASURE_TITLE="Балансировка нагрузки"

check_zoo4() { check_load_balancing "$MEASURE_CODE.1"; check_skip "$MEASURE_CODE.2" "Независимость физических каналов и провайдеров проверяется по сетевой документации"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_load_balancing "$MEASURE_CODE.3"; else skip_enhancement "$MEASURE_CODE.3"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zoo4
    finish_measure
}
