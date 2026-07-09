#!/usr/bin/env bash
# fstek_audit/checks/SOV/SOV_01.sh - migrated measure logic for СОВ.1.

MEASURE_CODE_DECL="СОВ.1"
MEASURE_TITLE="Обнаружение и предотвращение вторжений на периметре"

check_sov1() { check_ids_installed "$MEASURE_CODE.1"; check_ids_traffic_source "$MEASURE_CODE.2"; check_ids_rules_logs "$MEASURE_CODE.3"; check_fail2ban_or_reaction "$MEASURE_CODE.4"; check_ids_rule_updates "$MEASURE_CODE.5"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then check_ids_custom_rules "$MEASURE_CODE.6"; else skip_enhancement "$MEASURE_CODE.6"; fi; check_skip "$MEASURE_CODE.7" "Прикладной уровень, хранение фрагментов трафика, ретроанализ, песочница и репутационные базы относятся к усилениям 2-10 и проверяются по документации/конфигурации средств"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_sov1
    finish_measure
}
