#!/usr/bin/env bash
# fstek_audit/checks/ZEP/ZEP_05.sh - migrated measure logic for ЗЭП.5.

run_check() {
    # check_zep5.sh - Защита от спама (ЗЭП.5)
    # Соответствие разделу 4.6 (ЗЭП.5) Методического документа ФСТЭК России от 12.04.2026

    WITH_ENHANCEMENTS=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
        esac
    done


    # Унифицированные функции вывода

    # --- ПРОВЕРКА НАЛИЧИЯ ПОЧТОВОГО СЕРВЕРА ---
    # Если почтовый сервер не установлен, проверка ЗЭП.5 пропускается
    if ! command -v postconf &>/dev/null && ! systemctl list-units --all | grep -qE "postfix|dovecot|exim|sendmail"; then
        check_skip "ЗЭП.5" "Почтовый сервер не обнаружен. Проверка ЗЭП.5 пропущена."
        finish_legacy_measure "ЗЭП.5"
        exit 0
    fi

    # --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

    # ЗЭП.5.1 - Контроль поступающих сообщений (Спам-фильтр + Black/White списки)
    SPAM_FILTER=false
    if systemctl is-active --quiet rspamd 2>/dev/null || \
       systemctl is-active --quiet spamassassin 2>/dev/null || \
       [ -n "$(postconf -h content_filter 2>/dev/null)" ]; then
        SPAM_FILTER=true
    fi

    BW_LISTS=false
    # Проверка Black/White списков на уровне MTA (Postfix)
    if grep -rqE "check_client_access|check_sender_access" /etc/postfix/main.cf 2>/dev/null; then
        BW_LISTS=true
    fi
    # Или в Rspamd/SpamAssassin
    if grep -rqE "blacklist|whitelist|multimap" /etc/rspamd/local.d/ /etc/spamassassin/ 2>/dev/null; then
        BW_LISTS=true
    fi

    if $SPAM_FILTER && $BW_LISTS; then
        check_pass "ЗЭП.5.1" "Настроен спам-фильтр и механизмы Black/White списков отправителей"
    elif $SPAM_FILTER; then
        check_fail "ЗЭП.5.1" "Спам-фильтр есть, но не обнаружены механизмы Black/White списков отправителей (IP/домены)"
    else
        check_fail "ЗЭП.5.1" "Не обнаружен активный спам-фильтр и списки отправителей"
    fi

    # --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
    if fstek_enhancement_enabled "ЗЭП.5" "1"; then
        # ЗЭП.5.2 (Усиление 2) - Ограничение количества сообщений от одного отправителя (Rate Limit)
        RATE_LIMIT=$(postconf -h smtpd_client_message_rate_limit 2>/dev/null)
        if [ -n "$RATE_LIMIT" ] && [ "$RATE_LIMIT" != "0" ] && [ "$RATE_LIMIT" != " " ]; then
            check_pass "ЗЭП.5.2" "Установлено ограничение частоты сообщений от одного отправителя (Rate Limit = $RATE_LIMIT)"
        else
            check_fail "ЗЭП.5.2" "Не установлено ограничение на частоту сообщений (Rate Limit)"
        fi

        # ЗЭП.5.3 (Усиление 1) - Репутационная фильтрация отправителей
        check_skip "ЗЭП.5.3" "Репутационная фильтрация отправителей"

        # ЗЭП.5.4 (Усиление 3) - Технологии однозначной верификации адресов
        check_skip "ЗЭП.5.4" "Технологии однозначной верификации адресов (пересекается с ЗЭП.4)"
    else
        # Унифицированный вывод для отключенных усилений
        skip_enhancement "ЗЭП.5.2-4"
    fi

    # Унифицированная итоговая строка
    finish_legacy_measure "ЗЭП.5"
}
