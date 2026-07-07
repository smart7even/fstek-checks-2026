#!/bin/bash
# check_zep2.sh - Управление доступом пользователей (ЗЭП.2)
# Соответствие разделу 4.6 (ЗЭП.2) Методического документа ФСТЭК России от 12.04.2026

WITH_ENHANCEMENTS=false
[[ "$1" == "--with-enhancements" || "$1" == "-e" ]] && WITH_ENHANCEMENTS=true

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

# --- ПРОВЕРКА НАЛИЧИЯ ПОЧТОВОГО СЕРВЕРА ---
# Если почтовый сервер не установлен, проверка ЗЭП.2 пропускается
if ! command -v postconf &>/dev/null && ! systemctl list-units --all 2>/dev/null | grep -qE "postfix|dovecot|exim|sendmail"; then
    check_skip "ЗЭП.2" "Почтовый сервер не обнаружен. Проверка ЗЭП.2 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗЭП.2: FAIL=0, SKIP=1 ==="
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
echo "=== ИТОГ МОДУЛЯ ЗЭП.2: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1