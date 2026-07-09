#!/usr/bin/env bash
# fstek_audit/checks/ZOO/ZOO_06.sh - migrated measure logic for ЗОО.6.

MEASURE_CODE_DECL="ЗОО.6"
MEASURE_TITLE="Поддержка резерва пропускной способности и ресурсов"

check_zoo6() { check_skip "$MEASURE_CODE.1" "Двукратный резерв полосы и ресурсов определяется по методике оператора и не выводится достоверно из ОС"; if fstek_enhancement_enabled "$MEASURE_CODE" "1"; then if grep_any "xdp|dpdk|pf_ring|af_xdp" /etc /proc/cmdline 2>/dev/null; then check_pass "$MEASURE_CODE.2" "Обнаружены признаки высокопроизводительной обработки пакетов"; else check_fail "$MEASURE_CODE.2" "Не обнаружены признаки XDP/DPDK/PF_RING"; fi; else skip_enhancement "$MEASURE_CODE.2"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zoo6
    finish_measure
}
