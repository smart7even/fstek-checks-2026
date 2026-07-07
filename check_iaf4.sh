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

# ИАФ.4.1 – 802.1x в NetworkManager
NM_DIR="/etc/NetworkManager/system-connections"
DOT1X_FOUND=false
if [ -d "$NM_DIR" ]; then
    if grep -rq "802-1x" "$NM_DIR" 2>/dev/null; then
        DOT1X_FOUND=true
    fi
fi
if $DOT1X_FOUND; then
    check_pass "ИАФ.4.1" "Обнаружены профили NetworkManager с настройками 802.1x"
else
    check_fail "ИАФ.4.1" "Профили 802.1x в NetworkManager не найдены (возможно, используется только IP/MAC)"
fi

# ИАФ.4.2 – TLS для машинной аутентификации (SSSD/LDAP)
TLS_AUTH=false
if [ -f /etc/sssd/sssd.conf ]; then
    if grep -qE "ldap_auth_disable_tls_never_use_in_production_tests|ldap_tls_reqcert" /etc/sssd/sssd.conf; then
        TLS_AUTH=true
    fi
fi
if [ -f /etc/nslcd.conf ] && grep -q "ssl start_tls" /etc/nslcd.conf; then
    TLS_AUTH=true
fi

if $TLS_AUTH; then
    check_pass "ИАФ.4.2" "Использование TLS для машинной аутентификации в каталогах настроено"
else
    check_fail "ИАФ.4.2" "TLS для машинной аутентификации (SSSD/LDAP) не настроен или отключен"
fi

# ИАФ.4.3 – Усиление (Корпоративный ЦС / Kerberos)
if fstek_enhancement_enabled "ИАФ.4" "1"; then
    if [ -f /etc/krb5.conf ] && grep -q "default_realm" /etc/krb5.conf; then
        check_pass "ИАФ.4.3" "Настроен Kerberos (интеграция с ЦС / Active Directory)"
    elif command -v realm &>/dev/null && realm list | grep -q "configured"; then
        check_pass "ИАФ.4.3" "Устройство подключено к домену через realmd"
    else
        check_fail "ИАФ.4.3" "Интеграция с корпоративным ЦС (Kerberos/AD/FreeIPA) не обнаружена"
    fi
else
    skip_enhancement "ИАФ.4.3"
fi

echo "=== ИТОГ МОДУЛЯ ИАФ.4: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1