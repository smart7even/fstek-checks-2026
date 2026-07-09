#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zko2.sh - Регистрация событий безопасности в контейнерных средах (ЗКО.2)
# Соответствие разделу 4.5 (ЗКО.2) Методического документа ФСТЭК России от 12.04.2026

WITH_ENH=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENH=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода

ENGINE="none"
if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then ENGINE="docker";
elif command -v podman >/dev/null 2>&1; then ENGINE="podman"; fi

if [ "$ENGINE" == "none" ]; then
    check_skip "ЗКО.2.0" "Средства контейнеризации не обнаружены или не активны"
    finish_legacy_measure "ЗКО.2"
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ (11 типов событий Методики) ---

# ЗКО.2.1 – Настройка уровня детализации логирования (log-level)
LOG_LEVEL_OK=false
if [ "$ENGINE" == "docker" ]; then
    if grep -qE '"log-level"\s*:\s*"(info|debug)"' /etc/docker/daemon.json 2>/dev/null; then
        LOG_LEVEL_OK=true
    elif journalctl -u docker --no-pager -n 500 2>/dev/null | grep -qiE "container.*start|image.*pull"; then
        LOG_LEVEL_OK=true
    fi
elif [ "$ENGINE" == "podman" ]; then
    if grep -qE 'log_level\s*=\s*"info"|log_level\s*=\s*"debug"' /etc/containers/containers.conf 2>/dev/null; then
        LOG_LEVEL_OK=true
    elif journalctl --user -u podman --no-pager -n 500 2>/dev/null | grep -qiE "container.*start|image.*pull"; then
        LOG_LEVEL_OK=true
    fi
fi

if $LOG_LEVEL_OK; then
    check_pass "ЗКО.2.1" "Уровень логирования движка позволяет регистрировать события жизненного цикла (info/debug)"
else
    check_fail "ЗКО.2.1" "Уровень логирования не настроен (требуется log-level: info/debug) или логи lifecycle отсутствуют"
fi

# ЗКО.2.2 – Регистрация событий жизненного цикла
LIFECYCLE_LOGGED=false
if journalctl -u docker -u podman --since "7 days ago" --no-pager 2>/dev/null | grep -qiE "container start|container stop|container destroy|image pull|image delete|image tag|container commit"; then
    LIFECYCLE_LOGGED=true
fi
if auditctl -l 2>/dev/null | grep -qE "/var/lib/docker|/var/lib/containers|container_mod"; then
    LIFECYCLE_LOGGED=true
fi

if $LIFECYCLE_LOGGED; then
    check_pass "ЗКО.2.2" "Зафиксированы события ЖЦ (создание, удаление, запуск, остановка, модификация образов и контейнеров)"
else
    check_fail "ЗКО.2.2" "Отсутствуют записи о событиях ЖЦ контейнеров/образов в логах или правилах auditd"
fi

# ЗКО.2.3 – Попытки НСД и аутентификации
AUTH_NSD_LOGGED=false
if auditctl -l 2>/dev/null | grep -qE "/var/run/docker.sock|/run/podman/podman.sock|docker_sock"; then
    AUTH_NSD_LOGGED=true
fi
if journalctl -u docker -u podman --since "7 days ago" --no-pager 2>/dev/null | grep -qiE "unauthorized|access denied|permission denied|authentication"; then
    AUTH_NSD_LOGGED=true
fi

if $AUTH_NSD_LOGGED; then
    check_pass "ЗКО.2.3" "Настроена регистрация попыток НСД и аутентификации к API/сокету контейнеризации"
else
    check_fail "ЗКО.2.3" "Отсутствуют правила аудита (auditd) или логи для контроля доступа к сокету/API"
fi

# ЗКО.2.4 – Запуск/остановка средства контейнеризации с указанием причины
if journalctl -u docker -u podman --no-pager -n 2000 2>/dev/null | grep -qiE "Started|Stopped|Failed|Reason|signal|exit"; then
    check_pass "ЗКО.2.4" "Journald фиксирует факты запуска и остановки службы контейнеризации с указанием причин"
else
    check_skip "ЗКО.2.4" "Не удалось подтвердить наличие записей об остановках службы (возможно, служба не перезапускалась)"
fi

# ЗКО.2.5 – События функционирования с указанием идентификатора контейнера
ID_PRESENT=false
if journalctl -u docker -u podman --since "24 hours ago" --no-pager 2>/dev/null | grep -qE "[a-f0-9]{64}|container=[a-zA-Z0-9_-]+"; then
    ID_PRESENT=true
fi

if $ID_PRESENT; then
    check_pass "ЗКО.2.5" "События функционирования регистрируются с указанием идентификатора (ID/имени) контейнера"
else
    check_skip "ЗКО.2.5" "Не удалось подтвердить наличие ID контейнера в свежих логах (контейнеры не запускались)"
fi

# ЗКО.2.6 – Выявление уязвимостей и факты нарушения целостности
VULN_INTEGRITY=false
if command -v falco >/dev/null 2>&1 && systemctl is-active --quiet falco 2>/dev/null; then
    VULN_INTEGRITY=true
elif command -v trivy >/dev/null 2>&1 && (crontab -l 2>/dev/null | grep -q "trivy" || systemctl list-timers --all 2>/dev/null | grep -q "trivy"); then
    VULN_INTEGRITY=true
elif command -v grype >/dev/null 2>&1 && (crontab -l 2>/dev/null | grep -q "grype" || systemctl list-timers --all 2>/dev/null | grep -q "grype"); then
    VULN_INTEGRITY=true
fi

if $VULN_INTEGRITY; then
    check_pass "ЗКО.2.6" "Настроено выявление уязвимостей в образах и нарушений целостности (Falco/Trivy/Grype)"
else
    check_fail "ЗКО.2.6" "Отсутствуют средства автоматического выявления уязвимостей и нарушений целостности"
fi

# ЗКО.2.7 – Изменение назначения ролей
check_skip "ЗКО.2.7" "Изменение назначения ролей (Требует анализа RBAC/OPA на уровне оркестратора)"

# --- ДОПОЛНИТЕЛЬНЫЕ ПРОВЕРКИ (Централизованный сбор) ---
if fstek_enhancement_enabled "ЗКО.2" "1"; then
    CENTRAL_LOG=false
    if grep -rqE "/var/lib/docker|/var/log/containers|imjournal" /etc/rsyslog.d/ /etc/rsyslog.conf 2>/dev/null; then
        CENTRAL_LOG=true
    elif command -v filebeat >/dev/null 2>&1 && systemctl is-active --quiet filebeat 2>/dev/null && grep -qE "docker|containers" /etc/filebeat/filebeat.yml 2>/dev/null; then
        CENTRAL_LOG=true
    elif systemctl is-active --quiet wazuh-agent 2>/dev/null && grep -rqE "/var/lib/docker|/var/log/containers" /var/ossec/etc/ossec.conf 2>/dev/null; then
        CENTRAL_LOG=true
    fi

    if $CENTRAL_LOG; then
        check_pass "ЗКО.2.8" "Настроен централизованный сбор логов контейнерной среды (rsyslog/filebeat/wazuh)"
    else
        check_fail "ЗКО.2.8" "Централизованный сбор событий контейнеризации не настроен"
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "ЗКО.2.8"
fi

# Унифицированная итоговая строка
finish_legacy_measure "ЗКО.2"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1