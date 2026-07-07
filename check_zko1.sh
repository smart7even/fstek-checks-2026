#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zko1.sh - Контроль целостности в контейнерных средах (ЗКО.1)
# Соответствие разделу 4.5 (ЗКО.1) Методического документа ФСТЭК России от 12.04.2026

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
    check_skip "ЗКО.1.0" "Средства контейнеризации (Docker/Podman) не обнаружены или не активны"
    echo "=== ИТОГ МОДУЛЯ ЗКО.1: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗКО.1.1 – Периодичность контроля целостности (еженедельно или чаще)
PERIODIC_FOUND=false

# 1. Поиск в crontab и системных заданиях (только задания, явно связанные с контейнерами)
if crontab -l 2>/dev/null | grep -qiE "(docker|podman|container).*(integrity|hash|sha256|trivy|grype)" || \
   crontab -l 2>/dev/null | grep -qiE "trivy.*(container|image|docker|podman)" || \
   grep -rqiE "(docker|podman|container).*(integrity|trivy|grype)" /etc/cron.* /var/spool/cron/ 2>/dev/null || \
   systemctl list-timers --all 2>/dev/null | grep -qiE "(container|docker|podman).*(integrity|trivy|grype)"; then
    PERIODIC_FOUND=true
fi

# 2. Поиск файлов конфигурации FIM (AIDE/Wazuh/IMA), контролирующих каталоги контейнеризации
if ! $PERIODIC_FOUND; then
    if command -v aide &>/dev/null && [ -f /etc/aide/aide.conf ] && \
       grep -qE "/var/lib/docker|/var/lib/containers|/etc/docker|/etc/containers" /etc/aide/aide.conf 2>/dev/null; then
        PERIODIC_FOUND=true
    fi
    if systemctl is-active --quiet wazuh-agent 2>/dev/null && \
       grep -rqE "/var/lib/docker|/var/lib/containers|/etc/docker|/etc/containers" /var/ossec/etc/ossec.conf 2>/dev/null; then
        PERIODIC_FOUND=true
    fi
    if [ -f /sys/kernel/security/ima/ascii_runtime_measurements ] && \
       grep -qE "/var/lib/docker|/var/lib/containers|/etc/docker|/etc/containers" /sys/kernel/security/ima/ascii_runtime_measurements 2>/dev/null; then
        PERIODIC_FOUND=true
    fi
fi

if $PERIODIC_FOUND; then
    check_pass "ЗКО.1.1" "Настроены периодические задания (cron/timers) или FIM для контроля целостности контейнерной среды"
else
    check_fail "ЗКО.1.1" "Не найдены периодические задания или FIM-системы для контроля целостности образов и контейнеров"
fi

# ЗКО.1.2 – Контроль исполняемых файлов внутри ЗАПУЩЕННЫХ контейнеров
RUNTIME_CHECK=false
if command -v falco &>/dev/null && systemctl is-active --quiet falco 2>/dev/null; then
    RUNTIME_CHECK=true
    check_pass "ЗКО.1.2" "Falco активен: настроен мониторинг изменений файловой системы в запущенных контейнерах"
elif [ "$ENGINE" == "docker" ] || [ "$ENGINE" == "podman" ]; then
    CHANGED_CONTAINERS=0
    RUNNING=$($ENGINE ps -q 2>/dev/null)
    if [ -n "$RUNNING" ]; then
        for cid in $RUNNING; do
            if $ENGINE diff "$cid" 2>/dev/null | grep -qE "^C /bin|^C /usr|^C /sbin|^A /bin|^A /usr|^A /sbin"; then
                ((CHANGED_CONTAINERS++))
            fi
        done
        if [ "$CHANGED_CONTAINERS" -eq 0 ]; then
            RUNTIME_CHECK=true
            check_pass "ЗКО.1.2" "Изменений исполняемых файлов в запущенных контейнерах не обнаружено ($ENGINE diff)"
        else
            check_fail "ЗКО.1.2" "Обнаружены изменения файловой системы в $CHANGED_CONTAINERS запущенных контейнерах"
        fi
    else
        check_skip "ЗКО.1.2" "Нет запущенных контейнеров для проверки изменений ($ENGINE diff)"
        RUNTIME_CHECK=true
    fi
fi

