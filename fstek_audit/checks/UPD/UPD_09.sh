#!/usr/bin/env bash
# fstek_audit/checks/UPD/UPD_09.sh - migrated measure logic for УПД.9.

run_check() {
    # Модуль проверки УПД.9 - Контроль действий субъектов доступа до идентификации и аутентификации
    WITH_ENHANCEMENTS=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
        esac
    done


    # УПД.9.1 – Настройка Getty (отключение autologin)
    AUTOLOGIN_DISABLED=true
    for getty_conf in /etc/systemd/system/getty@.service.d/*.conf /lib/systemd/system/getty@.service; do
        if [ -f "$getty_conf" ] && grep -qE "autologin|--autologin" "$getty_conf" 2>/dev/null; then
            AUTOLOGIN_DISABLED=false
            break
        fi
    done
    if $AUTOLOGIN_DISABLED; then
        check_pass "УПД.9.1" "Getty: автоматический вход отключен"
    else
        check_fail "УПД.9.1" "Getty: обнаружен автоматический вход (autologin)"
    fi

    # УПД.9.2 – Отключение autologin в графической оболочке
    GUI_AUTOLOGIN=false
    # GDM
    if [ -f /etc/gdm/custom.conf ] || [ -f /etc/gdm3/custom.conf ]; then
        if grep -qE "AutomaticLoginEnable=True" /etc/gdm*/custom.conf 2>/dev/null; then
            GUI_AUTOLOGIN=true
        fi
    fi
    # LightDM
    if [ -f /etc/lightdm/lightdm.conf ]; then
        if grep -qE "autologin-user=" /etc/lightdm/lightdm.conf; then
            GUI_AUTOLOGIN=true
        fi
    fi
    # SDDM
    if [ -f /etc/sddm.conf ]; then
        if grep -qE "User=|Session=" /etc/sddm.conf; then
            GUI_AUTOLOGIN=true
        fi
    fi
    if ! $GUI_AUTOLOGIN; then
        check_pass "УПД.9.2" "Графическая оболочка: автоматический вход отключен"
    else
        check_fail "УПД.9.2" "Графическая оболочка: обнаружен автоматический вход"
    fi

    # УПД.9.3 – Сокрытие информации о системе до аутентификации (Pre-auth Info Leakage)
    # Методичка (УПД.9) требует ограничения действий до идентификации.
    # Раскрытие версии ОС/SSH до ввода пароля облегчает нарушителю выбор эксплойта.
    SSH_BANNER_HIDDEN=false
    if [ -f /etc/ssh/sshd_config ]; then
        # Проверяем DebianBanner (актуально для Debian-based: Astra, ALT, RedOS)
        if grep -qE "^\s*DebianBanner\s+no" /etc/ssh/sshd_config; then
            SSH_BANNER_HIDDEN=true
        fi
        # Проверяем VersionAddendum (если используется для скрытия доп. информации)
        if grep -qE "^\s*VersionAddendum\s+none" /etc/ssh/sshd_config; then
            SSH_BANNER_HIDDEN=true
        fi
    fi

    if $SSH_BANNER_HIDDEN; then
        check_info "УПД.9.I1" "SSH DebianBanner/VersionAddendum скрывает часть версии; это полезный hardening, но само по себе не классифицирует УПД.9"
    else
        check_info "УПД.9.I1" "SSH DebianBanner/VersionAddendum не скрывает версию; это может раскрывать детали, но недостаточно для FAIL по УПД.9"
    fi

    # INFO – Блок общего hardening (перенесено из старой УПД.9.3)
    # Примечание: Запрет root/паролей относится к модели доступа (УПД.1) и аутентификации (ИАФ.3),
    # поэтому здесь выводится как информационная рекомендация, чтобы не ломать логику УПД.9.
    if [ -f /etc/ssh/sshd_config ]; then
        PERMIT_ROOT=$(grep -E "^\s*PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
        PASSWORD_AUTH=$(grep -E "^\s*PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
        check_info "УПД.9.I2" "SSH Hardening (УПД.1/ИАФ.3): PermitRootLogin=${PERMIT_ROOT:-не задано}, PasswordAuthentication=${PASSWORD_AUTH:-не задано}"
    fi

    # УПД.9.4 – Журналирование действий до входа
    AUDIT_GETTY=false
    if systemctl is-active --quiet auditd 2>/dev/null; then
        if auditctl -l 2>/dev/null | grep -qE "getty|login|sshd"; then
            AUDIT_GETTY=true
        fi
    fi
    # Проверяем rsyslog/syslog
    if [ -f /var/log/auth.log ] || [ -f /var/log/secure ]; then
        check_pass "УПД.9.4" "Журналирование действий до входа настроено (auth.log/secure)"
    elif $AUDIT_GETTY; then
        check_pass "УПД.9.4" "Auditd настроен для журналирования Getty/login"
    else
        check_fail "УПД.9.4" "Журналирование действий до входа не настроено"
    fi

    finish_legacy_measure "УПД.9"
}
