#!/bin/bash
# check_zep3.sh - Защита от вредоносных вложений (ЗЭП.3)
# Соответствие разделу 4.6 (ЗЭП.3) Методического документа ФСТЭК России от 12.04.2026

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
    check_skip "ЗЭП.3" "Почтовый сервер не обнаружен. Проверка ЗЭП.3 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗЭП.3: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗЭП.3.1 - Антивирусная защита (АВЗ.2)
CONTENT_FILTER=$(postconf -h content_filter 2>/dev/null)
MILTERS=$(postconf -h smtpd_milters 2>/dev/null)
if [ -n "$CONTENT_FILTER" ] || [ -n "$MILTERS" ]; then
    check_pass "ЗЭП.3.1" "Настроен контент-фильтр или milter (Антивирусная защита)"
else
    check_fail "ЗЭП.3.1" "Не обнаружен контент-фильтр или milter для AV-проверки"
fi

# ЗЭП.3.2 - Блокирование неразрешенных форматов
if grep -rqE "header_checks|mime_header_checks|body_checks" /etc/postfix/main.cf 2>/dev/null; then
    check_pass "ЗЭП.3.2" "Настроены правила фильтрации/блокировки форматов вложений (header/body_checks)"
else
    check_fail "ЗЭП.3.2" "Не найдены правила блокировки неразрешенных форматов файлов"
fi

# ЗЭП.3.3 - Контроль вложений с использованием IOCs
check_skip "ЗЭП.3.3" "Контроль вложений с использованием индикаторов компрометации (IOCs)"

# ЗЭП.3.4 - Возможность ретроспективного анализа вложений
check_skip "ЗЭП.3.4" "Возможность ретроспективного анализа вложений"

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if $WITH_ENHANCEMENTS; then
    # ЗЭП.3.5 (Усиление 1) - Песочница (замкнутая среда предварительного выполнения)
    if grep -rqE "icap|c-icap|sandbox|vadesecure|kaspersky.*sandbox" /etc/postfix/ /etc/rspamd/ /etc/c-icap/ 2>/dev/null; then
        check_pass "ЗЭП.3.5" "Обнаружена интеграция с замкнутой средой (песочницей) для анализа вложений"
    else
        check_fail "ЗЭП.3.5" "Не обнаружена интеграция с замкнутой средой (песочницей) для динамического анализа"
    fi

    # ЗЭП.3.6 (Усиление 2) - Блокировка запароленных архивов
    if grep -rqE "ArchiveMaxEncrypted|encrypted.*archive|password.*protected" /etc/clamav/ /etc/rspamd/ /etc/amavis/ 2>/dev/null; then
        check_pass "ЗЭП.3.6" "Настроено блокирование запароленных архивов до проверки"
    else
        check_fail "ЗЭП.3.6" "Не настроено блокирование запароленных архивов"
    fi
else
    # Унифицированный вывод для отключенных усилений
    echo "[ЗЭП.3.5-6] SKIP – проверка усилений отключена"
    ((SKIP_COUNT+=2))
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗЭП.3: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1