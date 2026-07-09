#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_rsb5.sh - РСБ.5 Реагирование на сбои регистрации

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода

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

if fstek_enhancement_enabled "РСБ.5" "1"; then
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
    skip_enhancement "РСБ.5.3"
fi

# Унифицированная итоговая строка
finish_legacy_measure "РСБ.5"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1