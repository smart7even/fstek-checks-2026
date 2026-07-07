#!/bin/bash
# check_zsv4.sh - Управление доступом в среде виртуализации (ЗСВ.4)
# Соответствие разделу 4.4 (ЗСВ.4) Методического документа ФСТЭК России от 12.04.2026

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

# --- ПРОВЕРКА НАЛИЧИЯ СРЕДСТВ ВИРТУАЛИЗАЦИИ ---
# Если libvirt/virsh не обнаружены, проверка ЗСВ.1 пропускается
if ! command -v virsh &>/dev/null && ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    check_skip "ЗСВ.4" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.4 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗСВ.4: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗСВ.4.1 – Управление правами доступа пользователей средств виртуализации к ВМ
ACCESS_CTRL=false
if [ -d /etc/polkit-1/rules.d ] || [ -d /etc/polkit-1/localauthority.conf.d ]; then
    if grep -rqE "libvirt|qemu" /etc/polkit-1/ 2>/dev/null; then
        ACCESS_CTRL=true
    fi
fi
if grep -qE "^unix_sock_group|^unix_sock_rw_perms|^unix_sock_ro_perms" /etc/libvirt/libvirtd.conf 2>/dev/null; then
    ACCESS_CTRL=true
fi

if $ACCESS_CTRL; then
    check_pass "ЗСВ.4.1" "Настроено ограничение доступа пользователей к API libvirt (Polkit / Unix socket)"
else
    check_fail "ЗСВ.4.1" "Отсутствуют явные настройки ограничения доступа к интерфейсу виртуализации"
fi

# ЗСВ.4.2 – Управление доступом ВМ к физическому и виртуальному оборудованию
if command -v virsh &>/dev/null; then
    VMS=$(virsh list --all --name 2>/dev/null)
    if [ -n "$VMS" ]; then
        PASSTHROUGH_VIOLATIONS=0
        
        for vm in $VMS; do
            XML=$(virsh dumpxml "$vm" 2>/dev/null)
            
            # Проверка проброса физических устройств и внешних ФС
            HOSTDEV_COUNT=$(echo "$XML" | grep -c "<hostdev" || echo "0")
            FS_COUNT=$(echo "$XML" | grep -c "<filesystem" || echo "0")
            TOTAL_DEVICES=$((HOSTDEV_COUNT + FS_COUNT))
            
            if [ "$TOTAL_DEVICES" -gt 0 ]; then
                ((PASSTHROUGH_VIOLATIONS+=TOTAL_DEVICES))
                # Информационный вывод (без цветов, чтобы не ломать парсинг)
                echo "  ! ВМ '$vm': обнаружен проброс оборудования (hostdev: $HOSTDEV_COUNT, filesystem: $FS_COUNT). Требуется проверка легитимности."
            fi
        done
        
        if [ "$PASSTHROUGH_VIOLATIONS" -eq 0 ]; then
            check_pass "ЗСВ.4.2" "Проброс физического оборудования (USB/PCI) и внешних ФС в ВМ отсутствует"
        else
            check_fail "ЗСВ.4.2" "Обнаружено $PASSTHROUGH_VIOLATIONS фактов подключения оборудования/ФС к ВМ. Требуется верификация"
        fi
    else
        check_skip "ЗСВ.4.2" "Виртуальные машины не найдены"
    fi
else
    check_skip "ЗСВ.4.2" "Утилита virsh недоступна для анализа конфигураций ВМ"
fi

# ЗСВ.4.3 – Управление квотами доступа ВМ к ресурсам
if command -v virsh &>/dev/null; then
    VMS=$(virsh list --all --name 2>/dev/null)
    if [ -n "$VMS" ]; then
        QUOTAS_OK=0
        VMS_TOTAL=0
        
        for vm in $VMS; do
            ((VMS_TOTAL++))
            XML=$(virsh dumpxml "$vm" 2>/dev/null)
            
            if echo "$XML" | grep -qE "<memtune>|<cputune>|<blkiotune>|<iotune>"; then
                ((QUOTAS_OK++))
            else
                if virsh dominfo "$vm" 2>/dev/null | grep -qE "CPU limit|Max memory"; then
                    ((QUOTAS_OK++))
                fi
            fi
        done
        
        if [ "$QUOTAS_OK" -eq "$VMS_TOTAL" ] && [ "$VMS_TOTAL" -gt 0 ]; then
            check_pass "ЗСВ.4.3" "Для всех ВМ ($VMS_TOTAL) настроены квоты и ограничения ресурсов (CPU/RAM/I/O)"
        elif [ "$QUOTAS_OK" -gt 0 ]; then
            check_fail "ЗСВ.4.3" "Квоты ресурсов настроены только для $QUOTAS_OK из $VMS_TOTAL ВМ"
        else
            check_fail "ЗСВ.4.3" "Квоты и ограничения ресурсов (cgroups/memtune) для ВМ не настроены"
        fi
    else
        check_skip "ЗСВ.4.3" "ВМ не найдены для проверки квот"
    fi
else
    check_skip "ЗСВ.4.3" "Утилита virsh недоступна"
fi

# ЗСВ.4.4 – Мандатное управление доступом и изоляция (sVirt / SELinux / AppArmor)
ISOLATION_CONFIGURED=false
if command -v getenforce &>/dev/null && [ "$(getenforce 2>/dev/null)" == "Enforcing" ]; then
    if sestatus 2>/dev/null | grep -q "svirt\|virt_use" || grep -qE "security_driver\s*=\s*\"selinux\"" /etc/libvirt/qemu.conf 2>/dev/null; then
        ISOLATION_CONFIGURED=true
        check_pass "ЗСВ.4.4" "SELinux + sVirt активны (мандатное управление доступом ВМ к ресурсам хоста)"
    fi
elif command -v aa-status &>/dev/null && aa-status 2>/dev/null | grep -q "libvirt\|qemu"; then
    ISOLATION_CONFIGURED=true
    check_pass "ЗСВ.4.4" "AppArmor профили для libvirt/QEMU активны"
fi

if ! $ISOLATION_CONFIGURED; then
    check_fail "ЗСВ.4.4" "Мандатное управление доступом и изоляция ВМ (SELinux/sVirt/AppArmor) не настроены"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗСВ.4: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1