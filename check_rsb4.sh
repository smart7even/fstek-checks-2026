#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_rsb4.sh - РСБ.4 Сбор, хранение и защита логов

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода

# РСБ.4.1 – Защита от НСД (Права и Владелец)
SECURE_LOG="/var/log/secure"
[ -f /var/log/auth.log ] && SECURE_LOG="/var/log/auth.log"
AUDIT_LOG="/var/log/audit/audit.log"

PERM_OK=true
for log in "$SECURE_LOG" "$AUDIT_LOG"; do
    if [ -f "$log" ]; then
        PERM=$(stat -c %a "$log")
        OWNER=$(stat -c %U "$log")
        # Права должны быть 600 или 640, владелец - root (или syslog/adm для Debian-подобных)
        if [[ "$PERM" != "600" && "$PERM" != "640" ]] || [[ "$OWNER" != "root" && "$OWNER" != "syslog" ]]; then
            PERM_OK=false
            check_fail "РСБ.4.1" "Нарушение для $log: права=$PERM, владелец=$OWNER"
        fi
    fi
done
if $PERM_OK; then 
    check_pass "РСБ.4.1" "Права (600/640) и владелец (root/syslog) для журналов корректны"
fi

# РСБ.4.2 – Ротация и сроки хранения
if [ -d /etc/logrotate.d ]; then
    # Проверяем, не удаляются ли критические логи сразу (rotate 0)
    if grep -rE "rotate\s+0" /etc/logrotate.d/ 2>/dev/null | grep -qE "secure|auth|audit|syslog"; then
        check_fail "РСБ.4.2" "Обнаружено удаление критических логов без хранения (rotate 0)"
    elif grep -rq "/var/log" /etc/logrotate.conf /etc/logrotate.d/* 2>/dev/null; then
        check_pass "РСБ.4.2" "Настроена ротация и хранение журналов (logrotate)"
    else
        check_fail "РСБ.4.2" "Ротация журналов (logrotate) не настроена"
    fi
else 
    check_fail "РСБ.4.2" "Директория /etc/logrotate.d не найдена"
fi

if fstek_enhancement_enabled "РСБ.4" "1"; then
    # РСБ.4.3 (Усиление 4) – Резервное копирование
    if grep -rqE "/var/log|audit" /etc/cron.* /var/spool/cron/ 2>/dev/null; then
        check_pass "РСБ.4.3" "Обнаружены задачи cron для резервного копирования логов"
    else 
        check_fail "РСБ.4.3" "Автоматическое резервное копирование журналов не настроено"
    fi
    
    # РСБ.4.4 (Усиление 5) – Защита целостности (Crypto / TLS)
    if dpkg -l 2>/dev/null | grep -q "rsyslog-gnutls" || rpm -qa 2>/dev/null | grep -q "rsyslog-gnutls" || grep -qE "StreamDriver|gtls" /etc/rsyslog.conf /etc/rsyslog.d/*.conf 2>/dev/null; then
        check_pass "РСБ.4.4" "Используется TLS для защиты логов при передаче"
    else 
        check_fail "РСБ.4.4" "Криптографическая защита логов (TLS) не обнаружена"
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "РСБ.4.3-4"
fi

# Унифицированная итоговая строка
finish_legacy_measure "РСБ.4"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1