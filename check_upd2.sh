#!/bin/bash
# Модуль проверки УПД.2 - Разграничение и контроль прав доступа
WITH_ENHANCEMENTS=false
[[ "$1" == "--with-enhancements" || "$1" == "-e" ]] && WITH_ENHANCEMENTS=true

check_pass() { echo "[$1] PASS – $2"; }
check_fail() { echo "[$1] FAIL – $2"; ((FAIL_COUNT++)); }
FAIL_COUNT=0

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
# ИСПРАВЛЕНИЕ: Проверяем наличие разных имен с одинаковым UID. 
# Это прямое нарушение принципа уникальной идентификации и минимизации прав из методички ФСТЭК.
# Исключаем UID 0 (root), так как для него наличие алиасов (например, toor) иногда допустимо, 
# но дубликаты для обычных пользователей (UID >= 1000) строго запрещены.
DUP_UIDS=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d | grep -v "^0$")

if [ -z "$DUP_UIDS" ]; then
    check_pass "УПД.2.2" "Дублирующиеся UID в /etc/passwd отсутствуют"
else
    check_fail "УПД.2.2" "Обнаружены дублирующиеся UID (риск использования общих прав): $DUP_UIDS"
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
if $WITH_ENHANCEMENTS; then
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
    echo "[УПД.2.5] SKIP – проверка усилений отключена"
fi

echo "=== ИТОГ МОДУЛЯ УПД.2: FAIL=$FAIL_COUNT ==="
[ $FAIL_COUNT -eq 0 ] && exit 0 || exit 1