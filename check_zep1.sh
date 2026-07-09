#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zep1.sh - Защита ящиков и сообщений электронной почты (ЗЭП.1)
# Соответствие разделу 4.6 (ЗЭП.1) Методического документа ФСТЭК России от 12.04.2026

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
# Если почтовый сервер не установлен, проверка ЗЭП.1 пропускается
if ! command -v postconf &>/dev/null && ! systemctl list-units --all 2>/dev/null | grep -qE "postfix|dovecot|exim|sendmail"; then
    check_skip "ЗЭП.1" "Почтовый сервер не обнаружен. Проверка ЗЭП.1 пропущена."
    finish_legacy_measure "ЗЭП.1"
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
if fstek_enhancement_enabled "ЗЭП.1" "1"; then
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
    skip_enhancement "ЗЭП.1.3-4"
fi

# Унифицированная итоговая строка
finish_legacy_measure "ЗЭП.1"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1