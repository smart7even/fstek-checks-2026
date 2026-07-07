#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zko5.sh - Изоляция контейнеров в контейнерных средах (ЗКО.5)
# Соответствие разделу 4.5 (ЗКО.5) Методического документа ФСТЭК России от 12.04.2026

WITH_ENH=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENH=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода
check_pass() { fstek_status_line "$1" "PASS" "$2"; }
check_fail() { fstek_status_line "$1" "FAIL" "$2"; ((FAIL_COUNT++)); }
check_skip() { fstek_status_line "$1" "SKIP" "$2"; ((SKIP_COUNT++)); }

ENGINE="none"
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then ENGINE="docker";
elif command -v podman >/dev/null 2>&1; then ENGINE="podman"; fi

if [ "$ENGINE" == "none" ]; then
    check_skip "ЗКО.5.0" "Средства контейнеризации не обнаружены или не активны"
    echo "=== ИТОГ МОДУЛЯ ЗКО.5: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
    exit 0
fi

RUNNING=$($ENGINE ps -q 2>/dev/null)

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗКО.5.1 - Read-only корневая ФС и MAC-профили (AppArmor/SELinux)
MAC_OK=0
MAC_TOTAL=0
if [ -n "$RUNNING" ]; then
    for cid in $RUNNING; do
        ((MAC_TOTAL++))
        SECURITY_OPTS=$($ENGINE inspect --format='{{json .HostConfig.SecurityOpt}}' "$cid" 2>/dev/null)
        READONLY=$($ENGINE inspect --format='{{.HostConfig.ReadonlyRootfs}}' "$cid" 2>/dev/null)
        
        if [[ "$READONLY" == "true" ]] || [[ "$SECURITY_OPTS" =~ "apparmor" ]] || [[ "$SECURITY_OPTS" =~ "label=type:container" ]] || [[ "$SECURITY_OPTS" =~ "selinux" ]]; then
            ((MAC_OK++))
        fi
    done
fi

if [ "$MAC_TOTAL" -eq 0 ]; then
    check_skip "ЗКО.5.1" "Нет запущенных контейнеров для проверки изоляции ФС"
elif [ "$MAC_OK" -eq "$MAC_TOTAL" ]; then
    check_pass "ЗКО.5.1" "Для всех контейнеров ($MAC_TOTAL) настроена read-only ФС или MAC-профили (AppArmor/SELinux)"
else
    check_fail "ЗКО.5.1" "Только $MAC_OK из $MAC_TOTAL контейнеров используют read-only ФС или MAC-профили"
fi

# ЗКО.5.2 - Seccomp-профили (ограничение системных вызовов)
SECCOMP_OK=0
SECCOMP_TOTAL=0
if [ -n "$RUNNING" ]; then
    for cid in $RUNNING; do
        ((SECCOMP_TOTAL++))
        SECCOMP=$($ENGINE inspect --format='{{.HostConfig.SecurityOpt}}' "$cid" 2>/dev/null)
        
        if [[ ! "$SECCOMP" =~ "seccomp=unconfined" ]] && [[ ! "$SECCOMP" =~ "no-new-privileges:false" ]]; then
            ((SECCOMP_OK++))
        fi
    done
fi

if [ "$SECCOMP_TOTAL" -eq 0 ]; then
    check_skip "ЗКО.5.2" "Нет запущенных контейнеров для проверки seccomp"
elif [ "$SECCOMP_OK" -eq "$SECCOMP_TOTAL" ]; then
    check_pass "ЗКО.5.2" "Для всех контейнеров ($SECCOMP_TOTAL) активны seccomp-профили (ограничение syscalls)"
else
    check_fail "ЗКО.5.2" "Seccomp отключен для $((SECCOMP_TOTAL - SECCOMP_OK)) контейнеров (seccomp=unconfined)"
fi

