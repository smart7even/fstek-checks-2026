#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zko8.sh - Выявление и устранение уязвимостей в контейнерной среде (ЗКО.8)
# Соответствие разделу 4.5 (ЗКО.8) Методического документа ФСТЭК России от 12.04.2026

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода

ENGINE="none"
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then ENGINE="docker";
elif command -v podman >/dev/null 2>&1; then ENGINE="podman"; fi

if [ "$ENGINE" == "none" ]; then
    check_skip "ЗКО.8.0" "Средства контейнеризации не обнаружены или не активны"
    finish_legacy_measure "ЗКО.8"
    exit 0
fi

# =================================================================================================
# БЛОК 1: БАЗОВЫЕ ТРЕБОВАНИЯ
# =================================================================================================

# ЗКО.8.1 - Наличие сканера уязвимостей образов
# Методика требует взаимодействия со средством контроля защищённости на основе БДУ ФСТЭК
SCANNER_FOUND=false
SCANNER_NAME=""
if command -v trivy >/dev/null 2>&1; then SCANNER_FOUND=true; SCANNER_NAME="trivy"; fi
if command -v grype >/dev/null 2>&1; then SCANNER_FOUND=true; SCANNER_NAME="grype"; fi
if command -v snyk >/dev/null 2>&1; then SCANNER_FOUND=true; SCANNER_NAME="snyk"; fi

# Специализированные средства (Harbor с Clair, GitLab Container Scanning)
if command -v harbor >/dev/null 2>&1 || systemctl is-active --quiet harbor 2>/dev/null; then
    SCANNER_FOUND=true; SCANNER_NAME="harbor/clair";
fi

if $SCANNER_FOUND; then
    check_pass "ЗКО.8.1" "Обнаружен сканер уязвимостей образов ($SCANNER_NAME)"
else
    check_fail "ЗКО.8.1" "Сканер уязвимостей для контейнерных образов не установлен (требуется trivy/grype/snyk)"
fi

# ЗКО.8.2 - Периодичность сканирования (базовое требование — не реже 1 раза в месяц)
PERIODIC_SCAN=false
if crontab -l 2>/dev/null | grep -qE "trivy|grype|snyk|scan.*container"; then PERIODIC_SCAN=true; fi
if grep -rqE "trivy|grype|snyk|container.*scan" /etc/cron.* /var/spool/cron/ 2>/dev/null; then PERIODIC_SCAN=true; fi
if systemctl list-timers --all 2>/dev/null | grep -qiE "trivy|grype|container.*scan"; then PERIODIC_SCAN=true; fi

# Для Kubernetes: CronJob для сканирования образов
if command -v kubectl >/dev/null 2>&1 && kubectl get cronjobs --all-namespaces 2>/dev/null | grep -qiE "scan|trivy|grype"; then
    PERIODIC_SCAN=true
fi

if $PERIODIC_SCAN; then
    check_pass "ЗКО.8.2" "Настроено периодическое сканирование образов на уязвимости (cron/timers/CronJob)"
else
    check_fail "ЗКО.8.2" "Задания для автоматического сканирования образов не найдены (требуется не реже 1 раза в месяц)"
fi

# ЗКО.8.3 - Оповещение администратора безопасности о выявленных уязвимостях
# Методика ЖЕСТКО требует оповещения администратора ИБ по результатам сканирования
ALERTING_CONFIGURED=false

# 1. Проверка настроек алертинга в конфигах сканеров (webhook/email/telegram)
for conf in /etc/trivy.yaml /etc/trivy/trivy.yaml ~/.trivy.yaml /etc/grype.yaml ~/.grype.yaml; do
    if [ -f "$conf" ] && grep -qiE "webhook|email|smtp|telegram|slack|alert|notify" "$conf" 2>/dev/null; then
        ALERTING_CONFIGURED=true; break
    fi
done

# 2. Проверка скриптов отправки уведомлений в cron-задачах сканирования
if crontab -l 2>/dev/null | grep -qE "trivy.*\|.*mail|trivy.*\|.*curl|trivy.*\|.*telegram|grype.*\|.*mail"; then
    ALERTING_CONFIGURED=true
fi
if grep -rqE "trivy.*\|.*mail|trivy.*\|.*curl|trivy.*notify" /etc/cron.* /usr/local/bin/ 2>/dev/null; then
    ALERTING_CONFIGURED=true
fi

# 3. Интеграция с SIEM (Wazuh/Filebeat) для централизованного оповещения
if systemctl is-active --quiet wazuh-agent 2>/dev/null && grep -rqE "trivy|grype|vulnerab" /var/ossec/etc/ossec.conf 2>/dev/null; then
    ALERTING_CONFIGURED=true
fi
if systemctl is-active --quiet filebeat 2>/dev/null && grep -qiE "trivy|grype|vulnerab" /etc/filebeat/filebeat.yml 2>/dev/null; then
    ALERTING_CONFIGURED=true
fi

# 4. Интеграция с системами тикетов (Jira, ServiceNow, OTRS)
if crontab -l 2>/dev/null | grep -qiE "jira|servicenow|otrs|ticket" 2>/dev/null; then
    ALERTING_CONFIGURED=true
