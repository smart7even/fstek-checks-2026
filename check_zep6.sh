#!/bin/bash
# check_zep6.sh - Защита метаданных и иной технической информации сервисов электронной почты (ЗЭП.6)
# Соответствие разделу 4.6 (ЗЭП.6) Методического документа ФСТЭК России от 12.04.2026

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
    check_skip "ЗЭП.6" "Почтовый сервер не обнаружен. Проверка ЗЭП.6 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗЭП.6: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗЭП.6.1 - Сокрытие служебных заголовков (X-Mailer, User-Agent, X-Originating-IP, Message-ID)
HEADER_CHECKS=$(postconf -h header_checks 2>/dev/null)
HIDE_MASK="X-Mailer|User-Agent|X-Originating-IP|Message-ID"
HIDE_FOUND=false

if [ -n "$HEADER_CHECKS" ] && [ "$HEADER_CHECKS" != " " ]; then
    HEADER_FILE=$(echo "$HEADER_CHECKS" | awk '{print $2}')
    if [ -f "$HEADER_FILE" ] && grep -qE "$HIDE_MASK" "$HEADER_FILE" 2>/dev/null; then
        HIDE_FOUND=true
    fi
fi

# Альтернатива: проверка через milter
if ! $HIDE_FOUND && [ -n "$(postconf -h smtpd_milters 2>/dev/null)" ]; then 
    HIDE_FOUND=true
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
if $WITH_ENHANCEMENTS; then
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
    echo "[ЗЭП.6.3] SKIP – проверка усилений отключена"
    ((SKIP_COUNT++))
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗЭП.6: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1