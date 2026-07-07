#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# Модуль проверки ИАФ.1 (Универсальный для Astra/ALT/RedOS)

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

# Функция определения ОС
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="${NAME:-Unknown}"; OS_VER="${VERSION_ID:-}"
        OS_MATCH="$(printf '%s' "${ID:-} ${ID_LIKE:-} ${NAME:-} ${PRETTY_NAME:-}" | tr '[:upper:]' '[:lower:]')"
    else OS_NAME="Unknown"; OS_VER=""; OS_MATCH=""; fi
    if [[ "$OS_MATCH" == *"astra"* || "$OS_MATCH" == *"alse"* ]]; then
        if [[ "$OS_VER" == 1.7* ]]; then OS_TYPE="astra17";
        elif [[ "$OS_VER" == 1.8* ]]; then OS_TYPE="astra18";
        else OS_TYPE="astra"; fi
    elif [[ "$OS_MATCH" == *"altlinux"* || "$OS_MATCH" == *"alt linux"* || "$OS_MATCH" == *"alt"* ]]; then OS_TYPE="alt";
    elif [[ "$OS_MATCH" == *"redos"* || "$OS_MATCH" == *"red os"* || "$OS_MATCH" == *"red-os"* || "$OS_MATCH" == *"red_os"* ]]; then OS_TYPE="redos";
    else OS_TYPE="generic"; fi
}
detect_os

check_pass() { fstek_status_line "$1" "PASS" "$2"; }
check_fail() { fstek_status_line "$1" "FAIL" "$2"; ((FAIL_COUNT++)); }
check_skip() { fstek_status_line "$1" "SKIP" "$2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

FAIL_COUNT=0; SKIP_COUNT=0

# ИАФ.1.1 – /etc/passwd
if [ -f /etc/passwd ] && [ -s /etc/passwd ]; then
    if awk -F: '{print $3}' /etc/passwd | sort | uniq -d | grep -q .; then
        check_fail "ИАФ.1.1" "Обнаружены дублирующиеся UID в /etc/passwd"
    else
        check_pass "ИАФ.1.1" "Файл /etc/passwd корректен, дубликатов UID нет"
    fi
else
    check_fail "ИАФ.1.1" "Файл /etc/passwd отсутствует или пуст"
fi

# ИАФ.1.2 – PAM
PAM_FOUND=false
for pfile in /etc/pam.d/common-auth /etc/pam.d/system-auth /etc/pam.d/login /etc/pam.d/parsecd; do
    if [ -f "$pfile" ]; then
        if grep -qE "pam_unix\.so|pam_sss\.so|pam_parsec\.so" "$pfile"; then
            PAM_FOUND=true; break
        fi
    fi
done
if $PAM_FOUND; then
    check_pass "ИАФ.1.2" "PAM настроен (обнаружены модули pam_unix/pam_sss/pam_parsec)"
else
    check_fail "ИАФ.1.2" "Не найдены базовые модули идентификации в PAM"
fi

# ИАФ.1.3 – nsswitch.conf
if [ -f /etc/nsswitch.conf ]; then
    if grep -qE "^passwd:\s+.*(files|sss|ldap|parsec)" /etc/nsswitch.conf; then
        check_pass "ИАФ.1.3" "nsswitch.conf содержит корректные источники (files/sss/ldap)"
    else
        check_fail "ИАФ.1.3" "nsswitch.conf не содержит допустимых источников для passwd"
    fi
else
    check_fail "ИАФ.1.3" "Файл /etc/nsswitch.conf отсутствует"
fi

# ИАФ.1.4 – Организационная мера
check_skip "ИАФ.1.4" "Процедура первичной идентификации личности (требует ручной проверки регламента)"

# ИАФ.1.5 – Усиление (Централизация)
if fstek_enhancement_enabled "ИАФ.1" "1"; then
    if systemctl is-active --quiet sssd 2>/dev/null && grep -q "domains =" /etc/sssd/sssd.conf 2>/dev/null; then
        check_pass "ИАФ.1.5" "Обнаружена централизация через SSSD (домен настроен)"
    elif [ "$OS_TYPE" == "astra17" ] || [ "$OS_TYPE" == "astra18" ]; then
        if systemctl is-active --quiet parsecd 2>/dev/null; then
            check_pass "ИАФ.1.5" "Astra Linux: Служба PARSEC активна (возможна интеграция с КД)"
        else
            check_fail "ИАФ.1.5" "Централизованное управление не обнаружено (SSSD/FreeIPA не настроены)"
        fi
    else
        check_fail "ИАФ.1.5" "Централизованное управление (SSSD/FreeIPA/AD) не настроено"
    fi
else
    skip_enhancement "ИАФ.1.5"
fi

echo "=== ИТОГ МОДУЛЯ ИАФ.1: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
