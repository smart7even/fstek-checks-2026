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

# ИАФ.3.1 – Сложность пароля (minlen >= 12)
PWQUALITY="/etc/security/pwquality.conf"
if [ -f "$PWQUALITY" ]; then
    MINLEN=$(grep -E "^minlen" "$PWQUALITY" | awk -F'=' '{print $2}' | tr -d ' ')
    if [ -n "$MINLEN" ] && [ "$MINLEN" -ge 12 ]; then
        check_pass "ИАФ.3.1" "Минимальная длина пароля настроена: $MINLEN (>= 12)"
    else
        check_fail "ИАФ.3.1" "Минимальная длина пароля менее 12 или не задана в pwquality.conf"
    fi
else
    check_fail "ИАФ.3.1" "Файл $PWQUALITY отсутствует"
fi

# ИАФ.3.2 – Алфавит паролей (Алфавит >= 70 символов / minclass >= 4)
if [ -f "$PWQUALITY" ]; then
    MINCLASS=$(grep -E "^minclass" "$PWQUALITY" | awk -F'=' '{print $2}' | tr -d ' ')
    # minclass=4 означает требование букв верхнего/нижнего регистра, цифр и спецсимволов (алфавит > 70)
    if [ -n "$MINCLASS" ] && [ "$MINCLASS" -ge 4 ]; then
        check_pass "ИАФ.3.2" "Сложность пароля (алфавит) настроена: minclass=$MINCLASS"
    else
        check_fail "ИАФ.3.2" "Не настроена минимальная сложность пароля (minclass) в pwquality.conf (требуется >= 4)"
    fi
fi

# ИАФ.3.3 – Запрет повторного использования пароля (pam_pwhistory)
PWHISTORY_FOUND=false
for pfile in /etc/pam.d/system-auth /etc/pam.d/password-auth /etc/pam.d/common-password; do
    if [ -f "$pfile" ] && grep -qE "pam_pwhistory\.so|pam_unix\.so.*remember=" "$pfile"; then
        PWHISTORY_FOUND=true; break
    fi
done
if $PWHISTORY_FOUND; then
    check_pass "ИАФ.3.3" "Запрет повторного использования пароля настроен (pam_pwhistory/remember)"
else
    check_fail "ИАФ.3.3" "Не настроен запрет на повторное использование паролей (pam_pwhistory)"
fi

# ИАФ.3.4 – Смена пароля (PASS_MAX_DAYS <= 90)
LOGIN_DEFS="/etc/login.defs"
if [ -f "$LOGIN_DEFS" ]; then
    MAX_DAYS=$(grep -E "^PASS_MAX_DAYS" "$LOGIN_DEFS" | awk '{print $2}')
    if [ -n "$MAX_DAYS" ] && [ "$MAX_DAYS" -le 90 ] && [ "$MAX_DAYS" -gt 0 ]; then
        check_pass "ИАФ.3.4" "Срок действия пароля: $MAX_DAYS дней (<= 90)"
    else
        check_fail "ИАФ.3.4" "PASS_MAX_DAYS в login.defs больше 90 или не задан ($MAX_DAYS)"
    fi
else
    check_fail "ИАФ.3.4" "Файл $LOGIN_DEFS отсутствует"
fi

# ИАФ.3.5 – Блокировка (pam_faillock deny=5, unlock_time=900)
FAILLOCK_CONF="/etc/security/faillock.conf"
PAM_FILES="/etc/pam.d/system-auth /etc/pam.d/common-auth /etc/pam.d/password-auth"
LOCK_CONFIGURED=false

if [ -f "$FAILLOCK_CONF" ]; then
    DENY=$(grep -E "^deny" "$FAILLOCK_CONF" | awk -F'=' '{print $2}' | tr -d ' ')
    UNLOCK=$(grep -E "^unlock_time" "$FAILLOCK_CONF" | awk -F'=' '{print $2}' | tr -d ' ')
    if [ "$DENY" = "5" ] && [ "$UNLOCK" = "900" ]; then LOCK_CONFIGURED=true; fi
fi

if ! $LOCK_CONFIGURED; then
    for pfile in $PAM_FILES; do
        if [ -f "$pfile" ] && grep -qE "pam_faillock\.so.*deny=5|pam_tally2\.so.*deny=5" "$pfile"; then
            LOCK_CONFIGURED=true; break
        fi
    done
fi

if $LOCK_CONFIGURED; then
    check_pass "ИАФ.3.5" "Блокировка УЗ настроена (5 попыток, 15 минут)"
else
    check_fail "ИАФ.3.5" "Блокировка УЗ (pam_faillock/pam_tally2) не настроена согласно требованиям"
fi

# ИАФ.3.6 – Усиление (2FA / OTP)
if fstek_enhancement_enabled "ИАФ.3" "1"; then
    if grep -rqE "pam_google_authenticator|pam_pkcs11|pam_oath|otp" /etc/pam.d/ 2>/dev/null; then
        check_pass "ИАФ.3.6" "Обнаружены модули 2FA/MFA в PAM"
    elif command -v ipa &>/dev/null && ipa config-show 2>/dev/null | grep -q "otp"; then
        check_pass "ИАФ.3.6" "FreeIPA: включена поддержка OTP"
    else
        check_fail "ИАФ.3.6" "Двухфакторная аутентификация (2FA) не обнаружена"
    fi
else
    skip_enhancement "ИАФ.3.6"
fi

echo "=== ИТОГ МОДУЛЯ ИАФ.3: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1