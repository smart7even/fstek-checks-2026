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

    INTERACTIVE_USERS=()
    while read -r _iu; do
        [ -n "$_iu" ] && INTERACTIVE_USERS+=("$_iu")
    done < <(fstek_interactive_users)
    INTERACTIVE_COUNT="${#INTERACTIVE_USERS[@]}"

    # Поле inactive в /etc/shadow не является датой последнего входа, поэтому
    # фактическую неактивность проверяем по lastlog, когда он доступен.
    INACTIVE_USERS=()
    if command -v lastlog &>/dev/null; then
        while read -r user; do
            [ -n "$user" ] || continue
            for iu in "${INTERACTIVE_USERS[@]}"; do
                if [ "$iu" = "$user" ]; then
                    INACTIVE_USERS+=("$user")
                    break
                fi
            done
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

    # УПД.3.2 – Срок действия паролей (интерактивные УЗ: root или UID>=UID_MIN)
    MAX_DAYS_CONFIGURED=0
    TOTAL_USERS="$INTERACTIVE_COUNT"
    for user in "${INTERACTIVE_USERS[@]}"; do
        MAX_DAYS=$(chage -l "$user" 2>/dev/null | grep -E "Maximum|Максимальное" | awk -F: '{print $2}' | tr -d ' ')
        if [[ "$MAX_DAYS" =~ ^[0-9]+$ ]] && [ "$MAX_DAYS" -le 90 ]; then
            MAX_DAYS_CONFIGURED=$((MAX_DAYS_CONFIGURED + 1))
        fi
    done
    if [ "$TOTAL_USERS" -eq 0 ]; then
        check_skip "УПД.3.2" "Нет локальных интерактивных УЗ для проверки срока действия паролей"
    elif [ "$MAX_DAYS_CONFIGURED" -eq "$TOTAL_USERS" ]; then
        check_pass "УПД.3.2" "Срок действия паролей настроен для всех интерактивных пользователей ($TOTAL_USERS, <=90 дней)"
    else
        check_fail "УПД.3.2" "Срок действия паролей не настроен для всех пользователей ($MAX_DAYS_CONFIGURED из $TOTAL_USERS)"
    fi

    # УПД.3.3 – Учетные записи без пароля (среди интерактивных)
    if [ "$TOTAL_USERS" -eq 0 ]; then
        check_skip "УПД.3.3" "Нет локальных интерактивных УЗ для проверки паролей"
    elif [ ! -r /etc/shadow ]; then
        check_skip "УПД.3.3" "Файл /etc/shadow недоступен для чтения"
    else
        NO_PASSWORD=0
        NO_PASSWORD_LIST=()
        for user in "${INTERACTIVE_USERS[@]}"; do
            HASH=$(awk -F: -v u="$user" '$1 == u {print $2; exit}' /etc/shadow 2>/dev/null)
            # Пустой hash — риск; ! / !! / * — заблокированные/без парольного логина, не считаем FAIL
            if [ -z "$HASH" ]; then
                # Нет строки в shadow или пустое поле пароля
                if ! awk -F: -v u="$user" '$1 == u {found=1} END {exit !found}' /etc/shadow 2>/dev/null; then
                    continue
                fi
                NO_PASSWORD=$((NO_PASSWORD + 1))
                NO_PASSWORD_LIST+=("$user")
            fi
        done
        if [ "$NO_PASSWORD" -eq 0 ]; then
            check_pass "УПД.3.3" "Учетные записи без пароля отсутствуют среди интерактивных УЗ"
        else
            check_fail "УПД.3.3" "Обнаружено $NO_PASSWORD учетных записей без пароля: ${NO_PASSWORD_LIST[*]}"
        fi
    fi

    # INFO: перечень интерактивных УЗ и sudo/wheel для ручного анализа
    if [ "$INTERACTIVE_COUNT" -gt 0 ]; then
        check_info "УПД.3.I1" "Интерактивные УЗ: ${INTERACTIVE_USERS[*]}"
    else
        check_info "УПД.3.I1" "Интерактивные УЗ не обнаружены"
    fi
    SUDO_MEMBERS=""
    for grp in sudo wheel; do
        if getent group "$grp" >/dev/null 2>&1; then
            m=$(getent group "$grp" | cut -d: -f4)
            [ -n "$m" ] && SUDO_MEMBERS="${SUDO_MEMBERS}${SUDO_MEMBERS:+; }${grp}: ${m}"
        fi
    done
    if [ -n "$SUDO_MEMBERS" ]; then
        check_info "УПД.3.I2" "Группы sudo/wheel: $SUDO_MEMBERS"
    else
        check_info "УПД.3.I2" "Группы sudo/wheel пусты или отсутствуют"
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