# ЗКО.5.3 - Лимиты ресурсов (cgroups)
CGROUPS_OK=0
CGROUPS_TOTAL=0
if [ -n "$RUNNING" ]; then
    for cid in $RUNNING; do
        ((CGROUPS_TOTAL++))
        LIMITS=$($ENGINE inspect --format='{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}} {{.HostConfig.CpuShares}}' "$cid" 2>/dev/null)
        if [[ "$LIMITS" != "0 0 0" ]] && [[ -n "$LIMITS" ]]; then
            ((CGROUPS_OK++))
        fi
    done
fi

if [ "$CGROUPS_TOTAL" -eq 0 ]; then
    check_skip "ЗКО.5.3" "Нет запущенных контейнеров для проверки cgroups"
elif [ "$CGROUPS_OK" -eq "$CGROUPS_TOTAL" ]; then
    check_pass "ЗКО.5.3" "Для всех контейнеров ($CGROUPS_TOTAL) настроены лимиты ресурсов (CPU/RAM через cgroups)"
else
    check_fail "ЗКО.5.3" "Лимиты ресурсов не настроены для $((CGROUPS_TOTAL - CGROUPS_OK)) контейнеров (риск исчерпания ресурсов хоста)"
fi

# ЗКО.5.6 - Недоступность записи в корневую ФС хостовой ОС
HOST_MOUNT_VIOLATIONS=0
PRIVILEGED_VIOLATIONS=0
if [ -n "$RUNNING" ]; then
    for cid in $RUNNING; do
        PRIVILEGED=$($ENGINE inspect --format='{{.HostConfig.Privileged}}' "$cid" 2>/dev/null)
        MOUNTS=$($ENGINE inspect --format='{{json .Mounts}}' "$cid" 2>/dev/null)
        BINDS=$($ENGINE inspect --format='{{json .HostConfig.Binds}}' "$cid" 2>/dev/null)
        
        if [[ "$PRIVILEGED" == "true" ]]; then
            ((PRIVILEGED_VIOLATIONS++))
        fi
        
        if [[ "$MOUNTS" =~ '"/"' ]] || [[ "$BINDS" =~ '"/:"' ]] || [[ "$BINDS" =~ '"/etc:"' ]] || [[ "$BINDS" =~ '"/var:"' ]] || [[ "$BINDS" =~ '"/usr:"' ]]; then
            ((HOST_MOUNT_VIOLATIONS++))
        fi
    done
fi

TOTAL_VIOLATIONS=$((HOST_MOUNT_VIOLATIONS + PRIVILEGED_VIOLATIONS))
if [ "$TOTAL_VIOLATIONS" -eq 0 ]; then
    check_pass "ЗКО.5.6" "Корневая ФС хостовой ОС недоступна для записи из контейнеров (отсутствуют --privileged и mount /)"
else
    check_fail "ЗКО.5.6" "Обнаружено $PRIVILEGED_VIOLATIONS привилегированных контейнеров и $HOST_MOUNT_VIOLATIONS с mount корневой ФС хоста"
fi

# ЗКО.5.7 - Ограничение доступа к блочным устройствам и периферии
DEVICE_VIOLATIONS=0
if [ -n "$RUNNING" ]; then
    for cid in $RUNNING; do
        DEVICES=$($ENGINE inspect --format='{{json .HostConfig.Devices}}' "$cid" 2>/dev/null)
        if [[ "$DEVICES" != "null" ]] && [[ -n "$DEVICES" ]]; then
            ((DEVICE_VIOLATIONS++))
        fi
    done
fi

if [ "$DEVICE_VIOLATIONS" -eq 0 ]; then
    check_pass "ЗКО.5.7" "Доступ к блочным устройствам и периферии (/dev/*) ограничен (флаг --device отсутствует)"
