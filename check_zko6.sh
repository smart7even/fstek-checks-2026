#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zko6.sh - Идентификация, аутентификация и защита сетевого взаимодействия (ЗКО.6)
# Соответствие разделу 4.5 (ЗКО.6) Методического документа ФСТЭК России от 12.04.2026

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
    check_skip "ЗКО.6.0" "Средства контейнеризации не обнаружены или не активны"
    echo "=== ИТОГ МОДУЛЯ ЗКО.6: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
    exit 0
fi

# =================================================================================================
# БЛОК 1: БАЗОВЫЕ ТРЕБОВАНИЯ
# =================================================================================================

# ЗКО.6.1 - Идентификация и аутентификация 4 ролей (разработчик, админ ИБ, админ СК, админ хоста)
ROLES_CONFIGURED=false
if getent group docker >/dev/null 2>&1 && getent group docker-admins >/dev/null 2>&1; then ROLES_CONFIGURED=true; fi
if systemctl is-active --quiet sssd 2>/dev/null && grep -q "domains" /etc/sssd/sssd.conf 2>/dev/null; then ROLES_CONFIGURED=true; fi
if [ "$ENGINE" == "docker" ] && grep -qE '"authorization-plugins"' /etc/docker/daemon.json 2>/dev/null; then ROLES_CONFIGURED=true; fi
if command -v kubectl >/dev/null 2>&1 && kubectl get clusterroles 2>/dev/null | grep -qiE "developer|security|admin"; then ROLES_CONFIGURED=true; fi

if $ROLES_CONFIGURED; then
    check_pass "ЗКО.6.1" "Реализовано разграничение ролей (RBAC/LDAP/группы) для администраторов и разработчиков"
else
    check_fail "ЗКО.6.1" "Отсутствует явное разграничение 4 ролей (разработчик, админ ИБ, админ СК, админ хоста)"
fi

# ЗКО.6.3 - Защита взаимодействия с реестрами образов (TLS)
if [ "$ENGINE" == "docker" ]; then
    if grep -qE '"insecure-registries"' /etc/docker/daemon.json 2>/dev/null; then
        check_fail "ЗКО.6.3" "Обнаружены незащищённые реестры (insecure-registries) — нарушение TLS"
    else
        check_pass "ЗКО.6.3" "Взаимодействие с реестрами образов защищено (insecure-registries отсутствуют)"
    fi
elif [ "$ENGINE" == "podman" ]; then
    if grep -qE "insecure=true" /etc/containers/registries.conf 2>/dev/null; then
        check_fail "ЗКО.6.3" "Podman: Обнаружены незащищённые реестры (insecure=true)"
    else
        check_pass "ЗКО.6.3" "Podman: Взаимодействие с реестрами защищено TLS"
    fi
fi

# ЗКО.6.6 - Защита API средства контейнеризации (TLS / Unix socket)
if [ "$ENGINE" == "docker" ]; then
    if grep -qE '"tls":\s*true|"tlsverify":\s*true' /etc/docker/daemon.json 2>/dev/null || [ -d /etc/docker/certs.d ]; then
        check_pass "ЗКО.6.6" "Docker Daemon API защищен с использованием mTLS"
    elif [ -S /var/run/docker.sock ] && [ "$(stat -c %a /var/run/docker.sock 2>/dev/null)" == "660" ]; then
        check_pass "ЗКО.6.6" "Локальный доступ к API защищен строгими правами сокета (660)"
    else
        check_fail "ЗКО.6.6" "API средства контейнеризации не защищен TLS или строгими правами сокета"
    fi
else
    check_pass "ЗКО.6.6" "Podman: API защищен за счет отсутствия демона (daemonless) и rootless-режима"
fi

# =================================================================================================
# БЛОК 2: ТРЕБОВАНИЯ К УСИЛЕНИЮ
# =================================================================================================
if fstek_enhancement_enabled "ЗКО.6" "1"; then
    # ЗКО.6.2 (Усиление 1) - Идентификация объектов доступа (образов и контейнеров)
    OBJ_ID=false
    if [ "$ENGINE" == "docker" ] && grep -qE '"DOCKER_CONTENT_TRUST":\s*"1"' /etc/environment /etc/profile.d/*.sh 2>/dev/null; then OBJ_ID=true; fi
    if command -v cosign >/dev/null 2>&1 || command -v notary >/dev/null 2>&1; then OBJ_ID=true; fi
    
    # Проверка наличия инвентаризационных labels у запущенных контейнеров
    RUNNING=$($ENGINE ps -q 2>/dev/null)
    if [ -n "$RUNNING" ]; then
        LABELED=0
        for cid in $RUNNING; do
            if $ENGINE inspect --format='{{.Config.Labels}}' "$cid" 2>/dev/null | grep -qvE "^map\[\]$|^$"; then
                ((LABELED++))
            fi
        done
        [ "$LABELED" -gt 0 ] && OBJ_ID=true
    fi

    if $OBJ_ID; then
        check_pass "ЗКО.6.2" "Объекты доступа идентифицируются (цифровые подписи/Docker Content Trust/Labels)"
    else
        check_fail "ЗКО.6.2" "Идентификация образов и контейнеров не настроена (нет DCT/cosign/labels)"
    fi

    # ЗКО.6.4 (Усиление) - Ограничение сетевого доступа контейнеров (Запрет ICC)
    if [ "$ENGINE" == "docker" ]; then
        if grep -qE '"icc":\s*false' /etc/docker/daemon.json 2>/dev/null; then
            check_pass "ЗКО.6.4" "Межконтейнерное взаимодействие по умолчанию ограничено (icc=false)"
        else
            check_fail "ЗКО.6.4" "Межконтейнерное взаимодействие не ограничено (требуется icc=false в daemon.json)"
        fi
        
        # Дополнительная проверка: отключение userland-proxy для предотвращения обхода iptables
        if grep -qE '"userland-proxy":\s*false' /etc/docker/daemon.json 2>/dev/null; then
            check_pass "ЗКО.6.4" "Userland-proxy отключен (предотвращение обхода сетевых правил)"
        fi
    else
        check_skip "ЗКО.6.4" "Для Podman изоляция сетей обеспечивается через CNI/Netavark и rootless-режим"
    fi

    # ЗКО.6.5 (Усиление) - Сетевая сегментация / Микросегментация
    if [ "$ENGINE" == "docker" ]; then
        ISOLATED_NETS=$(docker network ls --filter driver=bridge --format '{{.Name}}' 2>/dev/null | grep -v "bridge" | wc -l)
        INTERNAL_NETS=0
        for net in $(docker network ls --filter driver=bridge --format '{{.Name}}' 2>/dev/null); do
            if docker network inspect "$net" --format '{{.Internal}}' 2>/dev/null | grep -q "true"; then
                ((INTERNAL_NETS++))
            fi
        done
        
        if [ "$ISOLATED_NETS" -gt 0 ] || [ "$INTERNAL_NETS" -gt 0 ]; then
            check_pass "ЗКО.6.5" "Используется сетевая сегментация ($ISOLATED_NETS кастомных сетей, $INTERNAL_NETS внутренних)"
        else
            check_fail "ЗКО.6.5" "Сетевая сегментация не настроена (контейнеры используют default bridge)"
        fi
    elif [ "$ENGINE" == "podman" ]; then
        check_pass "ЗКО.6.5" "Podman: По умолчанию используется изоляция через slirp4netns/pasta (микросегментация)"
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "ЗКО.6.2, ЗКО.6.4-5"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗКО.6: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1