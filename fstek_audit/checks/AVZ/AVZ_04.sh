#!/usr/bin/env bash
# fstek_audit/checks/AVZ/AVZ_04.sh - migrated measure logic for АВЗ.4.

MEASURE_CODE_DECL="АВЗ.4"
MEASURE_TITLE="Замкнутая среда предварительного анализа файлов"

check_avz4() { if service_active cuckoo cape sandbox detonator || file_any /opt/cuckoo /opt/cape /etc/cuckoo; then check_pass "$MEASURE_CODE.1" "Обнаружена среда предварительного анализа файлов"; else check_skip "$MEASURE_CODE.1" "Замкнутая среда предварительного анализа файлов обычно реализуется отдельной песочницей/процессом"; fi; }

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_avz4
    finish_measure
}
