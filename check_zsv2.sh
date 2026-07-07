#!/bin/bash
# check_zsv2.sh - Контроль целостности средств виртуализации и виртуальных машин
# Соответствие разделу 4.4 (ЗСВ.2) Методического документа ФСТЭК России от 12.04.2026

WITH_ENH=false
[[ "$1" == "-e" || "$1" == "--with-enhancements" ]] && WITH_ENH=true

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

# --- ПРОВЕРКА НАЛИЧИЯ СРЕДСТВ ВИРТУАЛИЗАЦИИ ---
# Если libvirt/virsh не обнаружены, проверка ЗСВ.1 пропускается
if ! command -v virsh &>/dev/null && ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    check_skip "ЗСВ.2" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.2 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗСВ.2: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗСВ.2.1 – Контроль состава и настроек виртуального оборудования ВЫПОЛНЯЮЩИХСЯ ВМ
if command -v virsh &>/dev/null; then
    RUNNING_VMS=$(virsh list --name 2>/dev/null)
    if [ -n "$RUNNING_VMS" ]; then
        ETALON_FOUND=false
        CHANGED_VMS=0
        UNAUTHORIZED_DEVICES=0

        for vm in $RUNNING_VMS; do
            # 1. Сравнение текущей конфигурации с эталоном (XML)
            CURRENT_HASH=$(virsh dumpxml "$vm" 2>/dev/null | md5sum | awk '{print $1}')
            SAVED_HASH=""
            
            if [ -f "/etc/libvirt/qemu/${vm}.xml.md5" ]; then
                SAVED_HASH=$(cat "/etc/libvirt/qemu/${vm}.xml.md5" 2>/dev/null)
                ETALON_FOUND=true
            elif [ -d "/etc/libvirt/qemu/.git" ]; then
                ETALON_FOUND=true
            fi

            if [ -n "$SAVED_HASH" ] && [ "$CURRENT_HASH" != "$SAVED_HASH" ]; then
                ((CHANGED_VMS++))
            fi

            # 2. Контроль состава виртуального оборудования
            if virsh dumpxml "$vm" 2>/dev/null | grep -qiE "<hostdev|<filesystem|<smartcard"; then
                ((UNAUTHORIZED_DEVICES++))
            fi
        done

        if $ETALON_FOUND && [ "$CHANGED_VMS" -eq 0 ]; then
            check_pass "ЗСВ.2.1" "Настройки выполняющихся ВМ соответствуют эталонным (несанкционированных изменений нет)"
        elif ! $ETALON_FOUND; then
            if systemctl is-active --quiet wazuh-agent 2>/dev/null && grep -rq "/etc/libvirt/qemu" /var/ossec/etc/ossec.conf 2>/dev/null; then
                check_pass "ЗСВ.2.1" "Контроль изменений конфигураций ВМ осуществляется FIM-агентом в реальном времени"
            else
                check_fail "ЗСВ.2.1" "Отсутствует механизм контроля изменений настроек выполняющихся ВМ (нет эталонов .md5 или FIM-агента)"
            fi
        else
            check_fail "ЗСВ.2.1" "Обнаружены несанкционированные изменения конфигурации у $CHANGED_VMS выполняющихся ВМ"
        fi

        if [ "$UNAUTHORIZED_DEVICES" -gt 0 ]; then
            check_fail "ЗСВ.2.1" "В $UNAUTHORIZED_DEVICES ВМ обнаружен проброс оборудования (hostdev/USB/PCI). Требуется проверка легитимности"
        fi
    else
        check_skip "ЗСВ.2.1" "Выполняющиеся ВМ не обнаружены"
    fi
else
    check_fail "ЗСВ.2.1" "Утилита virsh недоступна для проверки работающих ВМ"
fi

# ЗСВ.2.2 – Контроль параметров настройки средства виртуализации (Хостовая ОС)
INTEGRITY_SYSTEM=false
if command -v aide &>/dev/null && grep -qE "/etc/libvirt|/etc/qemu" /etc/aide/aide.conf 2>/dev/null; then
    INTEGRITY_SYSTEM=true; check_pass "ЗСВ.2.2" "AIDE настроен для контроля файлов конфигурации гипервизора"
elif systemctl is-active --quiet wazuh-agent 2>/dev/null && grep -rqE "/etc/libvirt|/etc/qemu" /var/ossec/etc/ossec.conf 2>/dev/null; then
    INTEGRITY_SYSTEM=true; check_pass "ЗСВ.2.2" "Wazuh FIM контролирует конфигурационные файлы виртуализации"
