#!/usr/bin/env bash
# fstek_audit/checks/UPD/UPD_02.sh - migrated measure logic for УПД.2.

run_check() {
    # Модуль проверки УПД.2 - Разграничение и контроль прав доступа
    WITH_ENHANCEMENTS=false
    for arg in "$@"; do
        case "$arg" in
            --with-enhancements|-e|--class|--security-class|-c|--class=*|--security-class=*|--k1|--K1|--к1|--К1|--k2|--K2|--к2|--К2|--k3|--K3|--к3|--К3) WITH_ENHANCEMENTS=true ;;
        esac
    done


    # УПД.2.1 – Права на критические файлы
    check_file_perms() {
        local file=$1
        local expected=$2
        local desc=$3
        if [ -f "$file" ]; then
            PERMS=$(stat -c %a "$file" 2>/dev/null)
            if [ "$PERMS" == "$expected" ]; then
                check_pass "УПД.2.1" "$desc: права $PERMS (корректные)"
            else
                check_fail "УПД.2.1" "$desc: права $PERMS (ожидалось $expected)"
            fi
        else
            check_fail "УПД.2.1" "$desc: файл не найден"
        fi
    }
    check_file_perms "/etc/passwd" "644" "Файл /etc/passwd"
    check_file_perms "/etc/shadow" "640" "Файл /etc/shadow"
    check_file_perms "/etc/sudoers" "440" "Файл /etc/sudoers"

    # УПД.2.2 – Отсутствие дублирующихся UID (запрет общих учетных записей и скрытого шаринга прав)
    DUP_UIDS=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d)

    if [ -z "$DUP_UIDS" ]; then
        check_pass "УПД.2.2" "Дублирующиеся UID в /etc/passwd отсутствуют"
    else
        check_fail "УПД.2.2" "Обнаружены дублирующиеся UID, включая возможные общие/root-alias учетные записи: $DUP_UIDS"
    fi

    # УПД.2.2a – Признаки групповых/общих и заданных по умолчанию учетных записей
    SHARED_ACCOUNTS=$(awk -F: '
        $1 ~ /^(guest|test|user|shared|common|operator|admin|toor)$/ && $7 !~ /(nologin|false)$/ {print $1}
    ' /etc/passwd 2>/dev/null | xargs)
    SAME_HOME_USERS=$(awk -F: '$3 >= 1000 && $6 ~ "^/home/" {homes[$6]=homes[$6] " " $1; count[$6]++} END {for (h in count) if (count[h] > 1) print h ":" homes[h]}' /etc/passwd 2>/dev/null | xargs)

    if [ -z "$SHARED_ACCOUNTS" ] && [ -z "$SAME_HOME_USERS" ]; then
        check_pass "УПД.2.2a" "Не обнаружены типовые активные guest/test/shared учетные записи и несколько пользователей с одним home"
    else
        check_fail "УПД.2.2a" "Обнаружены признаки общих/default учетных записей: users=[$SHARED_ACCOUNTS], homes=[$SAME_HOME_USERS]"
    fi

    # УПД.2.3 – SUID/SGID файлы (проверка минимизации привилегий)
    SUID_COUNT=$(find /usr/bin /usr/sbin /bin /sbin -perm /4000 2>/dev/null | wc -l)
    SGID_COUNT=$(find /usr/bin /usr/sbin /bin /sbin -perm /2000 2>/dev/null | wc -l)
    if [ "$SUID_COUNT" -lt 50 ] && [ "$SGID_COUNT" -lt 30 ]; then
        check_pass "УПД.2.3" "SUID файлов: $SUID_COUNT, SGID: $SGID_COUNT (в пределах нормы)"
    else
        check_fail "УПД.2.3" "Избыточное количество SUID/SGID файлов (SUID: $SUID_COUNT, SGID: $SGID_COUNT)"
    fi

    # УПД.2.4 – Права на домашние каталоги
    HOME_ISSUES=0
    for home in /home/*; do
        if [ -d "$home" ]; then
            PERMS=$(stat -c %a "$home" 2>/dev/null)
            if [ "$PERMS" != "700" ] && [ "$PERMS" != "750" ]; then
                ((HOME_ISSUES++))
            fi
        fi
    done
    if [ "$HOME_ISSUES" -eq 0 ]; then
        check_pass "УПД.2.4" "Права на домашние каталоги корректны (700/750)"
    else
        check_fail "УПД.2.4" "Обнаружено $HOME_ISSUES домашних каталогов с некорректными правами"
    fi

    # УПД.2.5 – Усиление: Разделение учетных записей
    if fstek_enhancement_enabled "УПД.2" "1" "2"; then
        # Проверяем, что пользователи с UID 0 (кроме root) отсутствуют
        ROOT_ACCOUNTS=$(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd | wc -l)

        # Проверяем, что администраторы не входят в обычные группы пользователей
        ADMIN_IN_USER_GROUPS=0
        for admin_user in $(awk -F: '$3 == 0 || $1 ~ /admin/ {print $1}' /etc/passwd); do
            USER_GROUPS=$(groups "$admin_user" 2>/dev/null | wc -w)
            [ "$USER_GROUPS" -gt 3 ] && ((ADMIN_IN_USER_GROUPS++))
        done

        if [ "$ROOT_ACCOUNTS" -eq 0 ] && [ "$ADMIN_IN_USER_GROUPS" -eq 0 ]; then
            check_pass "УПД.2.5" "Разделение привилегий соблюдено: нет лишних root-аккаунтов"
        else
            check_fail "УПД.2.5" "Нарушение разделения привилегий: лишних root: $ROOT_ACCOUNTS, админов в группах: $ADMIN_IN_USER_GROUPS"
        fi
    else
        skip_enhancement "УПД.2.5"
    fi

    if fstek_enhancement_enabled "УПД.2" "2"; then
        check_skip "УПД.2.6" "Минимизация прав устройств, приложений, СЗИ, СУБД, CI/CD, хранилищ секретов и сетевой инфраструктуры подтверждается матрицей доступа и настройками конкретных компонентов"
    else
        skip_enhancement "УПД.2.6"
    fi

    check_skip "УПД.2.7" "Наличие главного администратора и разделение ролей администрирования, разработки и безопасности проверяются по эксплуатационной документации и приказам"

    finish_legacy_measure "УПД.2"
}
