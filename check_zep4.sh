#!/bin/bash
# check_zep4.sh - Защита от фишинга (ЗЭП.4)
# Соответствие разделу 4.6 (ЗЭП.4) Методического документа ФСТЭК России от 12.04.2026

WITH_ENHANCEMENTS=false
[[ "$1" == "--with-enhancements" || "$1" == "-e" ]] && WITH_ENHANCEMENTS=true

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

# --- ПРОВЕРКА НАЛИЧИЯ ПОЧТОВОГО СЕРВЕРА ---
# Если почтовый сервер не установлен, проверка ЗЭП.5 пропускается
if ! command -v postconf &>/dev/null && ! systemctl list-units --all | grep -qE "postfix|dovecot|exim|sendmail"; then
    check_skip "ЗЭП.4" "Почтовый сервер не обнаружен. Проверка ЗЭП.4 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗЭП.4: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗЭП.4.1, ЗЭП.4.2 - Фильтрация по спискам отправителей и репутации
FILTER_LISTS=false
if grep -rqE "check_client_access|check_sender_access" /etc/postfix/main.cf 2>/dev/null; then
    FILTER_LISTS=true
fi
if grep -rqE "blacklist|whitelist|multimap|surbl|uribl" /etc/rspamd/ /etc/spamassassin/ 2>/dev/null; then
    FILTER_LISTS=true
fi

if $FILTER_LISTS; then
    check_pass "ЗЭП.4.1" "Механизмы фильтрации по спискам отправителей и репутации настроены"
else
    check_fail "ЗЭП.4.1" "Не обнаружены механизмы фильтрации по спискам отправителей и репутации"
fi

# ЗЭП.4.2 - Контроль текста и ссылок на наличие фишинговых элементов
check_skip "ЗЭП.4.2" "Контроль текста и ссылок на наличие фишинговых элементов (требует анализа СЗИ)"

# ЗЭП.4.3 - Ретроспективный анализ сообщений на наличие фишинга
check_skip "ЗЭП.4.3" "Ретроспективный анализ сообщений на наличие фишинга"

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if $WITH_ENHANCEMENTS; then
    # ЗЭП.4.4 (Усиление 4) - Верификация адресов (SPF/DKIM/DMARC)
    SPF_CHECK=$(grep -rqE "check_policy_service.*spf|pypolicyd-spf" /etc/postfix/ 2>/dev/null && echo "yes" || echo "no")
    DKIM_CHECK="no"
    if [ -f /etc/opendkim/opendkim.conf ] || grep -rq "dkim" /etc/rspamd/ 2>/dev/null; then
        DKIM_CHECK="yes"
    fi
    
    if [ "$SPF_CHECK" == "yes" ] || [ "$DKIM_CHECK" == "yes" ]; then
        check_pass "ЗЭП.4.4" "Настроена верификация адресов (SPF/DKIM/DMARC) для защиты от подделки"
    else
        check_fail "ЗЭП.4.4" "Не настроена верификация адресов отправителей (SPF/DKIM/DMARC)"
    fi

    # ЗЭП.4.5 (Усиление 1) - Блокирование/карантин для фишинговых сообщений
    check_skip "ЗЭП.4.5" "Блокирование/карантин для фишинговых сообщений (настраивается в СЗИ)"

    # ЗЭП.4.6 (Усиления 2, 3) - Репутационная фильтрация и песочница для фишинга
    check_skip "ЗЭП.4.6" "Репутационная фильтрация и песочница для фишинга"
else
    # Унифицированный вывод для отключенных усилений
    echo "[ЗЭП.4.4-6] SKIP – проверка усилений отключена"
    ((SKIP_COUNT+=3))
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗЭП.4: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1