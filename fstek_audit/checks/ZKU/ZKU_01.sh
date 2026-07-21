#!/usr/bin/env bash
# fstek_audit/checks/ZKU/ZKU_01.sh - migrated measure logic for ЗКУ.1.

MEASURE_CODE_DECL="ЗКУ.1"
MEASURE_TITLE="Управление доступом к конечным устройствам"

check_zku1() {
    is_linux || { check_na "$MEASURE_CODE" "Проверка рассчитана на Linux"; return; }
    check_pam_auth "$MEASURE_CODE.1"
    check_ssh_hardening "$MEASURE_CODE.2"
    check_sudo_restricted "$MEASURE_CODE.3"

    detect_os
    if [[ "$OS_TYPE" == "astra17" || "$OS_TYPE" == "astra18" ]]; then
        # Контроль интерфейсов ввода-вывода / съёмных носителей (Astra)
        PKLA_FILE="/etc/polkit-1/localauthority/10-vendor.d/ru.rusbitech.noudisksmount.pkla"
        if [ -f "$PKLA_FILE" ] && \
           grep -qE 'Identity=unix-user:\*' "$PKLA_FILE" && \
           grep -qE 'Action=org\.freedesktop\.udisks2\.filesystem-mount' "$PKLA_FILE" && \
           grep -qE 'ResultActive=no' "$PKLA_FILE"; then
            check_pass "$MEASURE_CODE.4" "polkit блокирует монтирование съёмных носителей ($PKLA_FILE)"
        else
            check_fail "$MEASURE_CODE.4" "polkit-политика блокировки монтирования съёмных носителей не найдена или неполная ($PKLA_FILE)"
        fi

        if have_cmd astra-mount-lock; then
            if fstek_astra_lock_active astra-mount-lock; then
                check_pass "$MEASURE_CODE.5" "astra-mount-lock: блокировка монтирования активна"
            else
                check_fail "$MEASURE_CODE.5" "astra-mount-lock установлен, но статус не АКТИВНО"
            fi
        else
            check_fail "$MEASURE_CODE.5" "Команда astra-mount-lock не найдена"
        fi

        if have_cmd astra-format-lock; then
            if fstek_astra_lock_active astra-format-lock; then
                check_pass "$MEASURE_CODE.6" "astra-format-lock: блокировка форматирования активна"
            else
                check_fail "$MEASURE_CODE.6" "astra-format-lock установлен, но статус не АКТИВНО"
            fi
        else
            check_fail "$MEASURE_CODE.6" "Команда astra-format-lock не найдена"
        fi

        if have_cmd astra-mic-control; then
            if fstek_astra_lock_active astra-mic-control; then
                check_pass_medium "$MEASURE_CODE.7" "astra-mic-control активен (ПО-контроль микрофона; аппаратное усиление ЗКУ.1 №2 не подтверждается)"
            else
                check_info "$MEASURE_CODE.7" "astra-mic-control найден, статус не АКТИВНО"
            fi
        else
            check_info "$MEASURE_CODE.7" "astra-mic-control не установлен"
        fi

        # Остаточная информация на хосте без стека виртуализации — INFO
        if ! have_cmd virsh && ! service_active libvirtd; then
            SWAP_WIPER="/etc/parsec/swap_wiper.conf"
            if [ -f "$SWAP_WIPER" ]; then
                SW_EN="$(fstek_config_value "$SWAP_WIPER" "ENABLED")"
                check_info "$MEASURE_CODE.8" "swap_wiper.conf ENABLED=${SW_EN:-unset} ($SWAP_WIPER)"
            else
                check_info "$MEASURE_CODE.8" "Файл /etc/parsec/swap_wiper.conf отсутствует"
            fi
            if grep -qE 'secdelrnd' /etc/fstab 2>/dev/null; then
                check_info "$MEASURE_CODE.9" "В /etc/fstab найдена опция secdelrnd: $(grep -E 'secdelrnd' /etc/fstab | head -n1)"
            else
                check_info "$MEASURE_CODE.9" "Опция secdelrnd в /etc/fstab не найдена"
            fi
        fi
    else
        check_na "$MEASURE_CODE.4" "Astra-specific контроль съёмных носителей неприменим на $OS_TYPE"
        check_na "$MEASURE_CODE.5" "astra-mount-lock неприменим на $OS_TYPE"
        check_na "$MEASURE_CODE.6" "astra-format-lock неприменим на $OS_TYPE"
    fi
}

run_check() {
    init_measure "$MEASURE_CODE_DECL" "$MEASURE_TITLE"
    check_zku1
    finish_measure
}