else
    check_fail "ЗКО.5.7" "Обнаружено $DEVICE_VIOLATIONS контейнеров с прямым доступом к блочным устройствам (--device)"
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if fstek_enhancement_enabled "ЗКО.5" "3"; then
    # ЗКО.5.4 (Усиление 3) - User Namespace Remapping
    if [ "$ENGINE" == "docker" ]; then
        if grep -qE '"userns-remap"' /etc/docker/daemon.json 2>/dev/null; then
            check_pass "ЗКО.5.4" "Docker: Включен User Namespace Remapping (изоляция UID/GID)"
        else
            check_fail "ЗКО.5.4" "Docker: User Namespace Remapping не настроен (риск эскалации привилегий)"
        fi
    elif [ "$ENGINE" == "podman" ]; then
        if grep -q "rootless" /etc/containers/containers.conf 2>/dev/null || [ "$(id -u)" -ne 0 ]; then
            check_pass "ЗКО.5.4" "Podman: Используется изоляция через user namespaces (rootless-режим)"
        else
            check_fail "ЗКО.5.4" "Podman: User namespaces не используются (запуск от root)"
        fi
    fi
else
    skip_enhancement "ЗКО.5.4"
fi

if fstek_enhancement_enabled "ЗКО.5" "1"; then
    # ЗКО.5.5 (Усиление 1) - Изоляция всех 6 пространств имён (namespaces)
    NAMESPACE_ISOLATED=0
    NAMESPACE_TOTAL=0
    if [ -n "$RUNNING" ]; then
        for cid in $RUNNING; do
            ((NAMESPACE_TOTAL++))
            NS_ISSUES=0
            
            PID_MODE=$($ENGINE inspect --format='{{.HostConfig.PidMode}}' "$cid" 2>/dev/null)
            if [[ "$PID_MODE" == "host" ]]; then ((NS_ISSUES++)); fi
            
            IPC_MODE=$($ENGINE inspect --format='{{.HostConfig.IpcMode}}' "$cid" 2>/dev/null)
            if [[ "$IPC_MODE" == "host" ]]; then ((NS_ISSUES++)); fi
            
            UTS_MODE=$($ENGINE inspect --format='{{.HostConfig.UtsMode}}' "$cid" 2>/dev/null)
            if [[ "$UTS_MODE" == "host" ]]; then ((NS_ISSUES++)); fi
            
            NET_MODE=$($ENGINE inspect --format='{{.HostConfig.NetworkMode}}' "$cid" 2>/dev/null)
            if [[ "$NET_MODE" == "host" ]]; then ((NS_ISSUES++)); fi
            
            SECURITY_OPTS=$($ENGINE inspect --format='{{.HostConfig.SecurityOpt}}' "$cid" 2>/dev/null)
            if [[ "$SECURITY_OPTS" =~ "userns" ]] || grep -q '"userns-remap"' /etc/docker/daemon.json 2>/dev/null; then
                : # User namespace изолирован
            else
                if [ "$ENGINE" == "docker" ]; then ((NS_ISSUES++)); fi
            fi
            
            PRIVILEGED=$($ENGINE inspect --format='{{.HostConfig.Privileged}}' "$cid" 2>/dev/null)
            if [[ "$PRIVILEGED" == "true" ]]; then ((NS_ISSUES++)); fi
            
            if [ "$NS_ISSUES" -eq 0 ]; then
                ((NAMESPACE_ISOLATED++))
            fi
        done
    fi

    if [ "$NAMESPACE_TOTAL" -eq 0 ]; then
        check_skip "ЗКО.5.5" "Нет запущенных контейнеров для проверки namespaces"
    elif [ "$NAMESPACE_ISOLATED" -eq "$NAMESPACE_TOTAL" ]; then
        check_pass "ЗКО.5.5" "Для всех контейнеров ($NAMESPACE_TOTAL) изолированы все 6 namespaces (PID/IPC/UTS/Net/User/Mount)"
    else
        check_fail "ЗКО.5.5" "Только $NAMESPACE_ISOLATED из $NAMESPACE_TOTAL контейнеров имеют полную изоляцию namespaces"
    fi
else
    skip_enhancement "ЗКО.5.5"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗКО.5: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
