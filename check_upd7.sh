#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# Модуль проверки УПД.7 - Ограничение параллельных сеансов

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0

# УПД.7.1 – limits.conf (maxlogins)
LIMITS_CONFIGURED=false
if [ -f /etc/security/limits.conf ]; then
    MAXLOGINS=$(grep -E "^\*.*maxlogins" /etc/security/limits.conf | awk '{print $NF}')
    if [[ "$MAXLOGINS" =~ ^[0-9]+$ ]] && [ "$MAXLOGINS" -gt 0 ]; then
        LIMITS_CONFIGURED=true
        check_pass "УПД.7.1" "limits.conf: maxlogins=$MAXLOGINS для всех пользователей"
    fi
fi

# Проверяем также в /etc/security/limits.d/
if ! $LIMITS_CONFIGURED && [ -d /etc/security/limits.d ]; then
    for limit_file in /etc/security/limits.d/*.conf; do
        if [ -f "$limit_file" ] && grep -qE "maxlogins" "$limit_file"; then
            LIMITS_CONFIGURED=true
            break
        fi
    done
fi

if ! $LIMITS_CONFIGURED; then
    check_fail "УПД.7.1" "maxlogins не настроен в limits.conf или limits.d"
fi

# УПД.7.2 – pam_limits в PAM
PAM_LIMITS=false
for pfile in /etc/pam.d/common-session /etc/pam.d/system-auth /etc/pam.d/login; do
    if [ -f "$pfile" ] && grep -qE "pam_limits\.so" "$pfile"; then
        PAM_LIMITS=true
        break
    fi
done

if $PAM_LIMITS; then
    check_pass "УПД.7.2" "pam_limits настроен в PAM (ограничения сеансов активны)"
else
    check_fail "УПД.7.2" "pam_limits не настроен в PAM"
fi

# УПД.7.3 – systemd-logind
if [ -f /etc/systemd/logind.conf ]; then
    KILL_PROCESSES=$(grep -E "^KillUserProcesses" /etc/systemd/logind.conf | awk -F'=' '{print $2}' | tr -d ' ')
    if [ "$KILL_PROCESSES" = "yes" ]; then
        check_pass "УПД.7.3" "systemd-logind: KillUserProcesses=yes (завершение процессов при выходе)"
    else
        check_fail "УПД.7.3" "systemd-logind: KillUserProcesses не включен"
    fi
else
    check_fail "УПД.7.3" "Файл /etc/systemd/logind.conf отсутствует"
fi

# УПД.7.4 – Усиление: Ограничение для привилегированных пользователей
if fstek_enhancement_enabled "УПД.7" "1a"; then
    ADMIN_LIMITS=0
    # Проверяем ограничения для root и администраторов
    if [ -f /etc/security/limits.conf ]; then
        ROOT_MAX=$(grep -E "^root.*maxlogins" /etc/security/limits.conf | awk '{print $NF}')
        if [[ "$ROOT_MAX" =~ ^[0-9]+$ ]] && [ "$ROOT_MAX" -le 2 ]; then
            ((ADMIN_LIMITS++))
        fi
        
        # Проверяем группы администраторов
        ADMIN_GROUPS=$(grep -E "^@admin.*maxlogins|^@wheel.*maxlogins" /etc/security/limits.conf | wc -l)
        ADMIN_LIMITS=$((ADMIN_LIMITS + ADMIN_GROUPS))
    fi
    
    if [ "$ADMIN_LIMITS" -gt 0 ]; then
        check_pass "УПД.7.4" "Ограничения для привилегированных пользователей настроены ($ADMIN_LIMITS правил)"
    else
        check_fail "УПД.7.4" "Ограничения для привилегированных пользователей не настроены"
    fi
else
    skip_enhancement "УПД.7.4"
fi

finish_legacy_measure "УПД.7"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1