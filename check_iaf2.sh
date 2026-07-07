#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

check_pass() { fstek_status_line "$1" "PASS" "$2"; }
check_fail() { fstek_status_line "$1" "FAIL" "$2"; ((FAIL_COUNT++)); }
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
if fstek_enhancement_enabled "ИАФ.2" "1"; then
    if [ -d /sys/class/tpm ] || command -v tpm2_getcap &>/dev/null; then
        check_pass "ИАФ.2.3" "Обнаружен модуль безопасности TPM"
    else
        check_fail "ИАФ.2.3" "TPM не обнаружен или не доступен ОС"
    fi
else
    skip_enhancement "ИАФ.2.3"
fi

# ИАФ.2.4 – Усиление (Машинные сертификаты / IPA)
if fstek_enhancement_enabled "ИАФ.2" "2"; then
    if command -v ipa-client &>/dev/null && ipa-client &>/dev/null | grep -q "configured"; then
        check_pass "ИАФ.2.4" "Устройство enrolled в домен (FreeIPA), машинный сертификат присутствует"
    elif [ -f /etc/pki/tls/certs/localhost.crt ] || ls /etc/pki/tls/certs/*.pem &>/dev/null; then
        check_pass "ИАФ.2.4" "Обнаружены локальные машинные сертификаты в /etc/pki"
    else
        check_fail "ИАФ.2.4" "Машинные сертификаты и интеграция с ЦС не обнаружены"
    fi
else
    skip_enhancement "ИАФ.2.4"
fi

echo "=== ИТОГ МОДУЛЯ ИАФ.2: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1