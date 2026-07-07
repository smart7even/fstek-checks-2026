#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zsv1.sh - Доверенная загрузка средств виртуализации и виртуальных машин
# Соответствие разделу 4.4 (ЗСВ.1) Методического документа ФСТЭК России от 12.04.2026

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
    check_skip "ЗСВ.1" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.1 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗСВ.1: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗСВ.1.1 – Доверенная загрузка хостовой ОС (Secure Boot)
SECURE_BOOT=false
if [ -f /sys/firmware/efi/efivars/SecureBoot-* ]; then
    SB_STATUS=$(od -An -tx1 /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | awk '{print $5}')
    if [ "$SB_STATUS" == "01" ]; then
        SECURE_BOOT=true
        check_pass "ЗСВ.1.1" "UEFI Secure Boot хостовой ОС включен"
    else
        check_fail "ЗСВ.1.1" "UEFI Secure Boot хостовой ОС отключен"
    fi
elif command -v mokutil &>/dev/null && mokutil --sb-state 2>/dev/null | grep -q "enabled"; then
    SECURE_BOOT=true
    check_pass "ЗСВ.1.1" "UEFI Secure Boot хостовой ОС включен (mokutil)"
else
    check_skip "ЗСВ.1.1" "Не удалось определить статус Secure Boot (возможно, legacy BIOS)"
fi

# ЗСВ.1.2 – Целостность средства виртуализации (Модули KVM)
if lsmod | grep -qE "^kvm|^vhost"; then
    if [ -f /proc/sys/kernel/modules_disabled ] && [ "$(cat /proc/sys/kernel/modules_disabled)" == "1" ]; then
        check_pass "ЗСВ.1.2" "Загрузка неподписанных модулей ядра запрещена (modules_disabled=1)"
    elif modinfo kvm 2>/dev/null | grep -q "sig_id\|signature"; then
        check_pass "ЗСВ.1.2" "Модули KVM подписаны цифровой подписью (Module Sig)"
    else
        check_fail "ЗСВ.1.2" "Модули KVM загружены, но проверка подписи не подтверждена"
    fi
else
    check_skip "ЗСВ.1.2" "Модули KVM не загружены как отдельные (возможно, встроены в ядро)"
fi

# ЗСВ.1.3 – Выявление несанкционированных изменений настроек ВМ
INTEGRITY_VM=false
if command -v aide &>/dev/null && grep -qE "/etc/libvirt/qemu" /etc/aide/aide.conf 2>/dev/null; then
    INTEGRITY_VM=true; check_pass "ЗСВ.1.3" "AIDE настроен для контроля целостности XML-конфигураций ВМ"
elif systemctl is-active --quiet wazuh-agent 2>/dev/null && grep -rqE "/etc/libvirt/qemu" /var/ossec/etc/ossec.conf 2>/dev/null; then
    INTEGRITY_VM=true; check_pass "ЗСВ.1.3" "Wazuh FIM настроен для контроля конфигураций ВМ"
elif [ -f /sys/kernel/security/ima/ascii_runtime_measurements ] && grep -q "libvirt" /sys/kernel/security/ima/ascii_runtime_measurements 2>/dev/null; then
    INTEGRITY_VM=true; check_pass "ЗСВ.1.3" "IMA (Integrity Measurement Architecture) отслеживает файлы виртуализации"
fi

if ! $INTEGRITY_VM; then
    check_fail "ЗСВ.1.3" "Не обнаружено механизмов контроля целостности конфигураций ВМ (AIDE/Wazuh/IMA)"
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if fstek_enhancement_enabled "ЗСВ.1" "1"; then
    # ЗСВ.1.4 (Усиление 1, 3, 4) – Политики блокировки загрузки ВМ и проверка подписей гостевых ОС
    VM_SECURE_BOOT=0
    VM_TOTAL=0
    if command -v virsh &>/dev/null; then
        for vm in $(virsh list --all --name 2>/dev/null); do
            ((VM_TOTAL++))
            if virsh dumpxml "$vm" 2>/dev/null | grep -qiE "loader.*secure='yes'|smm.*state='on'"; then
                ((VM_SECURE_BOOT++))
            fi
        done
    fi

    if [ "$VM_TOTAL" -gt 0 ]; then
        if [ "$VM_SECURE_BOOT" -eq "$VM_TOTAL" ]; then
            check_pass "ЗСВ.1.4" "Для всех ВМ ($VM_TOTAL) включен UEFI Secure Boot (аутентификация загрузчиков гостевых ОС)"
        elif [ "$VM_SECURE_BOOT" -gt 0 ]; then
            check_fail "ЗСВ.1.4" "Только для $VM_SECURE_BOOT из $VM_TOTAL ВМ включен UEFI Secure Boot"
        else
            check_fail "ЗСВ.1.4" "Для ВМ не настроен UEFI Secure Boot (loader secure='yes' / SMM)"
        fi
    else
        check_skip "ЗСВ.1.4" "ВМ не найдены для проверки гостевого Secure Boot"
    fi

    # ЗСВ.1.5 – Наличие механизмов предзагрузочной проверки (libvirt hooks)
    if [ -d /etc/libvirt/hooks ] && [ -n "$(ls -A /etc/libvirt/hooks/ 2>/dev/null)" ]; then
        if grep -rqE "exit 1|deny|block|signature" /etc/libvirt/hooks/ 2>/dev/null; then
            check_pass "ЗСВ.1.5" "Обнаружены хуки libvirt для предзагрузочной проверки и блокировки ВМ"
        else
            check_skip "ЗСВ.1.5" "Хуки libvirt присутствуют, но явной логики блокировки не обнаружено"
        fi
    else
        check_fail "ЗСВ.1.5" "Отсутствуют хуки libvirt (/etc/libvirt/hooks/) для реализации политик блокировки"
    fi

    # ЗСВ.1.6 – Фактическая регистрация блокировок (Анализ логов)
    BLOCK_LOGS=false
    if journalctl -u libvirtd --no-pager -n 5000 2>/dev/null | grep -qiE "blocked|denied|secure boot.*failed|signature.*mismatch|operation not permitted"; then
        BLOCK_LOGS=true
    fi
    if ausearch -m AVC -c qemu-kvm 2>/dev/null | grep -q "denied"; then
        BLOCK_LOGS=true
    fi

    if $BLOCK_LOGS; then
        check_pass "ЗСВ.1.6" "Обнаружены логи блокировки загрузки ВМ (механизм блокировки функционирует)"
    else
        check_skip "ЗСВ.1.6" "Логи блокировки загрузки ВМ не обнаружены (возможно, нарушений не было)"
    fi

else
    skip_enhancement "ЗСВ.1.4-6"
fi

# ЗСВ.1.7 (Усиление 2) – Блокировка запрещенных/уязвимых версий гостевых ОС
if fstek_enhancement_enabled "ЗСВ.1" "2"; then
    if grep -rqE "windows.*xp|centos.*6|ubuntu.*14|unsupported.*os|vuln.*os" /etc/libvirt/hooks/ /usr/local/bin/ 2>/dev/null; then
        check_pass "ЗСВ.1.7" "Обнаружен скрипт/хук для блокировки ВМ с устаревшими/запрещенными ОС"
    else
        check_fail "ЗСВ.1.7" "Автоматическая блокировка ВМ по версии гостевой ОС не настроена"
    fi
else
    skip_enhancement "ЗСВ.1.7"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗСВ.1: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
