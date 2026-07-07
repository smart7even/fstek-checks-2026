#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# Модуль проверки УПД.4 - Ограничение неуспешных попыток доступа

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

check_pass() { fstek_status_line "$1" "PASS" "$2"; }
check_fail() { fstek_status_line "$1" "FAIL" "$2"; ((FAIL_COUNT++)); }
check_info() { echo "[$1] INFO – $2"; }

FAIL_COUNT=0

# УПД.4.1 – pam_faillock (deny=5, unlock_time=900)
FAILLOCK_CONFIGURED=false

if [ -f /etc/security/faillock.conf ]; then
    DENY=$(grep -E "^deny" /etc/security/faillock.conf | awk -F'=' '{print $2}' | tr -d ' ')
    UNLOCK=$(grep -E "^unlock_time" /etc/security/faillock.conf | awk -F'=' '{print $2}' | tr -d ' ')
    
    if [ "$DENY" = "5" ] && [ "$UNLOCK" = "900" ]; then
        FAILLOCK_CONFIGURED=true
    fi
fi

# Проверяем также в PAM файлах
if ! $FAILLOCK_CONFIGURED; then
    for pfile in /etc/pam.d/system-auth /etc/pam.d/common-auth /etc/pam.d/password-auth; do
        if [ -f "$pfile" ] && grep -qE "pam_faillock\.so.*deny=5" "$pfile"; then
            FAILLOCK_CONFIGURED=true
            break
        fi
    done
fi

if $FAILLOCK_CONFIGURED; then
    check_pass "УПД.4.1" "pam_faillock настроен: 5 попыток, блокировка 900 секунд"
else
    check_fail "УПД.4.1" "pam_faillock не настроен согласно требованиям (deny=5, unlock_time=900)"
fi

# УПД.4.2 – pam_tally2 (для старых систем) – информационно
TALLY2_CONFIGURED=false
for pfile in /etc/pam.d/system-auth /etc/pam.d/common-auth; do
    if [ -f "$pfile" ] && grep -qE "pam_tally2\.so.*deny=5" "$pfile"; then
        TALLY2_CONFIGURED=true
        break
    fi
done

if $TALLY2_CONFIGURED; then
    check_info "УПД.4.2" "pam_tally2 настроен как альтернатива pam_faillock"
else
    check_info "УПД.4.2" "pam_tally2 не используется (используется pam_faillock)"
fi

# УПД.4.3 – fail2ban (НЕ ЯВЛЯЕТСЯ ОБЯЗАТЕЛЬНЫМ ПО МЕТОДИКЕ) – только информационно
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    JAILS=$(fail2ban-client status 2>/dev/null | grep -c "Jail list:" || echo "0")
    if [ "$JAILS" -gt 0 ]; then
        check_info "УПД.4.3" "fail2ban активен, настроено $JAILS jails для блокировки по IP (дополнительная мера)"
    else
        check_info "УПД.4.3" "fail2ban активен, но jails не настроены (дополнительная мера)"
    fi
else
    check_info "УПД.4.3" "fail2ban не установлен или не активен (не является обязательным по методике)"
fi

# УПД.4.4 – Усиление: Автоматическое удаление временных УЗ
if fstek_enhancement_enabled "УПД.4" "1" "2"; then
    # Проверяем наличие cron-задач для удаления временных УЗ
    CRON_TASKS=$(grep -rE "userdel|chage.*-E" /etc/cron.* 2>/dev/null | wc -l)
    
    # Проверяем systemd timers
    SYSTEMD_TIMERS=$(systemctl list-timers --all 2>/dev/null | grep -cE "user|account" || echo "0")
    
    if [ "$CRON_TASKS" -gt 0 ] || [ "$SYSTEMD_TIMERS" -gt 0 ]; then
        check_pass "УПД.4.4" "Автоматическое удаление временных УЗ настроено (cron: $CRON_TASKS, timers: $SYSTEMD_TIMERS)"
    else
        check_fail "УПД.4.4" "Автоматическое удаление временных УЗ не настроено"
    fi
else
    skip_enhancement "УПД.4.4"
fi

echo "=== ИТОГ МОДУЛЯ УПД.4: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1