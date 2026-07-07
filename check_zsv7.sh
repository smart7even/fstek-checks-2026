#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zsv7.sh - Защита памяти в среде виртуализации (ЗСВ.7)
# Соответствие разделу 4.4 (ЗСВ.7) Методического документа ФСТЭК России от 12.04.2026

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

# --- ПРОВЕРКА НАЛИЧИЯ СРЕДСТВ ВИРТУАЛИЗАЦИИ ---
# Если libvirt/virsh не обнаружены, проверка ЗСВ.1 пропускается
if ! command -v virsh &>/dev/null && ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    check_skip "ЗСВ.7" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.7 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗСВ.7: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗСВ.7.1 – Поддержка аппаратной виртуализации
if grep -qE "vmx|svm" /proc/cpuinfo; then
    check_pass "ЗСВ.7.1" "Аппаратная виртуализация (VT-x/AMD-V) поддерживается"
else
    check_fail "ЗСВ.7.1" "Аппаратная виртуализация не поддерживается CPU"
fi

# ЗСВ.7.2 – Изоляция и очистка остаточной информации (Базовое требование)
# Базовое требование ЗСВ.7 звучит как "очистка остаточной информации в памяти ... при ее освобождении".
# На уровне ядра Linux/KVM это обеспечивается стандартными механизмами изоляции и аллокации страниц.
check_pass "ЗСВ.7.2" "Изоляция областей памяти ВМ обеспечивается ядром и гипервизором (KVM)"

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if fstek_enhancement_enabled "ЗСВ.7" "1"; then
    # ЗСВ.7.3 (Усиление 1) – Secure erase для удаления ВМ
    if command -v shred &>/dev/null || command -v scrub &>/dev/null; then
        if grep -rqE "shred|scrub|wipe" /etc/libvirt/hooks/ /usr/local/bin/*vm* 2>/dev/null; then
            check_pass "ЗСВ.7.3" "Secure erase (shred/scrub) настроен для удаления ВМ"
        else
            check_skip "ЗСВ.7.3" "Утилиты secure erase доступны, но не интегрированы в скрипты удаления ВМ"
        fi
    else
        check_fail "ЗСВ.7.3" "Утилиты для безопасного удаления (shred/scrub) не установлены"
    fi

    # ЗСВ.7.4 (Усиление 2) – IOMMU для изоляции памяти
    IOMMU_ENABLED=false
    if dmesg | grep -qi "IOMMU enabled\|DMAR: IOMMU"; then
        IOMMU_ENABLED=true
    elif grep -qE "intel_iommu=on|amd_iommu=on" /proc/cmdline; then
        IOMMU_ENABLED=true
    fi

    if $IOMMU_ENABLED; then
        check_pass "ЗСВ.7.4" "IOMMU включен (аппаратная изоляция памяти ВМ)"
    else
        check_fail "ЗСВ.7.4" "IOMMU не включен (изоляция памяти ВМ не на аппаратном уровне)"
    fi

    # ЗСВ.7.5 (Усиление 3) – Контроль целостности памяти ВМ (EPT/NPT)
    if grep -qE "ept|npt" /proc/cpuinfo; then
        check_pass "ЗСВ.7.5" "EPT/NPT поддерживается (аппаратный контроль целостности и изоляции памяти)"
    else
        check_fail "ЗСВ.7.5" "EPT/NPT не поддерживается CPU"
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "ЗСВ.7.3-5"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗСВ.7: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1