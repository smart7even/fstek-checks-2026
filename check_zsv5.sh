#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zsv5.sh - Резервное копирование в среде виртуализации (ЗСВ.5)
# Соответствие разделу 4.4 (ЗСВ.5) Методического документа ФСТЭК России от 12.04.2026

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
check_skip() { fstek_status_line "$1" "SKIP" "$2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

# Стандартные директории, где могут храниться резервные копии
BACKUP_DIRS=("/backup" "/var/backups" "/mnt/backup" "/opt/backup" "/srv/backup" "/store")

# --- ПРОВЕРКА НАЛИЧИЯ СРЕДСТВ ВИРТУАЛИЗАЦИИ ---
# Если libvirt/virsh не обнаружены, проверка ЗСВ.1 пропускается
if ! command -v virsh &>/dev/null && ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    check_skip "ЗСВ.5" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.5 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗСВ.5: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗСВ.5.1 – Резервное копирование образов виртуальных машин
VM_BACKUPS_FOUND=0
for dir in "${BACKUP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        COUNT=$(find "$dir" -type f \( -name "*.qcow2" -o -name "*.raw" -o -name "*.vmdk" -o -name "*.img" -o -name "*.vdi" \) -mtime -7 2>/dev/null | wc -l)
        VM_BACKUPS_FOUND=$((VM_BACKUPS_FOUND + COUNT))
    fi
done

if [ "$VM_BACKUPS_FOUND" -gt 0 ]; then
    check_pass "ЗСВ.5.1" "Обнаружено $VM_BACKUPS_FOUND свежих резервных копий образов ВМ (за последние 7 дней)"
else
    check_fail "ЗСВ.5.1" "Свежие резервные копии образов ВМ не обнаружены в стандартных директориях хранения"
fi

# ЗСВ.5.2 – Резервное копирование параметров настройки средств виртуализации
LIBVIRT_BACKUP=false
for dir in "${BACKUP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        if find "$dir" -type d -name "libvirt" 2>/dev/null | grep -q .; then
            LIBVIRT_BACKUP=true; break
        fi
        if find "$dir" -type f \( -name "*libvirt*.tar*" -o -name "*libvirt*.zip" -o -name "*libvirt*.bak" \) -mtime -7 2>/dev/null | grep -q .; then
            LIBVIRT_BACKUP=true; break
        fi
    fi
done

if $LIBVIRT_BACKUP; then
    check_pass "ЗСВ.5.2" "Обнаружены резервные копии параметров настройки средства виртуализации (/etc/libvirt)"
else
    check_fail "ЗСВ.5.2" "Резервные копии настроек гипервизора не обнаружены"
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if fstek_enhancement_enabled "ЗСВ.5" "1"; then
    # ЗСВ.5.3 (Усиление 1) – Резервное копирование конфигураций виртуального оборудования ВМ
    XML_BACKUPS=0
    for dir in "${BACKUP_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            COUNT=$(find "$dir" -type f -name "*.xml" 2>/dev/null | grep -ciE "qemu|vm|libvirt")
            XML_BACKUPS=$((XML_BACKUPS + COUNT))
        fi
    done
    
    if [ "$XML_BACKUPS" -gt 0 ]; then
        check_pass "ЗСВ.5.3" "Резервные копии конфигураций виртуального оборудования ВМ (XML-файлы) присутствуют"
    else
        check_fail "ЗСВ.5.3" "Не обнаружены резервные копии XML-конфигураций виртуального оборудования ВМ"
    fi

    # ЗСВ.5.4 (Усиление 2) – Резервное копирование сведений о событиях безопасности
    LOG_BACKUP=false
    for dir in "${BACKUP_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            if find "$dir" -type f \( -path "*log*libvirt*" -o -path "*log*qemu*" -o -name "*libvirtd*.log*" \) -mtime -7 2>/dev/null | grep -q .; then
                LOG_BACKUP=true; break
            fi
        fi
    done
    
    if $LOG_BACKUP; then
        check_pass "ЗСВ.5.4" "Обнаружены резервные копии логов (событий безопасности) среды виртуализации"
    else
        check_fail "ЗСВ.5.4" "Резервное копирование логов виртуализации (/var/log/libvirt) не обнаружено"
    fi

    # ЗСВ.5.5 – Техническая проверка целостности резервных копий образов ВМ
    if command -v qemu-img &>/dev/null; then
        TEST_BACKUP=""
        for dir in "${BACKUP_DIRS[@]}"; do
            TEST_BACKUP=$(find "$dir" -type f -name "*.qcow2" 2>/dev/null | head -1)
            [ -n "$TEST_BACKUP" ] && break
        done
        
        if [ -n "$TEST_BACKUP" ]; then
            if qemu-img check "$TEST_BACKUP" &>/dev/null; then
                check_pass "ЗСВ.5.5" "Резервные копии образов ВМ проходят проверку целостности (qemu-img check)"
            else
                check_fail "ЗСВ.5.5" "Обнаружена резервная копия ВМ с нарушением целостности: $TEST_BACKUP"
            fi
        else
            check_skip "ЗСВ.5.5" "Не найдено образов .qcow2 для проверки целостности"
        fi
    else
        check_skip "ЗСВ.5.5" "Утилита qemu-img недоступна для проверки целостности образов"
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "ЗСВ.5.3-5"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗСВ.5: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1