#!/bin/bash
# check_zko7.sh - Управление контейнерами и их образами (ЗКО.7)
# Соответствие разделу 4.5 (ЗКО.7) Методического документа ФСТЭК России от 12.04.2026

# Согласно Методическому документу ФСТЭК, для меры ЗКО.7 
# требования к усилению не предъявляются. Флаг -e не используется.

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
    check_skip "ЗКО.7.0" "Средства контейнеризации не обнаружены или не активны"
    echo "=== ИТОГ МОДУЛЯ ЗКО.7: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗКО.7.1 - Доверенные реестры и размещение образов
if [ "$ENGINE" == "docker" ]; then
    # Проверяем наличие внешних незащищенных реестров (HTTP)
    if grep -qE '"insecure-registries"' /etc/docker/daemon.json 2>/dev/null && \
       ! grep -qE '"insecure-registries".*(localhost|127\.0\.0\.1|10\.|192\.168\.)' /etc/docker/daemon.json 2>/dev/null; then
        check_fail "ЗКО.7.1" "Docker: Обнаружены незащищённые внешние реестры (insecure-registries) в daemon.json"
    elif grep -qE '"registry-mirrors"|"insecure-registries".*(localhost|127\.0\.0\.1|10\.|192\.168\.)' /etc/docker/daemon.json 2>/dev/null; then
        check_pass "ЗКО.7.1" "Docker: Настроено использование внутренних доверенных реестров (registry-mirrors / локальные insecure-registries)"
    elif [ -f /etc/docker/daemon.json ]; then
        check_fail "ЗКО.7.1" "Docker: Не настроены registry-mirrors для использования внутренних реестров"
    else
        check_skip "ЗКО.7.1" "Docker: Файл daemon.json не найден"
    fi
elif [ "$ENGINE" == "podman" ]; then
    if [ -f /etc/containers/registries.conf ]; then
        if grep -qE '^\[\[registry\]\]|location.*=.*"(harbor|nexus|registry|gitlab)"' /etc/containers/registries.conf 2>/dev/null; then
            check_pass "ЗКО.7.1" "Podman: Настроено использование внутренних доверенных реестров"
        elif grep -qE "insecure=true" /etc/containers/registries.conf 2>/dev/null; then
            check_fail "ЗКО.7.1" "Podman: Обнаружены незащищённые реестры (insecure=true)"
        else
            check_fail "ЗКО.7.1" "Podman: Не настроены внутренние реестры в registries.conf"
        fi
    else
        check_skip "ЗКО.7.1" "Podman: Файл registries.conf не найден"
    fi
fi

# ЗКО.7.2 - Инвентаризация контейнеров и образов
INVENTORY_FOUND=false
# 1. Файлы инвентаризации
if find /var/lib /opt /backup /srv -type f \( -name "*inventory*.json" -o -name "*inventory*.yaml" -o -name "*inventory*.yml" -o -name "*container*list*.json" \) -mtime -30 2>/dev/null | grep -q .; then
    INVENTORY_FOUND=true
fi
# 2. Периодические задания
if crontab -l 2>/dev/null | grep -qiE "inventory|inspect|docker.*ps|podman.*ps" || \
   grep -rqiE "inventory|docker.*ps.*--format" /etc/cron.* /var/spool/cron/ 2>/dev/null || \
   systemctl list-timers --all 2>/dev/null | grep -qiE "inventory|container"; then
    INVENTORY_FOUND=true
fi
# 3. CMDB системы
if command -v netbox >/dev/null 2>&1 || command -v ralph >/dev/null 2>&1 || \
   systemctl is-active --quiet netbox 2>/dev/null || systemctl is-active --quiet ralph 2>/dev/null; then
    INVENTORY_FOUND=true
fi
# 4. Оркестратор (Kubernetes)
if command -v kubectl >/dev/null 2>&1 && kubectl get nodes 2>/dev/null | grep -q "Ready"; then
    INVENTORY_FOUND=true
fi

if $INVENTORY_FOUND; then
    check_pass "ЗКО.7.2" "Инвентаризация контейнеров и образов ведется (обнаружены CMDB, скрипты или K8s API)"
else
    check_fail "ЗКО.7.2" "Инвентаризация контейнеров и образов не ведется (отсутствуют данные, периодические задания или CMDB)"
fi

# ЗКО.7.3 - Контроль перемещения контейнеров за пределы ИС
EGRESS_CONTROL=false
# Сетевые политики (K8s NetworkPolicies или iptables)
if command -v kubectl >/dev/null 2>&1 && kubectl get networkpolicies --all-namespaces 2>/dev/null | grep -qE "deny|egress"; then
    EGRESS_CONTROL=true
elif command -v iptables >/dev/null 2>&1 && iptables -L OUTPUT -n 2>/dev/null | grep -qE "DROP|REJECT" && \
     iptables -L OUTPUT -n 2>/dev/null | grep -qiE "docker|container|172\.|10\."; then
    EGRESS_CONTROL=true
fi
# Запрет pull/push во внешние публичные реестры
if [ "$ENGINE" == "docker" ]; then
    if grep -qE '"registry-mirrors".*\[\]|"insecure-registries".*\[\]' /etc/docker/daemon.json 2>/dev/null; then
        EGRESS_CONTROL=true
    fi
elif [ "$ENGINE" == "podman" ]; then
    if [ -f /etc/containers/registries.conf ] && grep -qE "^unqualified-search-registries\s*=\s*\[\]" /etc/containers/registries.conf 2>/dev/null; then
        EGRESS_CONTROL=true
    fi
fi

if $EGRESS_CONTROL; then
    check_pass "ЗКО.7.3" "Контроль перемещения контейнеров за пределы ИС настроен (egress-политики или запрет внешних реестров)"
else
    check_fail "ЗКО.7.3" "Контроль перемещения контейнеров за пределы ИС не настроен"
fi

# ЗКО.7.4 - Контроль отклонений от эталонных конфигураций
CONFIG_CONTROL=false
# Инструменты конфигурационного контроля (IaC scanning)
if command -v checkov >/dev/null 2>&1 || command -v kics >/dev/null 2>&1 || \
   command -v anchore-cli >/dev/null 2>&1 || command -v conftest >/dev/null 2>&1; then
    CONFIG_CONTROL=true
fi
# Версионирование эталонных шаблонов (Dockerfile, docker-compose)
if find /opt /srv /home -type f \( -name "Dockerfile" -o -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "*.helmfile.yaml" \) 2>/dev/null | head -1 | grep -q .; then
    if find /opt /srv /home -type d -name ".git" 2>/dev/null | grep -q . || \
       find /opt /srv /home -type f \( -name "*.sha256" -o -name "*.sig" \) 2>/dev/null | grep -qE "Dockerfile|docker-compose"; then
        CONFIG_CONTROL=true
    fi
fi
# Admission Controllers (OPA/Gatekeeper/Kyverno)
if command -v kubectl >/dev/null 2>&1; then
    if kubectl get validatingwebhookconfigurations 2>/dev/null | grep -qiE "opa|gatekeeper|kyverno"; then
        CONFIG_CONTROL=true
    fi
fi

if $CONFIG_CONTROL; then
    check_pass "ЗКО.7.4" "Контроль отклонений от эталонных конфигураций настроен (Checkov/KICS/OPA или версионирование шаблонов)"
else
    check_fail "ЗКО.7.4" "Контроль отклонений от эталонных конфигураций не настроен"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗКО.7: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1