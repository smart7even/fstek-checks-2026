#!/usr/bin/env bash
# fstek_audit/checks/RSB/RSB_01.sh - migrated measure logic for РСБ.1.

run_check() {
    # check_rsb1.sh - РСБ.1 Определение событий безопасности

    WITH_ENH=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENH=true ;;
        esac
    done

    # Унифицированные функции вывода

    OS="generic"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_MATCH="$(printf '%s' "${ID:-} ${ID_LIKE:-} ${NAME:-} ${PRETTY_NAME:-}" | tr '[:upper:]' '[:lower:]')"
        [[ "$OS_MATCH" == *"astra"* || "$OS_MATCH" == *"alse"* ]] && OS="astra"
    fi

    # РСБ.1.1 – Служба аудита
    if [ "$OS" == "astra" ]; then
        if systemctl is-active --quiet parsecd 2>/dev/null || systemctl is-active --quiet auditd 2>/dev/null; then
            check_pass "РСБ.1.1" "Служба аудита (PARSEC/auditd) активна"
        else
            check_fail "РСБ.1.1" "Служба аудита не активна"
        fi
    else
        if systemctl is-active --quiet auditd 2>/dev/null; then
            check_pass "РСБ.1.1" "Служба auditd активна"
        else
            check_fail "РСБ.1.1" "Служба auditd не активна"
        fi
    fi

    # РСБ.1.2 – Минимальный состав событий по методике
    RULES=$(auditctl -l 2>/dev/null; cat /etc/audit/rules.d/*.rules 2>/dev/null)
    USB_OK=false; echo "$RULES" | grep -qiE "/dev|/media|/mnt|usb|udisks|mount" && USB_OK=true
    EXEC_OK=false; echo "$RULES" | grep -qiE "execve|-S[[:space:]]+execve|/usr/bin|/usr/sbin" && EXEC_OK=true
    LOGIN_OK=false; echo "$RULES" | grep -qiE "logins|USER_LOGIN|USER_LOGOUT|/var/run/utmp|/var/log/(wtmp|btmp|faillog)|pam_tally|faillock" && LOGIN_OK=true
    REMOTE_OK=false; echo "$RULES" | grep -qiE "sshd|/etc/ssh|USER_AUTH|remote|vpn|openvpn|wireguard|ipsec" && REMOTE_OK=true
    OBJECT_ACCESS_OK=false; echo "$RULES" | grep -qiE "^-a .* -S (open|openat|creat|truncate|unlink|rename|chmod|chown)|-w /etc/(passwd|shadow|sudoers|group)|perm=| -p (r|w|x|a)" && OBJECT_ACCESS_OK=true
    SECURITY_TOOL_OK=false; echo "$RULES" | grep -qiE "audit|/etc/audit|/etc/pam.d|/etc/security|/etc/sudoers|/etc/ssh|firewall|nftables|iptables" && SECURITY_TOOL_OK=true

    if $USB_OK && $EXEC_OK && $LOGIN_OK && $REMOTE_OK && $OBJECT_ACCESS_OK && $SECURITY_TOOL_OK; then
        check_pass "РСБ.1.2" "Настроены минимальные категории событий: входы, носители, запуск/завершение программ, доступ к объектам, удаленный доступ, события СЗИ"
    else
        MISSING=""
        $LOGIN_OK || MISSING+="logins "
        $USB_OK || MISSING+="media "
        $EXEC_OK || MISSING+="exec/process "
        $OBJECT_ACCESS_OK || MISSING+="object-access "
        $REMOTE_OK || MISSING+="remote-access "
        $SECURITY_TOOL_OK || MISSING+="security-tools "
        check_fail "РСБ.1.2" "Отсутствуют правила аудита для: $MISSING"
    fi

    check_skip "РСБ.1.2a" "Полный перечень типов событий и состав полей по ГОСТ Р 59548-2022 определяется оператором и проверяется по эксплуатационной документации"

    # РСБ.1.3 – Системное логирование
    if systemctl is-active --quiet rsyslog 2>/dev/null || systemctl is-active --quiet systemd-journald 2>/dev/null; then
        check_pass "РСБ.1.3" "Служба системного логирования активна"
    else
        check_fail "РСБ.1.3" "Служба системного логирования не активна"
    fi

    if fstek_enhancement_enabled "РСБ.1" "1"; then
        # РСБ.1.4 (Усиление 1) – Привилегированные команды
        if echo "$RULES" | grep -qE "execve.*(euid=0|uid=0|auid=0)"; then
            check_pass "РСБ.1.4" "Включено логирование привилегированных команд (execve)"
        else
            check_fail "РСБ.1.4" "Отсутствуют правила аудита для привилегированных команд"
        fi
    else
        skip_enhancement "РСБ.1.4"
    fi

    if fstek_enhancement_enabled "РСБ.1" "3"; then
        # РСБ.1.5 (Усиление 3) – Место удаленного доступа (IP-адреса)
        if grep -qE "^LogLevel\s+VERBOSE" /etc/ssh/sshd_config 2>/dev/null; then
            check_pass "РСБ.1.5" "SSH: LogLevel VERBOSE (фиксируется IP/порт источника)"
        else
            check_fail "РСБ.1.5" "SSH: Требуется LogLevel VERBOSE для фиксации места доступа"
        fi
    else
        skip_enhancement "РСБ.1.5"
    fi

    if fstek_enhancement_enabled "РСБ.1" "2"; then
        # РСБ.1.6 (Усиление 2) – Централизованный мониторинг / SIEM
        # Uses profile FSTEK_EXPECT_SIEM_HOST/PORT when set.
        check_siem_forwarding "РСБ.1.6"
    else
        skip_enhancement "РСБ.1.6"
    fi

    # Унифицированная итоговая строка
    finish_legacy_measure "РСБ.1"
}
