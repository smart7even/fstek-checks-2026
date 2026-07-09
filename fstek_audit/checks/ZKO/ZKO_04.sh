#!/usr/bin/env bash
# fstek_audit/checks/ZKO/ZKO_04.sh - migrated measure logic for ЗКО.4.

run_check() {
    # check_zko4.sh - Резервное копирование в контейнерных средах (ЗКО.4)
    # Соответствие разделу 4.5 (ЗКО.4) Методического документа ФСТЭК России от 12.04.2026

    WITH_ENH=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENH=true ;;
        esac
    done


    # Унифицированные функции вывода

    ENGINE="none"
    if command -v docker >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then ENGINE="docker";
    elif command -v podman >/dev/null 2>&1; then ENGINE="podman"; fi

    if [ "$ENGINE" == "none" ]; then
        check_skip "ЗКО.4.0" "Средства контейнеризации не обнаружены или не активны"
        finish_legacy_measure "ЗКО.4"
        exit 0
    fi

    # Стандартные директории, где могут храниться резервные копии
    BACKUP_DIRS=("/backup" "/var/backups" "/mnt/backup" "/opt/backup" "/srv/backup" "/store")

    # --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

    # ЗКО.4.1 - Фактическое наличие резервных копий образов контейнеров
    IMAGE_BACKUPS=0
    for dir in "${BACKUP_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            COUNT=$(find "$dir" -type f \( -name "*.tar" -o -name "*.tar.gz" -o -name "*.qcow2" -o -name "*.img" -o -name "*.vmdk" \) -mtime -7 2>/dev/null | grep -ciE "container|image|docker|registry|podman")
            IMAGE_BACKUPS=$((IMAGE_BACKUPS + COUNT))
        fi
    done

    if [ "$IMAGE_BACKUPS" -gt 0 ]; then
        check_pass "ЗКО.4.1" "Обнаружено $IMAGE_BACKUPS свежих резервных копий образов контейнеров (за последние 7 дней)"
    else
        # Альтернатива: использование специализированных утилит оркестрации (например, Velero для K8s)
        if command -v velero >/dev/null 2>&1 && velero backup get 2>/dev/null | grep -q "Completed"; then
            check_pass "ЗКО.4.1" "Обнаружены успешные резервные копии через систему Velero"
        else
            check_fail "ЗКО.4.1" "Свежие резервные копии образов контейнеров не обнаружены в стандартных директориях хранения"
        fi
    fi

    # --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
    if fstek_enhancement_enabled "ЗКО.4" "1" "2"; then
        # ЗКО.4.2 (Усиление 1) - Резервное копирование параметров настройки средств контейнеризации
        CONF_BACKUP=false
        CONF_DIR="/etc/docker"
        [ "$ENGINE" == "podman" ] && CONF_DIR="/etc/containers"

        for dir in "${BACKUP_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                if find "$dir" -type f \( -name "*docker*.tar*" -o -name "*docker*.bak" -o -name "*containers*.tar*" -o -path "*etc/docker*" -o -path "*etc/containers*" \) -mtime -7 2>/dev/null | grep -q .; then
                    CONF_BACKUP=true; break
                fi
            fi
        done

        if $CONF_BACKUP; then
            check_pass "ЗКО.4.2" "Обнаружены резервные копии параметров настройки средства контейнеризации ($CONF_DIR)"
        else
            check_fail "ЗКО.4.2" "Резервные копии конфигурации средства контейнеризации не обнаружены"
        fi

        # ЗКО.4.3 (Усиление 2) - Резервное копирование сведений о событиях безопасности
        LOG_BACKUP=false
        for dir in "${BACKUP_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                if find "$dir" -type f \( -path "*log*container*" -o -path "*log*docker*" -o -path "*log*podman*" -o -name "*docker*.log*" -o -name "*container*.log*" \) -mtime -7 2>/dev/null | grep -q .; then
                    LOG_BACKUP=true; break
                fi
            fi
        done

        # Альтернатива: передача логов в SIEM/Filebeat/Wazuh
        if systemctl is-active --quiet filebeat 2>/dev/null && grep -qE "containers|docker" /etc/filebeat/filebeat.yml 2>/dev/null; then
            LOG_BACKUP=true
        elif systemctl is-active --quiet wazuh-agent 2>/dev/null && grep -rqE "/var/lib/docker|/var/log/containers" /var/ossec/etc/ossec.conf 2>/dev/null; then
            LOG_BACKUP=true
        fi

        if $LOG_BACKUP; then
            check_pass "ЗКО.4.3" "Обнаружены резервные копии (или централизованный сбор с хранением) логов и событий безопасности контейнерной среды"
        else
            check_fail "ЗКО.4.3" "Резервное копирование сведений о событиях безопасности в среде контейнеризации не обнаружено"
        fi
    else
        # Унифицированный вывод для отключенных усилений
        skip_enhancement "ЗКО.4.2-3"
    fi

    # ЗКО.4.4 - Техническая проверка целостности резервных копий
    TEST_BACKUP=""
    for dir in "${BACKUP_DIRS[@]}"; do
        TEST_BACKUP=$(find "$dir" -type f -name "*.tar" 2>/dev/null | grep -iE "image|container|docker" | head -1)
        [ -n "$TEST_BACKUP" ] && break
    done

    if [ -n "$TEST_BACKUP" ]; then
        # Проверяем, является ли файл валидным tar-архивом
        if tar -tf "$TEST_BACKUP" >/dev/null 2>&1; then
            check_pass "ЗКО.4.4" "Резервные копии образов (tar-архивы) проходят проверку целостности структуры"
        else
            check_fail "ЗКО.4.4" "Обнаружен поврежденный архив резервной копии: $TEST_BACKUP"
        fi
    else
        check_skip "ЗКО.4.4" "Не найдено tar-архивов образов для проверки целостности"
    fi

    # Унифицированная итоговая строка
    finish_legacy_measure "ЗКО.4"
}
