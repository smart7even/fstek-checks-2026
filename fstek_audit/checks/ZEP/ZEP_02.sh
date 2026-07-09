#!/usr/bin/env bash
# fstek_audit/checks/ZEP/ZEP_02.sh - migrated measure logic for ЗЭП.2.

run_check() {
    # check_zep2.sh - Управление доступом пользователей (ЗЭП.2)
    # Соответствие разделу 4.6 (ЗЭП.2) Методического документа ФСТЭК России от 12.04.2026

    WITH_ENHANCEMENTS=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
        esac
    done


    # Унифицированные функции вывода

    # --- ПРОВЕРКА НАЛИЧИЯ ПОЧТОВОГО СЕРВЕРА ---
    # Если почтовый сервер не установлен, проверка ЗЭП.2 пропускается
    if ! command -v postconf &>/dev/null && ! systemctl list-units --all 2>/dev/null | grep -qE "postfix|dovecot|exim|sendmail"; then
        check_skip "ЗЭП.2" "Почтовый сервер не обнаружен. Проверка ЗЭП.2 пропущена."
        finish_legacy_measure "ЗЭП.2"
        exit 0
    fi

    # --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

    # ЗЭП.2.1 - Доступ после процедуры ИА (ИАФ.1, ИАФ.3)
    SASL_ENABLED=$(postconf -h smtpd_sasl_auth_enable 2>/dev/null)
    if [ "$SASL_ENABLED" == "yes" ]; then
        check_pass "ЗЭП.2.1" "Аутентификация пользователей при доступе к ящикам включена (SASL)"
    else
        check_fail "ЗЭП.2.1" "Не включена аутентификация пользователей (smtpd_sasl_auth_enable != yes)"
    fi

    # ЗЭП.2.2 - Организационная мера (согласование доступа)
    check_skip "ЗЭП.2.2" "Согласование доступа к общим ящикам и группам рассылки с владельцем"

    # Унифицированная итоговая строка
    finish_legacy_measure "ЗЭП.2"
}
