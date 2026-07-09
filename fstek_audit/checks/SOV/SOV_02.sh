#!/usr/bin/env bash
# fstek_audit/checks/SOV/SOV_02.sh - migrated measure logic for СОВ.2.

MEASURE_CODE_DECL="СОВ.2"
MEASURE_TITLE="Обнаружение и предотвращение вторжений в сегментах"

check_sov2() { check_ids_installed "$MEASURE_CODE.1"; check_network_segmentation "$MEASURE_CODE.2"; check_ids_rules_logs "$MEASURE_CODE.3"; check_ids_rule_updates "$MEASURE_CODE.4"; check_fail2ban_or_reaction "$MEASURE_CODE.5"; check_skip "$MEASURE_CODE.6" "Централизованное администрирование IDS в сегментах подтверждается эксплуатационной документацией и консолью управления"; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_sov2
    finish_measure
}
