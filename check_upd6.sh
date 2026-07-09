#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# Модуль проверки УПД.6 - Оповещение о предыдущем входе
WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# УПД.6.1 – pam_lastlog / pam_lastlog2 в PAM
LASTLOG_CONFIGURED=false
for pfile in /etc/pam.d/login /etc/pam.d/system-auth /etc/pam.d/common-session; do
    # ИСПРАВЛЕНИЕ: Добавлена проверка pam_lastlog2.so, так как pam_lastlog.so устарел 
    # в современных версиях Astra Linux, ALT Linux и RedOS.
    if [ -f "$pfile" ] && grep -qE "pam_lastlog\.so|pam_lastlog2\.so" "$pfile"; then
        LASTLOG_CONFIGURED=true
        break
    fi
done

if $LASTLOG_CONFIGURED; then
    check_pass "УПД.6.1" "Модуль оповещения о последнем входе (pam_lastlog/pam_lastlog2) настроен в PAM"
else
    check_fail "УПД.6.1" "Модуль оповещения о последнем входе (pam_lastlog/pam_lastlog2) не настроен в PAM"
fi

# УПД.6.2 – PrintLastLog в SSH
if [ -f /etc/ssh/sshd_config ]; then
    PRINT_LAST=$(grep -E "^PrintLastLog" /etc/ssh/sshd_config | awk '{print $2}')
    if [ "$PRINT_LAST" = "yes" ]; then
        check_pass "УПД.6.2" "SSH PrintLastLog включен (оповещение при входе по SSH)"
    else
        check_fail "УПД.6.2" "SSH PrintLastLog отключен или не настроен"
    fi
else
    check_fail "УПД.6.2" "Файл /etc/ssh/sshd_config отсутствует"
fi

# УПД.6.3 – Журнал lastlog
if [ -f /var/log/lastlog ] && [ -s /var/log/lastlog ]; then
    LASTLOG_SIZE=$(du -h /var/log/lastlog | awk '{print $1}')
    check_pass "УПД.6.3" "Журнал /var/log/lastlog существует и не пуст ($LASTLOG_SIZE)"
else
    check_fail "УПД.6.3" "Журнал /var/log/lastlog отсутствует или пуст"
fi

# УПД.6.4 – Усиление: Оповещение о неуспешных попытках
if fstek_enhancement_enabled "УПД.6" "1"; then
    FAIL_NOTIFY=false
    for pfile in /etc/pam.d/system-auth /etc/pam.d/common-auth; do
        if [ -f "$pfile" ] && grep -qE "pam_faillock|pam_tally2" "$pfile"; then
            FAIL_NOTIFY=true
            break
        fi
    done
    if [ -f /var/log/faillog ]; then FAIL_NOTIFY=true; fi
    
    if $FAIL_NOTIFY; then
        check_pass "УПД.6.4" "Оповещение о неуспешных попытках входа настроено"
    else
        check_fail "УПД.6.4" "Оповещение о неуспешных попытках входа не настроено"
    fi
else
    skip_enhancement "УПД.6.4"
fi

# УПД.6.5 – Усиление (п.6): Оповещение по альтернативным каналам связи (Email/SMS/Push)
if fstek_enhancement_enabled "УПД.6" "1"; then
    # Локальная проверка ОС не может гарантировать отправку писем/SMS.
    # Это настраивается на уровне SIEM, IDM (FreeIPA/AD) или почтового реле.
    # Мы проверяем косвенный признак: настроен ли SSSD на чтение email-атрибутов из каталога.
    SSSD_EMAIL=false
    if [ -f /etc/sssd/sssd.conf ] && grep -qE "ldap_user_email|krb5_email" /etc/sssd/sssd.conf 2>/dev/null; then
        SSSD_EMAIL=true
    fi
    
    if $SSSD_EMAIL; then
        check_pass "УПД.6.5" "SSSD настроен на чтение email-атрибутов из каталога (база для альтернативного оповещения)"
    else
        # Если интеграции нет, мы не ставим FAIL, а уходим в SKIP с понятным комментарием для аттестатора
        check_skip "УПД.6.5" "Оповещение по альтернативным каналам (Email/SMS) требует ручной проверки настроек SIEM/почтового шлюза"
    fi
else
    skip_enhancement "УПД.6.5"
fi

finish_legacy_measure "УПД.6"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1