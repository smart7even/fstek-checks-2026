#!/bin/bash
# check_zko3.sh - Управление доступом в контейнерных средах (ЗКО.3)
# Соответствие разделу 4.5 (ЗКО.3) Методического документа ФСТЭК России от 12.04.2026

WITH_ENH=false
[[ "$1" == "-e" || "$1" == "--with-enhancements" ]] && WITH_ENH=true

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

ENGINE="none"
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then ENGINE="docker";
elif command -v podman >/dev/null 2>&1; then ENGINE="podman"; fi

if [ "$ENGINE" == "none" ]; then
    check_skip "ЗКО.3.0" "Средства контейнеризации не обнаружены или не активны"
    echo "=== ИТОГ МОДУЛЯ ЗКО.3: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗКО.3.1 - Защита сокета средства контейнеризации
SOCKET_PATH="/var/run/docker.sock"
[ "$ENGINE" == "podman" ] && SOCKET_PATH="/run/podman/podman.sock"

if [ -S "$SOCKET_PATH" ]; then
    PERMS=$(stat -c "%a" "$SOCKET_PATH" 2>/dev/null)
    OWNER=$(stat -c "%U:%G" "$SOCKET_PATH" 2>/dev/null)
    if [ "$PERMS" == "660" ] && [[ "$OWNER" == "root:docker" || "$OWNER" == "root:root" || "$OWNER" == "root:podman" ]]; then
        check_pass "ЗКО.3.1" "Сокет средства контейнеризации защищен (права $PERMS, владелец $OWNER)"
    else
        check_fail "ЗКО.3.1" "Сокет имеет небезопасные права ($PERMS) или владельца ($OWNER). Требуется 660 root:docker"
    fi
else
    # Podman в rootless режиме может не иметь системного сокета
    if [ "$ENGINE" == "podman" ] && grep -q "rootless" /etc/containers/containers.conf 2>/dev/null; then
        check_pass "ЗКО.3.1" "Podman работает в rootless-режиме (системный сокет не требуется)"
    else
        check_fail "ЗКО.3.1" "Сокет средства контейнеризации не найден"
    fi
fi

# ЗКО.3.2 - Rootless mode или выделенные группы доступа
if [ "$ENGINE" == "podman" ]; then
    if grep -qE "rootless" /etc/containers/containers.conf 2>/dev/null; then
        check_pass "ЗКО.3.2" "Podman: Настроен rootless-режим (принцип минимальных привилегий)"
    else
        check_skip "ЗКО.3.2" "Rootless-режим Podman не подтвержден автоматически"
    fi
elif getent group docker >/dev/null 2>&1; then
    DOCKER_USERS=$(getent group docker | awk -F: '{print $4}')
    check_pass "ЗКО.3.2" "Существует выделенная группа 'docker' для контроля доступа (пользователи: $DOCKER_USERS)"
else
    check_fail "ЗКО.3.2" "Отсутствует выделенная группа для доступа к средству контейнеризации"
fi

# ЗКО.3.3 - Управление доступом к объектам (запрет привилегированных контейнеров)
PRIVILEGED_COUNT=0
RUNNING=$($ENGINE ps -q 2>/dev/null)
if [ -n "$RUNNING" ]; then
    for cid in $RUNNING; do
        if $ENGINE inspect --format='{{.HostConfig.Privileged}}' "$cid" 2>/dev/null | grep -q "true"; then
            ((PRIVILEGED_COUNT++))
        fi
    done
fi

if [ "$PRIVILEGED_COUNT" -eq 0 ]; then
    check_pass "ЗКО.3.3" "Привилегированные контейнеры (--privileged) отсутствуют. Доступ к ресурсам хоста ограничен"
else
    check_fail "ЗКО.3.3" "Обнаружено $PRIVILEGED_COUNT контейнеров, запущенных с флагом --privileged (нарушение минимизации прав)"
fi

# ЗКО.3.4 - Политики доступа к образам (аутентификация в приватных реестрах)
REGISTRY_AUTH=false
if [ "$ENGINE" == "docker" ]; then
    if [ -f ~/.docker/config.json ] && grep -q "auths" ~/.docker/config.json 2>/dev/null; then
        REGISTRY_AUTH=true
    elif [ -f /root/.docker/config.json ] && grep -q "auths" /root/.docker/config.json 2>/dev/null; then
        REGISTRY_AUTH=true
    fi
elif [ "$ENGINE" == "podman" ]; then
    if [ -f /etc/containers/auth.json ] || [ -f ~/.config/containers/auth.json ] || [ -f /run/containers/containers.auth ]; then
        REGISTRY_AUTH=true
    fi
fi

if $REGISTRY_AUTH; then
    check_pass "ЗКО.3.4" "Настроены политики аутентификации и доступа к приватным реестрам образов (auth.json / config.json)"
else
    check_fail "ЗКО.3.4" "Политики доступа к образам приватных реестров (auth.json / config.json) не обнаружены"
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if $WITH_ENH; then
    # ЗКО.3.5 (Усиление) - Плагины авторизации и RBAC
    AUTHZ_CONFIGURED=false
    
    # 1. Docker: проверка наличия authorization-plugins
    if [ "$ENGINE" == "docker" ] && grep -qE '"authorization-plugins"' /etc/docker/daemon.json 2>/dev/null; then
        AUTHZ_CONFIGURED=true
        check_pass "ЗКО.3.5" "Docker: Настроены плагины авторизации (authorization-plugins) для реализации RBAC"
    fi
    
    # 2. Kubernetes: проверка наличия Admission Controllers (OPA/Gatekeeper/Kyverno)
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl get validatingwebhookconfigurations 2>/dev/null | grep -qiE "opa|gatekeeper|kyverno"; then
            AUTHZ_CONFIGURED=true
            check_pass "ЗКО.3.5" "Kubernetes: Обнаружены политики RBAC (OPA/Gatekeeper/Kyverno)"
        fi
    fi
    
    if ! $AUTHZ_CONFIGURED; then
        check_fail "ЗКО.3.5" "Средства централизованного RBAC (authz-плагины или Admission Controllers) не обнаружены"
    fi
else
    # Унифицированный вывод для отключенных усилений
    echo "[ЗКО.3.5] SKIP – проверка усилений отключена"
    ((SKIP_COUNT++))
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗКО.3: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1