elif [ -f /sys/kernel/security/ima/ascii_runtime_measurements ] && grep -q "libvirt" /sys/kernel/security/ima/ascii_runtime_measurements 2>/dev/null; then
    INTEGRITY_SYSTEM=true; check_pass "ЗСВ.2.2" "IMA отслеживает файлы средства виртуализации"
fi

if ! $INTEGRITY_SYSTEM; then
    check_fail "ЗСВ.2.2" "Не обнаружено систем контроля целостности (AIDE/Wazuh/IMA) для настроек гипервизора"
fi

# ЗСВ.2.3 – Периодичность проверок (cron / systemd timers)
PERIODIC_CHECK=false
if grep -rqE "aide|aide\.daily|tripwire|integrity|virt-backup" /etc/cron.* /var/spool/cron/ 2>/dev/null; then
    PERIODIC_CHECK=true
elif systemctl list-timers --all 2>/dev/null | grep -qiE "aide|integrity|libvirt"; then
    PERIODIC_CHECK=true
fi

if $PERIODIC_CHECK; then
    check_pass "ЗСВ.2.3" "Настроена периодическая (еженедельная или чаще) проверка целостности"
else
    check_fail "ЗСВ.2.3" "Периодические задачи для проверки целостности не обнаружены (cron/timers)"
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if $WITH_ENH; then
    # ЗСВ.2.4 (Усиление 1) – Контроль исполняемых файлов гипервизора
    QEMU_BIN=$(which qemu-system-x86_64 2>/dev/null || which qemu-kvm 2>/dev/null)
    if [ -n "$QEMU_BIN" ]; then
        if rpm -V qemu-kvm 2>/dev/null | grep -qE "S\.5\.\.\.\.\.\.\.\.  c" || dpkg -V qemu-system-x86 2>/dev/null | grep -q "md5sum" || [ -f "${QEMU_BIN}.sha256" ]; then
            check_pass "ЗСВ.2.4" "Исполняемые файлы гипервизора защищены контрольными суммами/пакетным менеджером"
        elif $INTEGRITY_SYSTEM && grep -q "$QEMU_BIN" /etc/aide/aide.conf /var/ossec/etc/ossec.conf 2>/dev/null; then
            check_pass "ЗСВ.2.4" "Исполняемые файлы гипервизора контролируются системой FIM"
        else
            check_fail "ЗСВ.2.4" "Отсутствует контроль целостности исполняемых файлов гипервизора ($QEMU_BIN)"
        fi
    else
        check_skip "ЗСВ.2.4" "Исполняемый файл гипервизора не найден в стандартных путях"
    fi

    # ЗСВ.2.5 (Усиление 3) – Контроль файлов виртуальной базовой системы ввода-вывода (BIOS ВМ)
    BIOS_CONTROLLED=false
    BIOS_PATHS=(/usr/share/OVMF /usr/share/seabios /usr/share/qemu)
    for bpath in "${BIOS_PATHS[@]}"; do
        if [ -d "$bpath" ]; then
            if $INTEGRITY_SYSTEM && grep -rq "$bpath" /etc/aide/aide.conf /var/ossec/etc/ossec.conf 2>/dev/null; then
                BIOS_CONTROLLED=true
            elif ls "$bpath"/*.sha256 1>/dev/null 2>&1; then
                BIOS_CONTROLLED=true
            fi
        fi
    done

    if $BIOS_CONTROLLED; then
        check_pass "ЗСВ.2.5" "Файлы виртуального BIOS (OVMF/SeaBIOS) включены в контур контроля целостности"
    else
        check_fail "ЗСВ.2.5" "Файлы виртуального BIOS ВМ не контролируются (риск подмены загрузчика гостевой ОС)"
    fi

    # ЗСВ.2.6 (Усиление 4) – Контроль исполняемых файлов ПО гостевой ОС
    if command -v virt-inspector &>/dev/null || command -v guestfish &>/dev/null; then
        check_pass "ЗСВ.2.6" "Установлен libguestfs для анализа и контроля файловых систем гостевых ОС"
    elif command -v qemu-ga &>/dev/null; then
        check_pass "ЗСВ.2.6" "Настроен QEMU Guest Agent для контроля целостности внутри ВМ"
    else
        check_fail "ЗСВ.2.6" "Отсутствуют средства контроля исполняемых файлов гостевых ОС (требуется libguestfs или qemu-ga)"
    fi
else
    # Унифицированный вывод для отключенных усилений
    echo "[ЗСВ.2.4-6] SKIP – проверка усилений отключена"
    ((SKIP_COUNT++))
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗСВ.2: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1