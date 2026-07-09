#!/usr/bin/env bash
# fstek_audit/checks/UPD/UPD_03.sh - migrated measure logic for УПД.3.

run_check() {
    # Модуль проверки УПД.3 - Управление учетными записями
    WITH_ENHANCEMENTS=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
        esac
    done


    # УПД.3.1 – Заблокированные учетные записи и неактивные УЗ
    LOCKED_ACCOUNTS=$(passwd -S 2>/dev/null | grep -c " L ")
    if ! [[ "$LOCKED_ACCOUNTS" =~ ^[0-9]+$ ]]; then
        LOCKED_ACCOUNTS=$(grep -cE "^[^:]+:.*:.*:.*:.*:.*:.*:\*$" /etc/shadow 2>/dev/null)
    fi
    LOCKED_ACCOUNTS="${LOCKED_ACCOUNTS:-0}"

    # Поле inactive в /etc/shadow не является датой последнего входа, поэтому
    # фактическую неактивность проверяем по lastlog, когда он доступен.
    INACTIVE_USERS=()
    if command -v lastlog &>/dev/null; then
        while read -r user; do
            [ -n "$user" ] || continue
            if awk -F: -v u="$user" '$1 == u && $7 !~ /(nologin|false)$/ {found=1} END {exit !found}' /etc/passwd 2>/dev/null; then
                INACTIVE_USERS+=("$user")
            fi
        done < <(lastlog -b 90 2>/dev/null | awk 'NR > 1 && $0 !~ /Never logged in|Никогда/ {print $1}')
    else
        check_skip "УПД.3.1" "Команда lastlog отсутствует, дату последнего входа учетных записей проверить нельзя"
    fi

    if command -v lastlog &>/dev/null && [ "${#INACTIVE_USERS[@]}" -eq 0 ]; then
        check_pass "УПД.3.1" "Заблокировано учетных записей: $LOCKED_ACCOUNTS; активных локальных УЗ с последним входом старше 90 дней не обнаружено"
    elif command -v lastlog &>/dev/null; then
        check_fail "УПД.3.1" "Обнаружены активные локальные УЗ с последним входом старше 90 дней: ${INACTIVE_USERS[*]}"
    fi

    SHADOW_INACTIVE_BAD=$(awk -F: '$7 ~ /^[0-9]+$/ && $7 > 90 {print $1 ":" $7}' /etc/shadow 2>/dev/null | xargs)
    if [ -n "$SHADOW_INACTIVE_BAD" ]; then
        check_fail "УПД.3.1a" "Период неактивности после истечения пароля в /etc/shadow больше 90 дней: $SHADOW_INACTIVE_BAD"
    else
        check_pass "УПД.3.1a" "В /etc/shadow не задан период неактивности после истечения пароля больше 90 дней"
    fi

    # УПД.3.2 – Срок действия паролей
    MAX_DAYS_CONFIGURED=0
    for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
        MAX_DAYS=$(chage -l "$user" 2>/dev/null | grep "Maximum" | awk -F: '{print $2}' | tr -d ' ')
        if [[ "$MAX_DAYS" =~ ^[0-9]+$ ]] && [ "$MAX_DAYS" -le 90 ]; then
            ((MAX_DAYS_CONFIGURED++))
        fi
    done
    TOTAL_USERS=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd | wc -l)
    if [ "$MAX_DAYS_CONFIGURED" -eq "$TOTAL_USERS" ] && [ "$TOTAL_USERS" -gt 0 ]; then
        check_pass "УПД.3.2" "Срок действия паролей настроен для всех пользователей (<=90 дней)"
    else
        check_fail "УПД.3.2" "Срок действия паролей не настроен для всех пользователей ($MAX_DAYS_CONFIGURED из $TOTAL_USERS)"
    fi

    # УПД.3.3 – Учетные записи без пароля
    NO_PASSWORD=$(awk -F: '($2 == "" || $2 == "!") && $3 >= 1000 {print $1}' /etc/shadow 2>/dev/null | wc -l)
    if [ "$NO_PASSWORD" -eq 0 ]; then
        check_pass "УПД.3.3" "Учетные записи без пароля отсутствуют"
    else
        check_fail "УПД.3.3" "Обнаружено $NO_PASSWORD учетных записей без пароля"
    fi

    # УПД.3.4 – Журнал изменений учетных записей (auditd)
    if systemctl is-active --quiet auditd 2>/dev/null; then
        # УСИЛЕНИЕ: Более строгая проверка правил auditd на конкретные критические файлы
        AUDIT_RULES=$(auditctl -l 2>/dev/null | grep -cE "\-w /etc/passwd|\-w /etc/shadow|\-w /etc/group|\-w /etc/gshadow")

        if [ "$AUDIT_RULES" -ge 3 ]; then
            # Ожидаем, что настроено минимум 3 правила из 4 возможных
            check_pass "УПД.3.4" "Auditd активен, настроено $AUDIT_RULES строгих правил для учета изменений УЗ (passwd/shadow/group)"
        else
            check_fail "УПД.3.4" "Auditd активен, но строгие правила для учета изменений УЗ не настроены (найдено: $AUDIT_RULES)"
        fi
    else
        check_fail "УПД.3.4" "Служба auditd не активна (журнал изменений УЗ не ведется)"
    fi

    # УПД.3.5 – Усиление: Централизованное управление
    if fstek_enhancement_enabled "УПД.3" "1" "2"; then
        if systemctl is-active --quiet sssd 2>/dev/null; then
            if [ -f /etc/sssd/sssd.conf ] && grep -q "domains =" /etc/sssd/sssd.conf; then
                check_pass "УПД.3.5" "Централизованное управление УЗ через SSSD настроено"
            else
                check_fail "УПД.3.5" "SSSD активен, но домены не настроены"
            fi
        elif command -v ipa-client-install &>/dev/null && ipa-client-install --help &>/dev/null; then
            check_pass "УПД.3.5" "FreeIPA клиент установлен (централизованное управление)"
        else
            check_fail "УПД.3.5" "Централизованное управление учетными записями не обнаружено"
        fi
    else
        skip_enhancement "УПД.3.5"
    fi

    finish_legacy_measure "УПД.3"
}
