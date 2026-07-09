#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zep6.sh - Защита метаданных и иной технической информации сервисов электронной почты (ЗЭП.6)
# Соответствие разделу 4.6 (ЗЭП.6) Методического документа ФСТЭК России от 12.04.2026

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода

# --- ПРОВЕРКА НАЛИЧИЯ ПОЧТОВОГО СЕРВЕРА ---
# Если почтовый сервер не установлен, проверка ЗЭП.5 пропускается
if ! command -v postconf &>/dev/null && ! systemctl list-units --all | grep -qE "postfix|dovecot|exim|sendmail"; then
    check_skip "ЗЭП.6" "Почтовый сервер не обнаружен. Проверка ЗЭП.6 пропущена."
    finish_legacy_measure "ЗЭП.6"
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗЭП.6.1 - Сокрытие служебных заголовков (X-Mailer, User-Agent, X-Originating-IP, Message-ID)
HEADER_CHECKS="$(postconf -h header_checks 2>/dev/null; postconf -h smtp_header_checks 2>/dev/null; postconf -h mime_header_checks 2>/dev/null)"
HIDE_MASK="X-Mailer|User-Agent|X-Originating-IP|Message-ID"
HIDE_FOUND=false

if [ -n "$HEADER_CHECKS" ]; then
    while read -r map; do
        HEADER_FILE="${map#*:}"
        HEADER_FILE="${HEADER_FILE%%,*}"
        if [ -f "$HEADER_FILE" ] && grep -qE "^[^#].*($HIDE_MASK).*(IGNORE|REPLACE|DISCARD|PREPEND|WARN)" "$HEADER_FILE" 2>/dev/null; then
            HIDE_FOUND=true
            break
        fi
    done < <(echo "$HEADER_CHECKS" | tr ', ' '\n' | grep -E '^(regexp|pcre|hash|texthash):/')
fi

if $HIDE_FOUND; then
    check_pass "ЗЭП.6.1" "Настроено сокрытие метаданных (X-Mailer, User-Agent, X-Originating-IP, Message-ID)"
else
    check_fail "ЗЭП.6.1" "Не найдены правила сокрытия служебных заголовков"
fi

# ЗЭП.6.2 - Запрет команд VRFY / EXPN
VRFY_STATUS=$(postconf -h disable_vrfy_command 2>/dev/null)
if [ "$VRFY_STATUS" == "yes" ]; then
    check_pass "ЗЭП.6.2" "Исключена возможность перечисления ящиков (disable_vrfy_command = yes)"
else
    check_fail "ЗЭП.6.2" "Команды VRFY/EXPN не отключены"
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if fstek_enhancement_enabled "ЗЭП.6" "1"; then
    # ЗЭП.6.3 (Усиление 1) - Запрет ретрансляции для других ИС/доменов (Open Relay)
    RELAY_RESTRICT=$(postconf -h smtpd_relay_restrictions 2>/dev/null)
    RELAY_DOMAINS=$(postconf -h relay_domains 2>/dev/null)
    
    if echo "$RELAY_RESTRICT" | grep -q "reject_unauth_destination" && \
       ([ -z "$RELAY_DOMAINS" ] || [ "$RELAY_DOMAINS" == " " ]); then
        check_pass "ЗЭП.6.3" "Сервер не поддерживает ретрансляцию трафика для других ИС/доменов (Open Relay закрыт)"
    else
        check_fail "ЗЭП.6.3" "Обнаружена возможность ретрансляции трафика для сторонних доменов (Open Relay)"
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "ЗЭП.6.3"
fi

# Унифицированная итоговая строка
finish_legacy_measure "ЗЭП.6"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
