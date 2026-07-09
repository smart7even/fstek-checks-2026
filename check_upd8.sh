#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# Модуль проверки УПД.8 - Блокирование сеанса при неактивности

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0

# УПД.8.1 – TMOUT в shell
TMOUT_CONFIGURED=false
for profile in /etc/profile /etc/profile.d/*.sh /etc/bash.bashrc; do
    if [ -f "$profile" ] && grep -qE "(readonly|export)?[[:space:]]*TMOUT=[0-9]+" "$profile"; then
        TMOUT_VALUE=$(grep -E "TMOUT=[0-9]+" "$profile" | head -1 | grep -oE "[0-9]+")
        if [ "$TMOUT_VALUE" -gt 0 ] && [ "$TMOUT_VALUE" -le 900 ]; then
            TMOUT_CONFIGURED=true
            check_pass "УПД.8.1" "TMOUT настроен в $profile: $TMOUT_VALUE секунд"
            break
        fi
    fi
done

if ! $TMOUT_CONFIGURED; then
    check_fail "УПД.8.1" "TMOUT не настроен или значение > 900 секунд"
fi

# УПД.8.1a – Неактивность SSH-сессий
SSH_IDLE_CONFIGURED=false
for ssh_cfg in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf; do
    if [ -f "$ssh_cfg" ]; then
        CLIENT_ALIVE=$(awk '$1 == "ClientAliveInterval" {print $2}' "$ssh_cfg" | tail -1)
        CLIENT_COUNT=$(awk '$1 == "ClientAliveCountMax" {print $2}' "$ssh_cfg" | tail -1)
        if [[ "$CLIENT_ALIVE" =~ ^[0-9]+$ ]] && [ "$CLIENT_ALIVE" -gt 0 ] && [ "$CLIENT_ALIVE" -le 900 ]; then
            if [ -z "$CLIENT_COUNT" ] || ! [[ "$CLIENT_COUNT" =~ ^[0-9]+$ ]] || [ "$CLIENT_COUNT" -le 3 ]; then
                SSH_IDLE_CONFIGURED=true
                check_pass "УПД.8.1a" "SSH ClientAliveInterval настроен в $ssh_cfg: ${CLIENT_ALIVE}s"
                break
            fi
        fi
    fi
done

if ! $SSH_IDLE_CONFIGURED; then
    check_fail "УПД.8.1a" "Не настроено ограничение неактивности SSH-сессий (ClientAliveInterval <= 900)"
fi

# УПД.8.2 – Screensaver (автоблокировка экрана)
SCREENSAVER_CONFIGURED=false

# Проверяем X11 (xscreensaver, gnome-screensaver)
if command -v xset &>/dev/null; then
    XSET_TIMEOUT=$(xset q 2>/dev/null | grep -A 1 "Screen Saver" | grep -oE "timeout:.*[0-9]+" | grep -oE "[0-9]+")
    if [[ "$XSET_TIMEOUT" =~ ^[0-9]+$ ]] && [ "$XSET_TIMEOUT" -gt 0 ]; then
        SCREENSAVER_CONFIGURED=true
    fi
fi

# Проверяем dconf (GNOME)
if command -v dconf &>/dev/null; then
    IDLE_DELAY=$(dconf read /org/gnome/desktop/session/idle-delay 2>/dev/null | tr -d 'uint32')
    if [[ "$IDLE_DELAY" =~ ^[0-9]+$ ]] && [ "$IDLE_DELAY" -gt 0 ]; then
        SCREENSAVER_CONFIGURED=true
    fi
fi

if $SCREENSAVER_CONFIGURED; then
    check_pass "УПД.8.2" "Screensaver настроен (автоблокировка экрана активна)"
else
    echo "[УПД.8.2] INFO – Графическая оболочка не используется или screensaver не настроен"
fi

# УПД.8.3 – systemd-logind (IdleAction)
if [ -f /etc/systemd/logind.conf ]; then
    IDLE_ACTION=$(grep -E "^IdleAction" /etc/systemd/logind.conf | awk -F'=' '{print $2}' | tr -d ' ')
    IDLE_SEC=$(grep -E "^IdleActionSec" /etc/systemd/logind.conf | awk -F'=' '{print $2}' | tr -d ' ')
    
    if [ -n "$IDLE_ACTION" ] && [ "$IDLE_ACTION" != "ignore" ]; then
        check_pass "УПД.8.3" "systemd-logind: IdleAction=$IDLE_ACTION, IdleActionSec=$IDLE_SEC"
    else
        check_fail "УПД.8.3" "systemd-logind: IdleAction не настроен или равен ignore"
    fi
else
    check_fail "УПД.8.3" "Файл /etc/systemd/logind.conf отсутствует"
fi

# УПД.8.4 – Усиление: Автоматическое завершение сеанса
if fstek_enhancement_enabled "УПД.8" "1"; then
    AUTO_LOGOUT=false
    
    # Проверяем TMOUT с export
    for profile in /etc/profile /etc/profile.d/*.sh; do
        if [ -f "$profile" ] && grep -qE "export TMOUT|readonly TMOUT" "$profile"; then
            AUTO_LOGOUT=true
            break
        fi
    done
    
    # Проверяем systemd-logind KillUserProcesses
    if [ -f /etc/systemd/logind.conf ]; then
        KILL_PROCESSES=$(grep -E "^KillUserProcesses" /etc/systemd/logind.conf | awk -F'=' '{print $2}' | tr -d ' ')
        if [ "$KILL_PROCESSES" = "yes" ]; then
            AUTO_LOGOUT=true
        fi
    fi
    
    if $AUTO_LOGOUT; then
        check_pass "УПД.8.4" "Автоматическое завершение сеанса настроено"
    else
        check_fail "УПД.8.4" "Автоматическое завершение сеанса не настроено"
    fi
else
    skip_enhancement "УПД.8.4"
fi

finish_legacy_measure "УПД.8"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