if ! $RUNTIME_CHECK && [ "$ENGINE" != "none" ]; then
    if crontab -l 2>/dev/null | grep -q "trivy fs" || grep -rq "trivy fs" /etc/cron.* 2>/dev/null; then
        check_pass "ЗКО.1.2" "Настроено периодическое сканирование файловых систем контейнеров (trivy fs)"
    else
        check_fail "ЗКО.1.2" "Отсутствует механизм контроля изменений исполняемых файлов внутри запущенных контейнеров"
    fi
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if fstek_enhancement_enabled "ЗКО.1" "1" "2"; then
    # ЗКО.1.3 (Усиления 1 и 2) – Контроль целостности ПО и настроек ХОСТОВОЙ ОС и средства контейнеризации
    HOST_FIM=false
    FIM_PATHS=("/usr/bin/dockerd" "/usr/bin/podman" "/usr/bin/containerd" "/etc/docker" "/etc/containers")
    if command -v aide &>/dev/null && [ -f /etc/aide/aide.conf ]; then
        for p in "${FIM_PATHS[@]}"; do
            if grep -q "$p" /etc/aide/aide.conf /etc/aide/aide.conf.d/* 2>/dev/null; then
                HOST_FIM=true; break
            fi
        done
    elif systemctl is-active --quiet wazuh-agent 2>/dev/null; then
        for p in "${FIM_PATHS[@]}"; do
            if grep -rq "$p" /var/ossec/etc/ossec.conf /var/ossec/etc/shared/* 2>/dev/null; then
                HOST_FIM=true; break
            fi
        done
    elif [ -f /sys/kernel/security/ima/ascii_runtime_measurements ]; then
        if grep -qE "/etc/docker|/etc/containers" /sys/kernel/security/ima/ascii_runtime_measurements 2>/dev/null || \
           grep -rq "ima" /etc/fstab 2>/dev/null; then
            HOST_FIM=true
        fi
    fi

    if $HOST_FIM; then
        check_pass "ЗКО.1.3" "Бинарники и конфиги средства контейнеризации включены в контур FIM (AIDE/Wazuh/IMA)"
    else
        check_fail "ЗКО.1.3" "ПО и параметры настройки хостовой ОС и средства контейнеризации не контролируются FIM-системой"
    fi
else
    skip_enhancement "ЗКО.1.3"
fi

if fstek_enhancement_enabled "ЗКО.1" "4"; then
    # ЗКО.1.4 (Усиление 4) – Контроль образов с использованием свидетельств подлинности (подписей)
    TRUST_CONFIGURED=false
    if [ "$ENGINE" == "docker" ]; then
        if grep -qE '"DOCKER_CONTENT_TRUST"[:\s=]+ "?1"?' /etc/environment /etc/docker/daemon.json /etc/profile.d/*.sh 2>/dev/null || \
           [ "${DOCKER_CONTENT_TRUST}" == "1" ]; then
            TRUST_CONFIGURED=true
        fi
    elif [ "$ENGINE" == "podman" ]; then
        if [ -f /etc/containers/policy.json ] && grep -q "signedBy" /etc/containers/policy.json 2>/dev/null; then
            TRUST_CONFIGURED=true
        fi
    fi

    if $TRUST_CONFIGURED; then
        check_pass "ЗКО.1.4" "Настроена политика проверки цифровых подписей образов (Docker Content Trust / Podman policy.json)"
    else
        check_fail "ЗКО.1.4" "Контроль отсутствия изменений с использованием свидетельств подлинности (подписей) не настроен"
    fi
else
    skip_enhancement "ЗКО.1.4"
fi

if fstek_enhancement_enabled "ЗКО.1" "6"; then
    # ЗКО.1.5 (Усиление 6) – Выявление образа с нарушенной целостностью
    if command -v cosign &>/dev/null || command -v trivy &>/dev/null || command -v grype &>/dev/null; then
        check_pass "ЗКО.1.5" "Установлены средства верификации целостности и уязвимостей образов (cosign/trivy/grype)"
    elif [ "$ENGINE" == "docker" ] && docker trust inspect 2>/dev/null | grep -q "Signed"; then
        check_pass "ЗКО.1.5" "Используется Docker Trust для выявления образов с нарушенной целостностью"
    else
        check_fail "ЗКО.1.5" "Отсутствуют средства автоматического выявления образов с нарушенной целостностью"
    fi
else
    skip_enhancement "ЗКО.1.5"
fi

if fstek_enhancement_enabled "ЗКО.1" "7"; then
    # ЗКО.1.6 (Усиление 7) – Блокировка запуска образа с нарушенной целостностью
    BLOCK_CONFIGURED=false
    if [ "$ENGINE" == "docker" ]; then
        if grep -qE '"authorization-plugins"' /etc/docker/daemon.json 2>/dev/null; then
            BLOCK_CONFIGURED=true
        fi
    elif [ "$ENGINE" == "podman" ]; then
        if [ -f /etc/containers/policy.json ] && grep -q "reject" /etc/containers/policy.json 2>/dev/null; then
            BLOCK_CONFIGURED=true
        fi
    fi
    if command -v kubectl &>/dev/null && kubectl get validatingwebhookconfigurations 2>/dev/null | grep -qE "opa|gatekeeper|kyverno"; then
        BLOCK_CONFIGURED=true
    fi

    if $BLOCK_CONFIGURED; then
        check_pass "ЗКО.1.6" "Настроен механизм блокировки запуска образов с нарушенной целостностью (authz-plugins/policy/webhooks)"
    else
        check_fail "ЗКО.1.6" "Блокировка запуска образов и ПО с нарушенной целостностью не настроена"
    fi
else
    skip_enhancement "ЗКО.1.6"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗКО.1: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
