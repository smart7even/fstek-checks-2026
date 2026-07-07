#!/bin/bash
# check_rsb1.sh - РСБ.1 Определение событий безопасности

WITH_ENH=false; [[ "$1" == "-e" || "$1" == "--with-enhancements" ]] && WITH_ENH=true
FAIL_COUNT=0; SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2"; ((SKIP_COUNT++)); }

OS="generic"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_MATCH="$(printf '%s' "${ID:-} ${ID_LIKE:-} ${NAME:-} ${PRETTY_NAME:-}" | tr '[:upper:]' '[:lower:]')"
    [[ "$OS_MATCH" == *"astra"* || "$OS_MATCH" == *"alse"* ]] && OS="astra"
fi

# РСБ.1.1 – Служба аудита
if [ "$OS" == "astra" ]; then
    if systemctl is-active --quiet parsecd 2>/dev/null || systemctl is-active --quiet auditd 2>/dev/null; then
        check_pass "РСБ.1.1" "Служба аудита (PARSEC/auditd) активна"
    else 
        check_fail "РСБ.1.1" "Служба аудита не активна"
    fi
else
    if systemctl is-active --quiet auditd 2>/dev/null; then 
        check_pass "РСБ.1.1" "Служба auditd активна"
    else 
        check_fail "РСБ.1.1" "Служба auditd не активна"
    fi
fi

# РСБ.1.2 – Состав событий (USB, запуск программ, входы/выходы)
RULES=$(auditctl -l 2>/dev/null; cat /etc/audit/rules.d/*.rules 2>/dev/null)
USB_OK=false; [[ "$RULES" =~ /dev/|/media/|/mnt/|usb ]] && USB_OK=true
EXEC_OK=false; [[ "$RULES" =~ execve|-S\ execve ]] && EXEC_OK=true
LOGIN_OK=false; [[ "$RULES" =~ logins|USER_LOGIN|sshd|/var/run/utmp|/var/log/faillog|pam_tally ]] && LOGIN_OK=true

if $USB_OK && $EXEC_OK && $LOGIN_OK; then
    check_pass "РСБ.1.2" "Настроены обязательные события: носители (USB), запуск программ, входы"
else
    # Исправлено формирование строки ошибок
    MISSING=""
    [[ "$USB_OK" == false ]] && MISSING+="USB "
    [[ "$EXEC_OK" == false ]] && MISSING+="execve "
    [[ "$LOGIN_OK" == false ]] && MISSING+="logins "
    check_fail "РСБ.1.2" "Отсутствуют правила аудита для: $MISSING"
fi

# РСБ.1.3 – Системное логирование
if systemctl is-active --quiet rsyslog 2>/dev/null || systemctl is-active --quiet systemd-journald 2>/dev/null; then
    check_pass "РСБ.1.3" "Служба системного логирования активна"
else 
    check_fail "РСБ.1.3" "Служба системного логирования не активна"
fi

if $WITH_ENH; then
    # РСБ.1.4 (Усиление 1) – Привилегированные команды
    if echo "$RULES" | grep -qE "execve.*(euid=0|uid=0|auid=0)"; then
        check_pass "РСБ.1.4" "Включено логирование привилегированных команд (execve)"
    else 
        check_fail "РСБ.1.4" "Отсутствуют правила аудита для привилегированных команд"
    fi
    
    # РСБ.1.5 (Усиление 3) – Место удаленного доступа (IP-адреса)
    if grep -qE "^LogLevel\s+VERBOSE" /etc/ssh/sshd_config 2>/dev/null; then
        check_pass "РСБ.1.5" "SSH: LogLevel VERBOSE (фиксируется IP/порт источника)"
    else 
        check_fail "РСБ.1.5" "SSH: Требуется LogLevel VERBOSE для фиксации места доступа"
    fi
    
    # РСБ.1.6 (Усиление 4) – Передача в SIEM
    if grep -rqE "^\*\.\*.*(@@|@)" /etc/rsyslog.d/ /etc/rsyslog.conf 2>/dev/null; then
        check_pass "РСБ.1.6" "Настроена отправка логов на удаленный SIEM/Syslog сервер"
    else 
        check_fail "РСБ.1.6" "Отправка логов на централизованный сервер (SIEM) не настроена"
    fi
else
    check_skip "РСБ.1.4-6" "Проверка усилений отключена (используйте флаг -e)"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ РСБ.1: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
