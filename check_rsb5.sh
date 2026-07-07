#!/bin/bash
# check_rsb5.sh - РСБ.5 Реагирование на сбои регистрации

WITH_ENHANCEMENTS=false
[[ "$1" == "-e" || "$1" == "--with-enhancements" ]] && WITH_ENHANCEMENTS=true

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

AUDIT_CONF="/etc/audit/auditd.conf"

# РСБ.5.1 – Реакция на переполнение диска (auditd)
if [ -f "$AUDIT_CONF" ]; then
    DISK_ACTION=$(grep -E "^disk_full_action" "$AUDIT_CONF" | awk -F'=' '{print $2}' | tr -d ' ')
    if [[ "$DISK_ACTION" == "syslog" || "$DISK_ACTION" == "single" || "$DISK_ACTION" == "halt" ]]; then
        check_pass "РСБ.5.1" "auditd: disk_full_action = $DISK_ACTION (настроено реагирование)"
    elif [[ "$DISK_ACTION" == "ignore" || -z "$DISK_ACTION" ]]; then
        check_fail "РСБ.5.1" "auditd: disk_full_action = ignore (игнорирование переполнения недопустимо)"
    else
        check_fail "РСБ.5.1" "auditd: действие при переполнении диска не настроено"
    fi
else
    check_skip "РСБ.5.1" "Файл auditd.conf не найден (возможно, используется journald)"
fi

# РСБ.5.2 – Ограничения journald
JOURNAL_CONF="/etc/systemd/journald.conf"
if [ -f "$JOURNAL_CONF" ]; then
    if grep -qE "^SystemMaxUse=|^SystemKeepFree=" "$JOURNAL_CONF"; then
        check_pass "РСБ.5.2" "journald: Ограничение размера журналов настроено"
    else 
        check_fail "РСБ.5.2" "journald: Ограничение размера журналов не задано"
    fi
else 
    check_fail "РСБ.5.2" "Файл journald.conf не найден"
fi

if $WITH_ENHANCEMENTS; then
    # РСБ.5.3 (Усиление 2) – Остановка системы (Fail-secure)
    if [ -f "$AUDIT_CONF" ]; then
        SPACE_ACTION=$(grep -E "^admin_space_left_action" "$AUDIT_CONF" | awk -F'=' '{print $2}' | tr -d ' ')
        if [[ "$SPACE_ACTION" == "halt" || "$SPACE_ACTION" == "single" ]]; then
            check_pass "РСБ.5.3" "auditd: admin_space_left_action = $SPACE_ACTION (запрет обработки при сбое)"
        else
            check_fail "РСБ.5.3" "auditd: Требуется halt/single для admin_space_left_action (текущий: $SPACE_ACTION)"
        fi
    else 
        check_skip "РСБ.5.3" "auditd не используется"
    fi
else
    # Унифицированный вывод для отключенных усилений
    echo "[РСБ.5.3] SKIP – проверка усилений отключена"
    ((SKIP_COUNT++))
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ РСБ.5: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1