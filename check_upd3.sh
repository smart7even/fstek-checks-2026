#!/bin/bash
# Модуль проверки УПД.3 - Управление учетными записями
WITH_ENHANCEMENTS=false
[[ "$1" == "--with-enhancements" || "$1" == "-e" ]] && WITH_ENHANCEMENTS=true

check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
FAIL_COUNT=0

# УПД.3.1 – Заблокированные учетные записи и неактивные УЗ
LOCKED_ACCOUNTS=$(passwd -S 2>/dev/null | grep -c " L " || grep -cE "^[^:]+:.*:.*:.*:.*:.*:.*:\*$" /etc/shadow 2>/dev/null || echo "0")

# ИСПРАВЛЕНИЕ: Надежная проверка неактивных УЗ через /etc/shadow (поле 7 - период неактивности)
# Вместо уязвимого lastlog, который падает на "Never logged in" и выдает ошибки bash
INACTIVE_90_DAYS=0
if [ -f /etc/shadow ]; then
    while IFS=: read -r user _ _ _ _ _ inactive _; do
        # Если поле inactive задано и оно больше 90 дней
        if [[ "$inactive" =~ ^[0-9]+$ ]] && [ "$inactive" -gt 90 ]; then
            ((INACTIVE_90_DAYS++))
        fi
    done < /etc/shadow
fi

check_pass "УПД.3.1" "Заблокировано учетных записей: $LOCKED_ACCOUNTS, неактивных >90 дней: $INACTIVE_90_DAYS"

# УПД.3.2 – Срок действия паролей
MAX_DAYS_CONFIGURED=0
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    MAX_DAYS=$(chage -l "$user" 2>/dev/null | grep "Maximum" | awk -F: '{print $2}' | tr -d ' ')
    if [[ "$MAX_DAYS" =~ ^[0-9]+$ ]] && [ "$MAX_DAYS" -le 90 ]; then
        ((MAX_DAYS_CONFIGURED++))
    fi
done
TOTAL_USERS=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd | wc -l)
if [ "$MAX_DAYS_CONFIGURED" -eq "$TOTAL_USERS" ] && [ "$TOTAL_USERS" -gt 0 ]; then
    check_pass "УПД.3.2" "Срок действия паролей настроен для всех пользователей (<=90 дней)"
else
    check_fail "УПД.3.2" "Срок действия паролей не настроен для всех пользователей ($MAX_DAYS_CONFIGURED из $TOTAL_USERS)"
fi

# УПД.3.3 – Учетные записи без пароля
NO_PASSWORD=$(awk -F: '($2 == "" || $2 == "!") && $3 >= 1000 {print $1}' /etc/shadow 2>/dev/null | wc -l)
if [ "$NO_PASSWORD" -eq 0 ]; then
    check_pass "УПД.3.3" "Учетные записи без пароля отсутствуют"
else
    check_fail "УПД.3.3" "Обнаружено $NO_PASSWORD учетных записей без пароля"
fi

# УПД.3.4 – Журнал изменений учетных записей (auditd)
if systemctl is-active --quiet auditd 2>/dev/null; then
    # УСИЛЕНИЕ: Более строгая проверка правил auditd на конкретные критические файлы
    AUDIT_RULES=$(auditctl -l 2>/dev/null | grep -cE "\-w /etc/passwd|\-w /etc/shadow|\-w /etc/group|\-w /etc/gshadow" || echo "0")
    
    if [ "$AUDIT_RULES" -ge 3 ]; then 
        # Ожидаем, что настроено минимум 3 правила из 4 возможных
        check_pass "УПД.3.4" "Auditd активен, настроено $AUDIT_RULES строгих правил для учета изменений УЗ (passwd/shadow/group)"
    else
        check_fail "УПД.3.4" "Auditd активен, но строгие правила для учета изменений УЗ не настроены (найдено: $AUDIT_RULES)"
    fi
else
    check_fail "УПД.3.4" "Служба auditd не активна (журнал изменений УЗ не ведется)"
fi

# УПД.3.5 – Усиление: Централизованное управление
if $WITH_ENHANCEMENTS; then
    if systemctl is-active --quiet sssd 2>/dev/null; then
        if [ -f /etc/sssd/sssd.conf ] && grep -q "domains =" /etc/sssd/sssd.conf; then
            check_pass "УПД.3.5" "Централизованное управление УЗ через SSSD настроено"
        else
            check_fail "УПД.3.5" "SSSD активен, но домены не настроены"
        fi
    elif command -v ipa-client-install &>/dev/null && ipa-client-install --help &>/dev/null; then
        check_pass "УПД.3.5" "FreeIPA клиент установлен (централизованное управление)"
    else
        check_fail "УПД.3.5" "Централизованное управление учетными записями не обнаружено"
    fi
else
    echo "[УПД.3.5] SKIP – проверка усилений отключена"
fi

echo "=== ИТОГ МОДУЛЯ УПД.3: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1