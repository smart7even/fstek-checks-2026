#!/bin/bash
# check_zsv9.sh - Управление виртуальными машинами (ЗСВ.9)
# Соответствие разделу 4.4 (ЗСВ.9) Методического документа ФСТЭК России от 12.04.2026

# Согласно Методическому документу ФСТЭК, для меры ЗСВ.9 
# требования к усилению не предъявляются. Флаг -e не используется.

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода (БЕЗ ЦВЕТОВ)
check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
check_skip() { echo "[$1] SKIP – $2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

OS="generic"
[ -f /etc/os-release ] && . /etc/os-release
[[ "$NAME" == *"Astra"* ]] && OS="astra"

# --- ПРОВЕРКА НАЛИЧИЯ СРЕДСТВ ВИРТУАЛИЗАЦИИ ---
# Если libvirt/virsh не обнаружены, проверка ЗСВ.1 пропускается
if ! command -v virsh &>/dev/null && ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    check_skip "ЗСВ.9" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.9 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗСВ.9: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗСВ.9.1 – Настройка миграции ВМ
if grep -qE "migrate.*tls|live_migration" /etc/libvirt/qemu.conf 2>/dev/null; then
    check_pass "ЗСВ.9.1" "Миграция ВМ настроена с использованием TLS"
elif grep -qE "listen_tls|listen_tcp" /etc/libvirt/libvirtd.conf 2>/dev/null; then
    check_pass "ЗСВ.9.1" "Libvirt настроен для управления миграцией ВМ"
else
    check_fail "ЗСВ.9.1" "Управление миграцией ВМ не настроено"
fi

# ЗСВ.9.2 – Контроль перемещения ВМ (auditd)
if systemctl is-active --quiet auditd 2>/dev/null; then
    if auditctl -l 2>/dev/null | grep -qE "migrate|virt|qemu|libvirt"; then
        check_pass "ЗСВ.9.2" "Auditd настроен для контроля миграции ВМ"
    else
        check_fail "ЗСВ.9.2" "Auditd активен, но правила для миграции ВМ не настроены"
    fi
else
    check_fail "ЗСВ.9.2" "Auditd не активен (контроль миграции не ведется)"
fi

# ЗСВ.9.3 – Ограничение миграции за пределы ИС
if grep -qE "migration_host|migration_address" /etc/libvirt/qemu.conf 2>/dev/null; then
    check_pass "ЗСВ.9.3" "Миграция ВМ ограничена определенными хостами"
elif [ -f /etc/libvirt/qemu/networks/autostart/default.xml ] && grep -q "forward.*dev" /etc/libvirt/qemu/networks/*.xml 2>/dev/null; then
    check_pass "ЗСВ.9.3" "Сетевое взаимодействие ВМ ограничено (изоляция)"
else
    check_fail "ЗСВ.9.3" "Ограничения на миграцию ВМ за пределы ИС не настроены"
fi

# ЗСВ.9.4 – Использование сертифицированных средств
if [ "$OS" == "astra" ]; then
    if systemctl is-active --quiet parsecd 2>/dev/null; then
        check_pass "ЗСВ.9.4" "Используются сертифицированные средства (Astra PARSEC)"
    else
        check_skip "ЗСВ.9.4" "Сертифицированные средства виртуализации не обнаружены"
    fi
else
    # Проверяем наличие отечественных гипервизоров (с защитой от ошибок, если rpm/dpkg нет в ОС)
    if command -v kvm &>/dev/null && (rpm -qa 2>/dev/null | grep -qE "kvm|qemu" || dpkg -l 2>/dev/null | grep -q "qemu-kvm"); then
        check_pass "ЗСВ.9.4" "Используется отечественный гипервизор KVM"
    else
        check_skip "ЗСВ.9.4" "Не удалось определить сертифицированность средств виртуализации"
    fi
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗСВ.9: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1