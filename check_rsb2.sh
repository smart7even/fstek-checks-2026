#!/bin/bash
# check_rsb2.sh - РСБ.2 Анализ событий и реагирование

WITH_ENHANCEMENTS=false
[[ "$1" == "-e" || "$1" == "--with-enhancements" ]] && WITH_ENHANCEMENTS=true

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

# РСБ.2.1 – Агенты анализа (HIDS/SIEM)
AGENT_FOUND=false
AGENT_NAME=""
for agent in wazuh-agent ossec-hids-agent splunkd filebeat logstash; do
    if systemctl is-active --quiet "$agent" 2>/dev/null; then 
        AGENT_FOUND=true
        AGENT_NAME="$agent"
        break 
    fi
done

if $AGENT_FOUND; then
    check_pass "РСБ.2.1" "Обнаружен агент централизованного анализа/SIEM ($AGENT_NAME)"
else
    check_skip "РСБ.2.1" "Агенты HIDS/SIEM не найдены (возможен ручной анализ или сетевой SIEM)"
fi

# РСБ.2.2 – Организационная мера
check_skip "РСБ.2.2" "Наличие регламента периодического анализа (Требует ручной проверки)"

if $WITH_ENHANCEMENTS; then
    # РСБ.2.3 (Усиление 1, 2) – Корреляция и IDS
    if systemctl is-active --quiet suricata 2>/dev/null || \
       systemctl is-active --quiet snort 2>/dev/null || \
       [ -d /var/ossec/etc/rules ] || \
       [ -d /etc/filebeat ]; then
        check_pass "РСБ.2.3" "Обнаружены средства корреляции, IDS или настроенные правила SIEM"
    else
        check_fail "РСБ.2.3" "Средства автоматической корреляции и IDS не обнаружены"
    fi
else
    # Унифицированный вывод для отключенных усилений (как в check_iaf1.sh)
    echo "[РСБ.2.3] SKIP – проверка усилений отключена"
    ((SKIP_COUNT++))
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ РСБ.2: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1