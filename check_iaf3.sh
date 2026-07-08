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

get_conf_value() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 1
    awk -F= -v key="$key" '
        $0 !~ /^[[:space:]]*#/ && $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
            gsub(/[[:space:]]/, "", $2); print $2; exit
        }
    ' "$file"
}

pam_option_max() {
    local option="$1"
    shift
    grep -hE "pam_(pwhistory|unix|faillock|tally2)\.so" "$@" 2>/dev/null |
        grep -oE "$option=[0-9]+" |
        awk -F= 'max < $2 {max = $2} END {if (max != "") print max}'
}

pam_has_option() {
    local option="$1"
    shift
    grep -hE "pam_(faillock|tally2)\.so" "$@" 2>/dev/null | grep -qE "(^|[[:space:]])$option([[:space:]]|$)"
}

active_local_users() {
    awk -F: 'NF >= 7 && $1 !~ /^#/ && ($7 !~ /(nologin|false)$/) {print $1}' /etc/passwd 2>/dev/null
}

# ИАФ.3.1 – Сложность пароля (minlen >= 12)
PWQUALITY="/etc/security/pwquality.conf"
if [ -f "$PWQUALITY" ]; then
    MINLEN=$(get_conf_value "$PWQUALITY" "minlen")
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
    MINCLASS=$(get_conf_value "$PWQUALITY" "minclass")
    # minclass=4 означает требование букв верхнего/нижнего регистра, цифр и спецсимволов (алфавит > 70)
    if [ -n "$MINCLASS" ] && [ "$MINCLASS" -ge 4 ]; then
        check_pass "ИАФ.3.2" "Сложность пароля (алфавит) настроена: minclass=$MINCLASS"
    else
        check_fail "ИАФ.3.2" "Не настроена минимальная сложность пароля (minclass) в pwquality.conf (требуется >= 4)"
    fi
fi

# ИАФ.3.3 – Запрет повторного использования 12 последних паролей
PWHISTORY_REMEMBER=0
for pfile in /etc/pam.d/system-auth /etc/pam.d/password-auth /etc/pam.d/common-password; do
    if [ -f "$pfile" ]; then
        VALUE=$(pam_option_max "remember" "$pfile")
        if [[ "$VALUE" =~ ^[0-9]+$ ]] && [ "$VALUE" -gt "$PWHISTORY_REMEMBER" ]; then
            PWHISTORY_REMEMBER="$VALUE"
        fi
    fi
done
if [ "$PWHISTORY_REMEMBER" -ge 12 ]; then
    check_pass "ИАФ.3.3" "Запрет повторного использования настроен: remember=$PWHISTORY_REMEMBER (>= 12)"
else
    check_fail "ИАФ.3.3" "Не настроен запрет повторного использования 12 последних паролей (remember=$PWHISTORY_REMEMBER)"
fi

# ИАФ.3.4 – Смена пароля (PASS_MAX_DAYS <= 90) для всех локальных пользователей, включая привилегированных
LOGIN_DEFS="/etc/login.defs"
if [ -f "$LOGIN_DEFS" ]; then
    MAX_DAYS=$(awk '$1 == "PASS_MAX_DAYS" {print $2; exit}' "$LOGIN_DEFS")
    if [ -n "$MAX_DAYS" ] && [ "$MAX_DAYS" -le 90 ] && [ "$MAX_DAYS" -gt 0 ]; then
        check_pass "ИАФ.3.4" "Срок действия пароля: $MAX_DAYS дней (<= 90)"
    else
        check_fail "ИАФ.3.4" "PASS_MAX_DAYS в login.defs больше 90 или не задан ($MAX_DAYS)"
    fi
else
    check_fail "ИАФ.3.4" "Файл $LOGIN_DEFS отсутствует"
fi

USERS_WITH_BAD_MAX_DAYS=()
while read -r user; do
    [ -n "$user" ] || continue
    USER_MAX=$(chage -l "$user" 2>/dev/null | awk -F: '/Maximum number of days|Максимальное/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')
    if ! [[ "$USER_MAX" =~ ^[0-9]+$ ]] || [ "$USER_MAX" -gt 90 ] || [ "$USER_MAX" -le 0 ]; then
        USERS_WITH_BAD_MAX_DAYS+=("$user:${USER_MAX:-unset}")
    fi
done < <(active_local_users)

if [ "${#USERS_WITH_BAD_MAX_DAYS[@]}" -eq 0 ]; then
    check_pass "ИАФ.3.4a" "Срок действия пароля <=90 дней задан для активных локальных пользователей"
