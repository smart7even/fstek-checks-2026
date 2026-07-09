#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zsv6.sh - Ограничение программной среды в среде виртуализации (ЗСВ.6)
# Соответствие разделу 4.4 (ЗСВ.6) Методического документа ФСТЭК России от 12.04.2026

WITH_ENH=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENH=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода

OS="generic"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_MATCH="$(printf '%s' "${ID:-} ${ID_LIKE:-} ${NAME:-} ${PRETTY_NAME:-}" | tr '[:upper:]' '[:lower:]')"
    [[ "$OS_MATCH" == *"astra"* || "$OS_MATCH" == *"alse"* ]] && OS="astra"
fi

# --- ПРОВЕРКА НАЛИЧИЯ СРЕДСТВ ВИРТУАЛИЗАЦИИ ---
# Если libvirt/virsh не обнаружены, проверка ЗСВ.1 пропускается
if ! command -v virsh &>/dev/null && ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    check_skip "ЗСВ.6" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.6 пропущена."
    finish_legacy_measure "ЗСВ.6"
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗСВ.6.1 – AppArmor/SELinux для ограничения программ
if command -v aa-status &>/dev/null && aa-status 2>/dev/null | grep -q "libvirt\|qemu"; then
    check_pass "ЗСВ.6.1" "AppArmor профили ограничивают ПО виртуализации"
elif command -v getenforce &>/dev/null && [ "$(getenforce 2>/dev/null)" == "Enforcing" ]; then
    check_pass "ЗСВ.6.1" "SELinux ограничивает ПО виртуализации"
else
    check_fail "ЗСВ.6.1" "Мандатное ограничение ПО (AppArmor/SELinux) не настроено"
fi

# ЗСВ.6.2 – Замкнутая программная среда (Astra PARSEC)
if [ "$OS" == "astra" ]; then
    if systemctl is-active --quiet parsecd 2>/dev/null; then
        check_pass "ЗСВ.6.2" "Astra PARSEC активен (замкнутая программная среда)"
    else
        check_fail "ЗСВ.6.2" "Astra PARSEC не активен (замкнутая среда не настроена)"
    fi
else
    # Для других ОС проверяем наличие whitelist/blacklist модулей
    if [ -f /etc/apparmor.d/local/usr.sbin.libvirtd ] || [ -f /etc/selinux/targeted/modules/active/modules/libvirt.pp ]; then
        check_pass "ЗСВ.6.2" "Настроены ограничения для libvirt (AppArmor/SELinux модули)"
    else
        check_skip "ЗСВ.6.2" "Замкнутая программная среда не обнаружена (возможно, не требуется для данной ОС)"
    fi
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if fstek_enhancement_enabled "ЗСВ.6" "1"; then
    # ЗСВ.6.3 (Усиление 1) – Блокировка запуска неразрешенного ПО
    if [ "$OS" == "astra" ]; then
        # Проверяем режим ЗПС
        if grep -q "mode.*strict\|mode.*enforce" /etc/parsecd/parsecd.conf 2>/dev/null; then
            check_pass "ЗСВ.6.3" "Замкнутая программная среда в режиме блокировки"
        else
            check_fail "ЗСВ.6.3" "ЗПС не в режиме блокировки неразрешенного ПО"
        fi
    else
        # Проверяем наличие security driver для гипервизора
        if [ -f /etc/libvirt/qemu.conf ] && grep -q "security_driver.*selinux\|security_driver.*apparmor" /etc/libvirt/qemu.conf; then
            check_pass "ЗСВ.6.3" "Security driver настроен для блокировки неразрешенного ПО"
        else
            check_fail "ЗСВ.6.3" "Блокировка запуска неразрешенного ПО не настроена"
        fi
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "ЗСВ.6.3"
fi

# Унифицированная итоговая строка
finish_legacy_measure "ЗСВ.6"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
