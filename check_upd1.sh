#!/bin/bash
# Модуль проверки УПД.1 - Реализация модели управления доступом
WITH_ENHANCEMENTS=false
[[ "$1" == "--with-enhancements" || "$1" == "-e" ]] && WITH_ENHANCEMENTS=true

# Определение ОС
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME; OS_VER=$VERSION_ID
    else OS_NAME="Unknown"; fi
    if [[ "$OS_NAME" == *"Astra"* ]]; then
        if [[ "$OS_VER" == *"1.7"* ]]; then OS_TYPE="astra17";
        elif [[ "$OS_VER" == *"1.8"* ]]; then OS_TYPE="astra18";
        else OS_TYPE="astra"; fi
    elif [[ "$OS_NAME" == *"ALT"* ]]; then OS_TYPE="alt";
    elif [[ "$OS_NAME" == *"RED"* || "$OS_NAME" == *"Red"* ]]; then OS_TYPE="redos";
    else OS_TYPE="generic"; fi
}
detect_os

check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
FAIL_COUNT=0

# УПД.1.1 – Наличие групп (ролевая модель)
GROUP_COUNT=$(wc -l < /etc/group 2>/dev/null || echo "0")
if [ "$GROUP_COUNT" -gt 10 ]; then
    check_pass "УПД.1.1" "Обнаружено $GROUP_COUNT групп пользователей (ролевая модель реализована)"
else
    check_fail "УПД.1.1" "Недостаточно групп пользователей для ролевой модели (только $GROUP_COUNT)"
fi

# УПД.1.2 – Настройка sudo для ролевого доступа и минимизация привилегий
if [ -f /etc/sudoers ] || [ -d /etc/sudoers.d ]; then
    # 1. Проверяем наличие базовых правил ролевого доступа
    SUDO_RULES=$(grep -cE "^[^#].*ALL=" /etc/sudoers /etc/sudoers.d/* 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}')
    
    if [ "$SUDO_RULES" -gt 0 ]; then
        # 2. ИСПРАВЛЕНИЕ: Проверка на наличие опасных NOPASSWD: ALL для не-root пользователей
        # Это прямое нарушение принципа минимизации прав из методички ФСТЭК
        DANGEROUS_SUDO=$(grep -rE "^[^#].*NOPASSWD:\s*ALL" /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -v "root" | wc -l)
        
        if [ "$DANGEROUS_SUDO" -eq 0 ]; then
            check_pass "УПД.1.2" "Sudo настроен ($SUDO_RULES правил), опасные конструкции NOPASSWD: ALL не обнаружены"
        else
            check_fail "УПД.1.2" "Обнаружены опасные правила sudo (NOPASSWD: ALL) для $DANGEROUS_SUDO пользователей"
        fi
    else
        check_fail "УПД.1.2" "Sudo настроен, но правила ролевого доступа не обнаружены"
    fi
else
    check_fail "УПД.1.2" "Файл /etc/sudoers отсутствует"
fi

# УПД.1.3 – Мандатный доступ (Astra PARSEC / SELinux)
if [[ "$OS_TYPE" == "astra17" || "$OS_TYPE" == "astra18" ]]; then
    if systemctl is-active --quiet parsecd 2>/dev/null; then
        MAC_USERS=$(pdpl-user 2>/dev/null | wc -l)
        check_pass "УПД.1.3" "Мандатный доступ PARSEC активен, настроено $MAC_USERS пользователей"
    else
        check_fail "УПД.1.3" "Служба PARSEC не активна (мандатный доступ не реализован)"
    fi
else
    # Для ALT/RedOS проверяем SELinux
    if command -v getenforce &>/dev/null; then
        SELINUX_STATUS=$(getenforce 2>/dev/null)
        if [ "$SELINUX_STATUS" == "Enforcing" ]; then
            check_pass "УПД.1.3" "SELinux в режиме Enforcing (мандатный доступ реализован)"
        else
            check_fail "УПД.1.3" "SELinux не в режиме Enforcing (текущий статус: $SELINUX_STATUS)"
        fi
    else
        check_fail "УПД.1.3" "Средства мандатного доступа (PARSEC/SELinux) не обнаружены"
    fi
fi

# УПД.1.4 – AppArmor (дополнительная защита)
if command -v apparmor_status &>/dev/null || systemctl is-active --quiet apparmor 2>/dev/null; then
    PROFILES=$(aa-status 2>/dev/null | grep -c "profiles are loaded" || echo "0")
    check_pass "УПД.1.4" "AppArmor активен, загружено профилей: $PROFILES"
else
    echo "[УПД.1.4] INFO – AppArmor не используется (не обязательно для базовой проверки)"
fi

# УПД.1.5 – Усиление: Централизованное управление
if $WITH_ENHANCEMENTS; then
    if systemctl is-active --quiet sssd 2>/dev/null; then
        if grep -qE "ldap_group|ad_group|ipa_group" /etc/sssd/sssd.conf 2>/dev/null; then
            check_pass "УПД.1.5" "SSSD настроен с управлением группами (централизованная модель)"
        else
            check_fail "УПД.1.5" "SSSD активен, но управление группами не настроено"
        fi
    else
        check_fail "УПД.1.5" "Централизованное управление доступом (SSSD/LDAP) не обнаружено"
    fi
else
    echo "[УПД.1.5] SKIP – проверка усилений отключена"
fi

echo "=== ИТОГ МОДУЛЯ УПД.1: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1