fi

if $ALERTING_CONFIGURED; then
    check_pass "ЗКО.8.3" "Настроено оповещение администратора ИБ о выявленных уязвимостях (webhook/email/SIEM)"
else
    check_fail "ЗКО.8.3" "Оповещение администратора ИБ о результатах сканирования не настроено"
fi

# =================================================================================================
# БЛОК 2: ТРЕБОВАНИЯ К УСИЛЕНИЮ
# =================================================================================================
if fstek_enhancement_enabled "ЗКО.8" "1" "2"; then
    # ЗКО.8.4 (Усиление 1) - Еженедельное сканирование
    WEEKLY_SCAN=false
    if crontab -l 2>/dev/null | grep -E "trivy|grype|snyk" | awk '{print $1, $2, $3, $4, $5}' | grep -qE "@weekly|^\*.*\*.*\*.*(0|7)"; then
        WEEKLY_SCAN=true
    fi
    if grep -rqE "@weekly.*(trivy|grype)|trivy.*weekly|grype.*weekly" /etc/cron.* 2>/dev/null; then
        WEEKLY_SCAN=true
    fi
    if systemctl list-timers --all 2>/dev/null | grep -qiE "trivy-weekly|grype-weekly|container-scan-weekly"; then
        WEEKLY_SCAN=true
    fi
    
    if $WEEKLY_SCAN; then
        check_pass "ЗКО.8.4" "Настроено еженедельное сканирование образов (усиление 1)"
    else
        check_fail "ЗКО.8.4" "Еженедельная периодичность сканирования не настроена (требуется для усиления 1)"
    fi

    # ЗКО.8.5 (Усиление 2) - Запрет создания/развёртывания образов с критическими/высокими уязвимостями
    BLOCK_CONFIGURED=false
    
    # 1. Admission Controllers в Kubernetes (OPA Gatekeeper, Kyverno)
    if command -v kubectl >/dev/null 2>&1; then
        if kubectl get validatingwebhookconfigurations 2>/dev/null | grep -qiE "opa|gatekeeper|kyverno"; then
            if kubectl get constraints,clusterpolicies,policies --all-namespaces 2>/dev/null | grep -qiE "vuln|cve|critical|high|severity"; then
                BLOCK_CONFIGURED=true
                check_pass "ЗКО.8.5" "Kubernetes: Admission Controller (OPA/Kyverno) блокирует деплой образов с CRITICAL/HIGH CVE"
            fi
        fi
    fi
    
    # 2. Политики Docker Content Trust / Podman policy.json
    if [ "$ENGINE" == "docker" ] && grep -qE '"DOCKER_CONTENT_TRUST"[:\s=]+ "?1"?' /etc/environment /etc/docker/daemon.json 2>/dev/null; then
        BLOCK_CONFIGURED=true
        check_pass "ЗКО.8.5" "Docker Content Trust блокирует запуск неподписанных (неверифицированных) образов"
    fi
    if [ "$ENGINE" == "podman" ] && [ -f /etc/containers/policy.json ] && grep -q '"type": "reject"' /etc/containers/policy.json 2>/dev/null; then
        BLOCK_CONFIGURED=true
        check_pass "ЗКО.8.5" "Podman: policy.json блокирует запуск образов, не прошедших верификацию"
    fi
    
    # 3. CI/CD пайплайны с автоматическим прерыванием при обнаружении CRITICAL/HIGH CVE
    if find / -maxdepth 5 -type f \( -name ".gitlab-ci.yml" -o -name "Jenkinsfile" -o -name "*.pipeline" \) 2>/dev/null | xargs grep -lE "trivy.*--severity.*(CRITICAL|HIGH)|grype.*--fail-on.*high|exit.*1.*vuln" 2>/dev/null | grep -q .; then
        BLOCK_CONFIGURED=true
        check_pass "ЗКО.8.5" "CI/CD пайплайн прерывается при обнаружении CRITICAL/HIGH уязвимостей (fail-fast)"
    fi
    
    # 4. Harbor / приватные registry с политиками блокировки
    if systemctl is-active --quiet harbor 2>/dev/null || [ -f /etc/harbor/harbor.yml ]; then
        if grep -qiE "vulnerability.*policy|block.*critical|deny.*high" /etc/harbor/*.yml 2>/dev/null; then
            BLOCK_CONFIGURED=true
            check_pass "ЗКО.8.5" "Harbor Registry: настроены политики блокировки уязвимых образов"
        fi
    fi
    
    # 5. Docker authorization plugins
    if [ "$ENGINE" == "docker" ] && grep -qE '"authorization-plugins".*"(opa|authz|trivy)"' /etc/docker/daemon.json 2>/dev/null; then
        BLOCK_CONFIGURED=true
        check_pass "ЗКО.8.5" "Docker: authorization plugin блокирует запуск уязвимых образов на уровне демона"
    fi
    
    if ! $BLOCK_CONFIGURED; then
        check_fail "ЗКО.8.5" "Механизмы блокировки развёртывания образов с CRITICAL/HIGH уязвимостями не настроены"
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "ЗКО.8.4-5"
fi

# Унифицированная итоговая строка
finish_legacy_measure "ЗКО.8"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1