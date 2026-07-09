#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_rsb3.sh - РСБ.3 Генерация временных меток (Синхронизация времени)

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода

# РСБ.3.1 – Служба синхронизации времени
NTP_ACTIVE=false
if systemctl is-active --quiet chronyd 2>/dev/null; then 
    NTP_ACTIVE=true; NTP_SVC="chronyd"
elif systemctl is-active --quiet ntpd 2>/dev/null; then 
    NTP_ACTIVE=true; NTP_SVC="ntpd"
elif systemctl is-active --quiet systemd-timesyncd 2>/dev/null; then 
    NTP_ACTIVE=true; NTP_SVC="timesyncd"
fi

if $NTP_ACTIVE; then 
    check_pass "РСБ.3.1" "Служба синхронизации времени ($NTP_SVC) активна"
else 
    check_fail "РСБ.3.1" "Служба синхронизации времени (chrony/ntp/timesyncd) не активна"
fi

# РСБ.3.2 – Источники времени
NTP_CONF="/etc/chrony.conf"
[ ! -f "$NTP_CONF" ] && NTP_CONF="/etc/chrony/chrony.conf"
[ ! -f "$NTP_CONF" ] && NTP_CONF="/etc/ntp.conf"
[ ! -f "$NTP_CONF" ] && NTP_CONF="/etc/systemd/timesyncd.conf"

if [ -f "$NTP_CONF" ]; then
    if grep -qE "^server|^pool|^NTP=" "$NTP_CONF"; then
        check_pass "РСБ.3.2" "Источники времени настроены в $NTP_CONF"
    else 
        check_fail "РСБ.3.2" "В конфигурации $NTP_CONF не указаны серверы времени"
    fi
else 
    check_fail "РСБ.3.2" "Файл конфигурации NTP/Chrony не найден"
fi

# РСБ.3.3 – Часовой пояс
TIMEZONE=$(timedatectl show -p Timezone --value 2>/dev/null)
if [[ -n "$TIMEZONE" ]]; then 
    check_pass "РСБ.3.3" "Часовой пояс установлен: $TIMEZONE"
else 
    check_fail "РСБ.3.3" "Часовой пояс не настроен корректно"
fi

# Унифицированная итоговая строка
finish_legacy_measure "РСБ.3"
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1