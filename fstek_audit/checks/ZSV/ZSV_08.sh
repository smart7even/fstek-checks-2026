#!/usr/bin/env bash
# fstek_audit/checks/ZSV/ZSV_08.sh - migrated measure logic for ЗСВ.8.

run_check() {
    # check_zsv8.sh - Идентификация и аутентификация в среде виртуализации (ЗСВ.8)
    # Соответствие разделу 4.4 (ЗСВ.8) Методического документа ФСТЭК России от 12.04.2026

    WITH_ENH=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENH=true ;;
        esac
    done


    # Унифицированные функции вывода

    # --- ПРОВЕРКА НАЛИЧИЯ СРЕДСТВ ВИРТУАЛИЗАЦИИ ---
    # Если libvirt/virsh не обнаружены, проверка ЗСВ.1 пропускается
    if ! command -v virsh &>/dev/null && ! systemctl is-active --quiet libvirtd 2>/dev/null; then
        check_skip "ЗСВ.8" "Средства виртуализации (libvirt/virsh) не обнаружены. Проверка ЗСВ.8 пропущена."
        finish_legacy_measure "ЗСВ.8"
        exit 0
    fi

    # --- БАЗОВЫЕ ТРЕБОВАНИЯ ---

    # ЗСВ.8.1 – Аутентификация для libvirt (не root)
    if grep -qE "auth_unix_rw.*polkit|auth_unix_ro.*polkit|auth_unix_rw.*sasl" /etc/libvirt/libvirtd.conf 2>/dev/null; then
        check_pass "ЗСВ.8.1" "Libvirt использует polkit/SASL для аутентификации (не root)"
    elif [ -f /etc/polkit-1/localauthority.conf.d/50-libvirt.pkla ] || [ -d /etc/polkit-1/rules.d ]; then
        check_pass "ЗСВ.8.1" "Polkit настроен для аутентификации в libvirt"
    else
        check_fail "ЗСВ.8.1" "Libvirt может использовать root для доступа (аутентификация не настроена)"
    fi

    # ЗСВ.8.2 – Разделение учетных записей
    VIRT_ADMINS=$(grep -cE "^libvirt.*:" /etc/group 2>/dev/null || echo "0")
    if [ "$VIRT_ADMINS" -ge 2 ]; then
        check_pass "ЗСВ.8.2" "Обнаружено $VIRT_ADMINS групп для разделения ролей администраторов виртуализации"
    else
        check_fail "ЗСВ.8.2" "Недостаточно групп для разделения ролей (только $VIRT_ADMINS)"
    fi

    # ЗСВ.8.3 – PAM для виртуализации
    if [ -f /etc/pam.d/libvirt ] || grep -qE "pam_unix|pam_sss" /etc/pam.d/system-auth /etc/pam.d/common-auth 2>/dev/null; then
        check_pass "ЗСВ.8.3" "PAM настроен для аутентификации в среде виртуализации"
    else
        check_fail "ЗСВ.8.3" "PAM не настроен для аутентификации libvirt"
    fi

    # --- ТРЕБОВАНИЯ К УСИЛЕНИЮ ---
    if fstek_enhancement_enabled "ЗСВ.8" "1"; then
        # ЗСВ.8.4 (Усиление 1) – Идентификация объектов виртуализации (UUID)
        if command -v virsh &>/dev/null; then
            VM_WITH_UUID=0
            VM_TOTAL=0
            for vm in $(virsh list --all --name 2>/dev/null); do
                ((VM_TOTAL++))
                if virsh dumpxml "$vm" 2>/dev/null | grep -q "<uuid>"; then
                    ((VM_WITH_UUID++))
                fi
            done

            if [ "$VM_TOTAL" -gt 0 ] && [ "$VM_WITH_UUID" -eq "$VM_TOTAL" ]; then
                check_pass "ЗСВ.8.4" "Все ВМ ($VM_TOTAL) имеют уникальные UUID (идентификация объектов)"
            elif [ "$VM_TOTAL" -gt 0 ]; then
                check_fail "ЗСВ.8.4" "Не все ВМ имеют UUID ($VM_WITH_UUID из $VM_TOTAL)"
            else
                check_skip "ЗСВ.8.4" "ВМ не найдены для проверки UUID"
            fi
        else
            check_skip "ЗСВ.8.4" "virsh недоступен для проверки UUID ВМ"
        fi
    else
        # Унифицированный вывод для отключенных усилений
        skip_enhancement "ЗСВ.8.4"
    fi

    # Унифицированная итоговая строка
    finish_legacy_measure "ЗСВ.8"
}
