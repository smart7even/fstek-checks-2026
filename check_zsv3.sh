#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zsv3.sh - Регистрация событий безопасности в среде виртуализации (ЗСВ.3)
# Соответствие разделу 4.4 (ЗСВ.3) Методического документа ФСТЭК России от 12.04.2026

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода

# --- ПРОВЕРКА НАЛИЧИЯ СРЕДСТВ ВИРТУАЛИЗАЦИИ ---
# Если libvirt/virsh не обнаружены, проверка ЗСВ.1 пропускается
if ! command -v virsh &>/dev/null && ! systemctl is-active --quiet libvirtd 2>/dev/null; then
    check_skip "ЗСВ.3" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.3 пропущена."
    finish_legacy_measure "ЗСВ.3"
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗСВ.3.1 – Аудит изменений конфигураций средства виртуализации и ВМ
if auditctl -l 2>/dev/null | grep -qE "/etc/libvirt|/etc/qemu|libvirt_config"; then
    check_pass "ЗСВ.3.1" "Auditd: Настроен контроль изменений конфигураций СВ и ВМ (-w /etc/libvirt -p wa)"
else
    check_fail "ЗСВ.3.1" "Auditd: Отсутствуют правила контроля изменений конфигураций СВ и ВМ"
fi

# ЗСВ.3.2 – Аудит жизненного цикла ВМ (создание, удаление, запуск, остановка, перемещение)
LIBVIRT_LOGS_OK=false
if grep -qE "^log_level\s*=\s*[0-2]|log_filters.*libvirt" /etc/libvirt/libvirtd.conf 2>/dev/null; then
    LIBVIRT_LOGS_OK=true
fi

if $LIBVIRT_LOGS_OK; then
    check_pass "ЗСВ.3.2" "Libvirt: Включено логирование событий жизненного цикла ВМ"
elif auditctl -l 2>/dev/null | grep -qE "virsh|virt-install|qemu-img|vm_lifecycle"; then
    check_pass "ЗСВ.3.2" "Auditd: Настроен контроль команд управления жизненным циклом ВМ"
else
    check_fail "ЗСВ.3.2" "Не настроена регистрация событий жизненного цикла ВМ"
fi

# ЗСВ.3.3 – Аудит аутентификации и доступа к интерфейсу средства виртуализации
AUTH_LOGGED=false
if [ -f /var/log/libvirt/libvirtd.log ] && grep -qiE "AUTH|CONNECT|access|polkit" /var/log/libvirt/libvirtd.log 2>/dev/null; then
    AUTH_LOGGED=true
fi
if auditctl -l 2>/dev/null | grep -qE "/var/run/libvirt|libvirt-sock|auth_attempt"; then
    AUTH_LOGGED=true
fi

if $AUTH_LOGGED; then
    check_pass "ЗСВ.3.3" "Зафиксированы события аутентификации и доступа к интерфейсу виртуализации"
else
    check_fail "ЗСВ.3.3" "Не обнаружено регистрации событий аутентификации и доступа к СВ"
fi

# ЗСВ.3.4 – Аудит запуска и остановки средства виртуализации (с указанием причины)
if journalctl -u libvirtd --no-pager -n 500 2>/dev/null | grep -qiE "Started|Stopped|Exiting|Failed|Reason|signal"; then
    check_pass "ЗСВ.3.4" "Journald: Фиксируются факты запуска и остановки службы виртуализации (libvirtd)"
else
    check_fail "ЗСВ.3.4" "Не обнаружено логирования запусков/остановок средства виртуализации"
fi

# ЗСВ.3.5 – Регистрация фактов нарушения целостности объектов контроля
INTEGRITY_OK=false
if command -v aide &>/dev/null && grep -qE "/etc/libvirt|/var/lib/libvirt" /etc/aide/aide.conf 2>/dev/null; then
    INTEGRITY_OK=true; check_pass "ЗСВ.3.5" "AIDE: Настроен контроль целостности файлов виртуализации"
elif systemctl is-active --quiet wazuh-agent 2>/dev/null && grep -rqE "/etc/libvirt|/var/lib/libvirt" /var/ossec/etc/ossec.conf 2>/dev/null; then
    INTEGRITY_OK=true; check_pass "ЗСВ.3.5" "Wazuh FIM: Настроен контроль целостности файлов виртуализации"
fi

if ! $INTEGRITY_OK; then
    check_fail "ЗСВ.3.5" "Не настроена регистрация фактов нарушения целостности объектов виртуализации (требуется FIM)"
fi

# ЗСВ.3.6 – Централизованный сбор и хранение логов
CENTRAL_LOG=false
if grep -rqE "/var/log/libvirt|libvirtd|/var/log/qemu" /etc/rsyslog.d/ /etc/rsyslog.conf 2>/dev/null; then
    CENTRAL_LOG=true; check_pass "ЗСВ.3.6" "Rsyslog: Настроена отправка логов виртуализации на центральный сервер"
elif command -v filebeat &>/dev/null && systemctl is-active --quiet filebeat 2>/dev/null && grep -qE "libvirt|qemu" /etc/filebeat/filebeat.yml 2>/dev/null; then
    CENTRAL_LOG=true; check_pass "ЗСВ.3.6" "Filebeat: Настроен централизованный сбор логов виртуализации"
elif systemctl is-active --quiet wazuh-agent 2>/dev/null && grep -rqE "/var/log/libvirt|/var/log/qemu" /var/ossec/etc/ossec.conf 2>/dev/null; then
    CENTRAL_LOG=true; check_pass "ЗСВ.3.6" "Wazuh: Настроен централизованный сбор логов виртуализации"
fi

if ! $CENTRAL_LOG; then
    check_fail "ЗСВ.3.6" "Централизованный сбор логов среды виртуализации не настроен"
fi

# Унифицированная итоговая строка
finish_legacy_measure "ЗСВ.3"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1