else
    check_fail "ИАФ.3.4a" "Есть активные пользователи без срока <=90 дней: ${USERS_WITH_BAD_MAX_DAYS[*]}"
fi

# ИАФ.3.5 – Блокировка (не более 5 попыток, не менее 900 секунд), включая привилегированных
FAILLOCK_CONF="/etc/security/faillock.conf"
PAM_FILES="/etc/pam.d/system-auth /etc/pam.d/common-auth /etc/pam.d/password-auth"
LOCK_CONFIGURED=false
LOCK_PRIVILEGED=false

if [ -f "$FAILLOCK_CONF" ]; then
    DENY=$(get_conf_value "$FAILLOCK_CONF" "deny")
    UNLOCK=$(get_conf_value "$FAILLOCK_CONF" "unlock_time")
    EVEN_DENY_ROOT=$(grep -Eq "^[[:space:]]*even_deny_root([[:space:]]|$)" "$FAILLOCK_CONF" && echo yes || echo no)
    ADMIN_GROUP=$(get_conf_value "$FAILLOCK_CONF" "admin_group")
    if [[ "$DENY" =~ ^[0-9]+$ ]] && [ "$DENY" -le 5 ] && [[ "$UNLOCK" =~ ^[0-9]+$ ]] && [ "$UNLOCK" -ge 900 ]; then LOCK_CONFIGURED=true; fi
    if [ "$EVEN_DENY_ROOT" = "yes" ] || [ -n "$ADMIN_GROUP" ]; then LOCK_PRIVILEGED=true; fi
fi

if ! $LOCK_CONFIGURED; then
    for pfile in $PAM_FILES; do
        DENY=$(pam_option_max "deny" "$pfile")
        UNLOCK=$(pam_option_max "unlock_time" "$pfile")
        if [[ "$DENY" =~ ^[0-9]+$ ]] && [ "$DENY" -le 5 ] && { [ -z "$UNLOCK" ] || [ "$UNLOCK" -ge 900 ]; }; then
            LOCK_CONFIGURED=true; break
        fi
    done
fi

if ! $LOCK_PRIVILEGED; then
    for pfile in $PAM_FILES; do
        if [ -f "$pfile" ] && { pam_has_option "even_deny_root" "$pfile" || grep -qE "admin_group=" "$pfile"; }; then
            LOCK_PRIVILEGED=true
            break
        fi
    done
fi

if $LOCK_CONFIGURED; then
    check_pass "ИАФ.3.5" "Блокировка УЗ настроена (5 попыток, 15 минут)"
else
    check_fail "ИАФ.3.5" "Блокировка УЗ (pam_faillock/pam_tally2) не настроена согласно требованиям"
fi

if $LOCK_PRIVILEGED; then
    check_pass "ИАФ.3.5a" "Блокировка распространяется на привилегированных пользователей/root (even_deny_root/admin_group)"
else
    check_fail "ИАФ.3.5a" "Не подтверждена блокировка привилегированных пользователей после неуспешных попыток"
fi

# ИАФ.3.6 – Усиление (2FA / OTP)
if fstek_enhancement_enabled "ИАФ.3" "1"; then
    if grep -rqE "pam_google_authenticator|pam_pkcs11|pam_oath|pam_yubico|otp" /etc/pam.d/sshd /etc/pam.d/remote /etc/pam.d/login /etc/pam.d/su 2>/dev/null && grep -Eq "^[[:space:]]*AuthenticationMethods[[:space:]].*(keyboard-interactive|pam|publickey.*,)" /etc/ssh/sshd_config 2>/dev/null; then
        check_pass "ИАФ.3.6" "Для удаленного доступа обнаружены PAM MFA/OTP и AuthenticationMethods в SSH"
    elif grep -rqE "pam_google_authenticator|pam_pkcs11|pam_oath|pam_yubico|otp" /etc/pam.d/sshd /etc/pam.d/remote 2>/dev/null; then
        check_pass "ИАФ.3.6" "Обнаружены модули 2FA/MFA в PAM"
    elif command -v ipa &>/dev/null && ipa config-show 2>/dev/null | grep -q "otp"; then
        check_pass "ИАФ.3.6" "FreeIPA: включена поддержка OTP"
    else
        check_fail "ИАФ.3.6" "Двухфакторная аутентификация (2FA) не обнаружена"
    fi
    check_skip "ИАФ.3.6a" "Обязательность MFA для всех привилегированных пользователей при удаленном доступе проверяется в IdP/PAM-политиках и списке привилегированных учетных записей"
else
    skip_enhancement "ИАФ.3.6"
fi

echo "=== ИТОГ МОДУЛЯ ИАФ.3: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
