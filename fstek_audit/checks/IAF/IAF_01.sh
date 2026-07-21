#!/usr/bin/env bash
# fstek_audit/checks/IAF/IAF_01.sh - migrated measure logic for ИАФ.1.

run_check() {
    # Модуль проверки ИАФ.1 (Универсальный для Astra/ALT/RedOS)

    WITH_ENHANCEMENTS=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
        esac
    done

    # Функция определения ОС
detect_os



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

    # ИАФ.1.2 – PAM (Astra/Debian common-*, RHEL/ALT system-auth/password-auth)
    PAM_FOUND=false
    for pfile in /etc/pam.d/common-auth /etc/pam.d/system-auth /etc/pam.d/password-auth /etc/pam.d/login /etc/pam.d/parsecd; do
        if [ -f "$pfile" ]; then
            if grep -qE "pam_unix\.so|pam_sss\.so|pam_parsec\.so" "$pfile"; then
                PAM_FOUND=true; break
            fi
        fi
    done
    if ! $PAM_FOUND && grep_any "pam_unix\\.so|pam_sss\\.so|pam_parsec\\.so" /etc/pam.d 2>/dev/null; then
        PAM_FOUND=true
    fi
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

    finish_legacy_measure "ИАФ.1"
}
