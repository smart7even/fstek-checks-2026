#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib_fstek.sh"
# check_zep3.sh - Защита от вредоносных вложений (ЗЭП.3)
# Соответствие разделу 4.6 (ЗЭП.3) Методического документа ФСТЭК России от 12.04.2026

WITH_ENHANCEMENTS=false
for arg in "$@"; do
    case "$arg" in
        --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
    esac
done

FAIL_COUNT=0
SKIP_COUNT=0

# Унифицированные функции вывода
check_pass() { fstek_status_line "$1" "PASS" "$2"; }
check_fail() { fstek_status_line "$1" "FAIL" "$2"; ((FAIL_COUNT++)); }
check_skip() { fstek_status_line "$1" "SKIP" "$2 (НЕ ПОДДАЁТСЯ АВТОМАТИЧЕСКОЙ ПРОВЕРКЕ)"; ((SKIP_COUNT++)); }

# --- ПРОВЕРКА НАЛИЧИЯ ПОЧТОВОГО СЕРВЕРА ---
# Если почтовый сервер не установлен, проверка ЗЭП.5 пропускается
if ! command -v postconf &>/dev/null && ! systemctl list-units --all | grep -qE "postfix|dovecot|exim|sendmail"; then
    check_skip "ЗЭП.3" "Почтовый сервер не обнаружен. Проверка ЗЭП.3 пропущена."
    echo "=== ИТОГ МОДУЛЯ ЗЭП.3: FAIL=0, SKIP=1 ==="
    exit 0
fi

# --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

# ЗЭП.3.1 - Антивирусная защита (АВЗ.2)
CONTENT_FILTER=$(postconf -h content_filter 2>/dev/null)
MILTERS=$(postconf -h smtpd_milters 2>/dev/null)
if echo "$CONTENT_FILTER $MILTERS" | grep -qiE "clam|amavis|rspamd|spamd|virus|av|drweb|kaspersky|kesl|milter.*(clam|av|virus)" || \
   grep -RIEq "clamav|clamd|amavis|rspamd.*antivirus|virus|drweb|kaspersky|kesl" /etc/postfix /etc/amavis /etc/rspamd /etc/clamav 2>/dev/null; then
    check_pass "ЗЭП.3.1" "Настроена интеграция почты с антивирусной проверкой"
else
    check_fail "ЗЭП.3.1" "Не подтверждена антивирусная природа content_filter/milter для проверки вложений"
fi

# ЗЭП.3.2 - Блокирование неразрешенных форматов
if grep -RIEq "(\.(exe|scr|bat|cmd|com|js|vbs|jar|ps1|msi|hta|lnk)|application/(x-msdownload|x-dosexec)|filename=.*\.(exe|scr|bat|cmd|js|vbs|jar|ps1|msi|hta|lnk)).*(REJECT|DISCARD|quarantine|block)" /etc/postfix /etc/amavis /etc/rspamd 2>/dev/null; then
    check_pass "ЗЭП.3.2" "Настроены правила блокирования неразрешенных форматов вложений"
else
    check_fail "ЗЭП.3.2" "Не найдены явные правила блокирования неразрешенных форматов файлов"
fi

# ЗЭП.3.3 - Контроль вложений с использованием IOCs
if grep -RIEq "ioc|yara|hash|sha256|suricata|threat.?intel|indicator|reputation|rspamd.*(url|phishing|antivirus)" /etc/postfix /etc/amavis /etc/rspamd /etc/clamav /etc/yara 2>/dev/null; then
    check_pass "ЗЭП.3.3" "Обнаружены признаки контроля вложений/ссылок по IOC/репутационным индикаторам"
else
    check_skip "ЗЭП.3.3" "Контроль вложений и ссылок с использованием IOC подтверждается политиками почтового шлюза/СЗИ"
fi

# ЗЭП.3.4 - Возможность ретроспективного анализа вложений
if grep -RIEq "quarantine|archive|history|store.*attachment|retrospective|rspamd.*history" /etc/postfix /etc/amavis /etc/rspamd /var/lib/rspamd 2>/dev/null; then
    check_pass "ЗЭП.3.4" "Обнаружены признаки карантина/хранения данных для ретроспективного анализа вложений"
else
    check_skip "ЗЭП.3.4" "Возможность ретроспективного анализа вложений и ссылок подтверждается настройками почтового шлюза/СЗИ и сроками хранения"
fi

# --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
if fstek_enhancement_enabled "ЗЭП.3" "1"; then
    # ЗЭП.3.5 (Усиление 1) - Песочница (замкнутая среда предварительного выполнения)
    if grep -rqE "icap|c-icap|sandbox|vadesecure|kaspersky.*sandbox" /etc/postfix/ /etc/rspamd/ /etc/c-icap/ 2>/dev/null; then
        check_pass "ЗЭП.3.5" "Обнаружена интеграция с замкнутой средой (песочницей) для анализа вложений"
    else
        check_fail "ЗЭП.3.5" "Не обнаружена интеграция с замкнутой средой (песочницей) для динамического анализа"
    fi

    # ЗЭП.3.6 (Усиление 2) - Блокировка запароленных архивов
    if grep -rqE "ArchiveMaxEncrypted|encrypted.*archive|password.*protected" /etc/clamav/ /etc/rspamd/ /etc/amavis/ 2>/dev/null; then
        check_pass "ЗЭП.3.6" "Настроено блокирование запароленных архивов до проверки"
    else
        check_fail "ЗЭП.3.6" "Не настроено блокирование запароленных архивов"
    fi
else
    # Унифицированный вывод для отключенных усилений
    skip_enhancement "ЗЭП.3.5-6"
fi

# Унифицированная итоговая строка
echo "=== ИТОГ МОДУЛЯ ЗЭП.3: FAIL=$FAIL_COUNT, SKIP=$SKIP_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1
