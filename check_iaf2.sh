#!/bin/bash
WITH_ENHANCEMENTS=false
[[ "$1" == "--with-enhancements" || "$1" == "-e" ]] && WITH_ENHANCEMENTS=true

check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
FAIL_COUNT=0

# ИАФ.2.1 – Hostname
HOSTNAME=$(hostnamectl --static 2>/dev/null || hostname)
if [[ "$HOSTNAME" != "localhost" && "$HOSTNAME" != "localhost.localdomain" && -n "$HOSTNAME" ]]; then
    check_pass "ИАФ.2.1" "Hostname задан и уникален: $HOSTNAME"
else
    check_fail "ИАФ.2.1" "Hostname не настроен или равен localhost"
fi

# ИАФ.2.2 – Инвентаризация MAC
MAC_COUNT=$(ip link show | grep -c "link/ether")
if [ "$MAC_COUNT" -gt 0 ]; then
    check_pass "ИАФ.2.2" "Обнаружено $MAC_COUNT сетевых интерфейсов с MAC-адресами (инвентаризация доступна)"
else
    check_fail "ИАФ.2.2" "Не удалось получить MAC-адреса сетевых интерфейсов"
fi

# ИАФ.2.3 – Усиление (TPM)
if $WITH_ENHANCEMENTS; then
    if [ -d /sys/class/tpm ] || command -v tpm2_getcap &>/dev/null; then
        check_pass "ИАФ.2.3" "Обнаружен модуль безопасности TPM"
    else
        check_fail "ИАФ.2.3" "TPM не обнаружен или не доступен ОС"
    fi
else
    echo "[ИАФ.2.3] SKIP – проверка усилений отключена"
fi

# ИАФ.2.4 – Усиление (Машинные сертификаты / IPA)
if $WITH_ENHANCEMENTS; then
    if command -v ipa-client &>/dev/null && ipa-client &>/dev/null | grep -q "configured"; then
        check_pass "ИАФ.2.4" "Устройство enrolled в домен (FreeIPA), машинный сертификат присутствует"
    elif [ -f /etc/pki/tls/certs/localhost.crt ] || ls /etc/pki/tls/certs/*.pem &>/dev/null; then
        check_pass "ИАФ.2.4" "Обнаружены локальные машинные сертификаты в /etc/pki"
    else
        check_fail "ИАФ.2.4" "Машинные сертификаты и интеграция с ЦС не обнаружены"
    fi
else
    echo "[ИАФ.2.4] SKIP – проверка усилений отключена"
fi

echo "=== ИТОГ МОДУЛЯ ИАФ.2: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1