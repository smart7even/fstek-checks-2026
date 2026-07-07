#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zep4.sh - Защита от фишинга (ЗЭП.4)
# Соответствие разделу 4.6 (ЗЭП.4) Методического документа ФСТЭК России от 12.04.2026

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода
check_pass() { fstek_status_line "$1" "PASS" "$2"; }
check_fail() { fstek_status_line "$1" "FAIL" "$2"; ((FAIL_COUNT++)); }
check_skip() { fstek_status_line "$1" "SKIP" "$2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

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
if fstek_enhancement_enabled "ЗЭП.4" "4"; then
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
else
    skip_enhancement "ЗЭП.4.4"
fi

if fstek_enhancement_enabled "ЗЭП.4" "1"; then
    # ЗЭП.4.5 (Усиление 1) - Блокирование/карантин для фишинговых сообщений
    check_skip "ЗЭП.4.5" "Блокирование/карантин для фишинговых сообщений (настраивается в СЗИ)"
else
    skip_enhancement "ЗЭП.4.5"
fi

if fstek_enhancement_enabled "ЗЭП.4" "2" "3"; then
    # ЗЭП.4.6 (Усиления 2, 3) - Репутационная фильтрация и песочница для фишинга
    check_skip "ЗЭП.4.6" "Репутационная фильтрация и песочница для фишинга"
else
    skip_enhancement "ЗЭП.4.6"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗЭП.4: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
