#!/bin/bash
# check_zep1.sh - Защита ящиков и сообщений электронной почты (ЗЭП.1)
# Соответствие разделу 4.6 (ЗЭП.1) Методического документа ФСТЭК России от 12.04.2026

WITH_ENHANCEMENTS=false
[[ "$1" == "--with-enhancements" || "$1" == "-e" ]] && WITH_ENHANCEMENTS=true

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

# --- ПРОВЕРКА НАЛИЧИЯ ПОЧТОВОГО СЕРВЕРА ---
# Если почтовый сервер не установлен, проверка ЗЭП.1 пропускается
if ! command -v postconf &>/dev/null && ! systemctl list-units --all 2>/dev/null | grep -qE "postfix|dovecot|exim|sendmail"; then
    check_skip "ЗЭП.1" "Почтовый сервер не обнаружен. Проверка ЗЭП.1 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗЭП.1: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗЭП.1.1 - Регистрация событий безопасности (РСБ.1-РСБ.5)
if journalctl -u postfix -n 1 --no-pager &>/dev/null || [ -f /var/log/maillog ] || [ -f /var/log/mail.log ]; then
    check_pass "ЗЭП.1.1" "Регистрация событий безопасности почтового сервера настроена"
else
    check_fail "ЗЭП.1.1" "Не обнаружено логирование событий почтового сервера"
fi

# ЗЭП.1.2 - Организационная мера (аудит ящиков)
check_skip "ЗЭП.1.2" "Периодический анализ (аудит) ящиков на наличие подлежащих удалению"

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if $WITH_ENHANCEMENTS; then
    # ЗЭП.1.3 (Усиление 1) - Автоблокирование неактивных ящиков
    if grep -rq "plugin.*expire" /etc/dovecot/ 2>/dev/null || \
       crontab -l 2>/dev/null | grep -qiE "inactive.*mail|disable.*user|doveadm.*kick" 2>/dev/null; then
        check_pass "ЗЭП.1.3" "Настроено автоблокирование/удаление неактивных ящиков"
    else
        check_skip "ЗЭП.1.3" "Автоблокировка неактивных ящиков не обнаружена (проверьте AD/LDAP политики или cron-задачи)"
    fi

    # ЗЭП.1.4 (Усиление 2) - Резервное копирование ящиков
    if crontab -l 2>/dev/null | grep -qiE "backup.*mail|doveadm.*backup|rsync.*maildir" || \
       [ -f /etc/cron.d/mail_backup ]; then
        check_pass "ЗЭП.1.4" "Настроено периодическое резервное копирование ящиков"
    else
        check_fail "ЗЭП.1.4" "Не обнаружены задачи резервного копирования ящиков (cron)"
    fi
else
    # Унифицированный вывод для отключенных усилений
    echo "[ЗЭП.1.3-4] SKIP – проверка усилений отключена"
    ((SKIP_COUNT+=2))
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗЭП.1: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1