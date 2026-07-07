#!/bin/bash
# Модуль проверки УПД.5 - Предупреждение пользователя

WITH_ENHANCEMENTS=false
[[ "$1" == "--with-enhancements" || "$1" == "-e" ]] && WITH_ENHANCEMENTS=true

check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
FAIL_COUNT=0

# УПД.5.1 – /etc/issue (локальный вход)
if [ -f /etc/issue ] && [ -s /etc/issue ]; then
    ISSUE_SIZE=$(wc -c < /etc/issue)
    if [ "$ISSUE_SIZE" -gt 50 ]; then
        check_pass "УПД.5.1" "Файл /etc/issue существует и содержит предупреждение ($ISSUE_SIZE байт)"
    else
        check_fail "УПД.5.1" "Файл /etc/issue существует, но слишком короткий ($ISSUE_SIZE байт)"
    fi
else
    check_fail "УПД.5.1" "Файл /etc/issue отсутствует или пуст"
fi

# УПД.5.2 – /etc/issue.net (сетевой вход)
if [ -f /etc/issue.net ] && [ -s /etc/issue.net ]; then
    ISSUE_NET_SIZE=$(wc -c < /etc/issue.net)
    if [ "$ISSUE_NET_SIZE" -gt 50 ]; then
        check_pass "УПД.5.2" "Файл /etc/issue.net существует и содержит предупреждение ($ISSUE_NET_SIZE байт)"
    else
        check_fail "УПД.5.2" "Файл /etc/issue.net существует, но слишком короткий ($ISSUE_NET_SIZE байт)"
    fi
else
    check_fail "УПД.5.2" "Файл /etc/issue.net отсутствует или пуст"
fi

# УПД.5.3 – SSH Banner
if [ -f /etc/ssh/sshd_config ]; then
    BANNER=$(grep -E "^Banner" /etc/ssh/sshd_config | awk '{print $2}' | tr -d '"')
    if [ -n "$BANNER" ] && [ -f "$BANNER" ]; then
        check_pass "УПД.5.3" "SSH Banner настроен: $BANNER"
    else
        check_fail "УПД.5.3" "SSH Banner не настроен или файл не существует"
    fi
else
    check_fail "УПД.5.3" "Файл /etc/ssh/sshd_config отсутствует"
fi

# УПД.5.4 – Графическая оболочка (GDM/LightDM)
GDM_CONFIGURED=false
if [ -f /etc/gdm/custom.conf ] || [ -f /etc/gdm3/custom.conf ]; then
    if grep -qE "Banner|Welcome" /etc/gdm*/custom.conf 2>/dev/null; then
        GDM_CONFIGURED=true
    fi
elif [ -f /etc/lightdm/lightdm.conf ]; then
    if grep -qE "greeter-setup-script|display-setup-script" /etc/lightdm/lightdm.conf; then
        GDM_CONFIGURED=true
    fi
fi

if $GDM_CONFIGURED; then
    check_pass "УПД.5.4" "Предупреждение в графической оболочке настроено"
else
    echo "[УПД.5.4] INFO – Графическая оболочка не используется или предупреждение не настроено"
fi

echo "=== ИТОГ МОДУЛЯ УПД.5: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1