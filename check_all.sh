#!/bin/bash
# check_all.sh - агрегатор проверок мер защиты ФСТЭК 2026.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 2
. "$SCRIPT_DIR/lib_fstek.sh"

ENHANCE_ARGS=()
if [ -n "$FSTEK_SECURITY_CLASS" ]; then
    ENHANCE_ARGS=(--class "$FSTEK_SECURITY_CLASS")
    echo ">>> Режим проверки с учетом требований к усилению для класса $FSTEK_SECURITY_CLASS включен."
elif $WITH_ENHANCEMENTS; then
    ENHANCE_ARGS=(-e)
    echo ">>> Режим проверки с учетом всех требований к усилению включен."
else
    echo ">>> Режим проверки только базовых требований."
fi
detect_os
fstek_print_os_info
echo "========================================================="

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
FAIL_LIST=""
SKIP_LIST=""
MEASURE_SUMMARY=""
FAILED_MEASURES=""

for script in check_*.sh; do
    [[ "$script" == "check_all.sh" ]] && continue
    [[ ! -x "$script" ]] && chmod +x "$script" 2>/dev/null

    measure_name="${script#check_}"
    measure_name="${measure_name%.sh}"
    measure_prefix="${measure_name%%[0-9]*}"
    measure_number="${measure_name#$measure_prefix}"
    MEASURE_CODE="$(printf '%s.%s' "$(printf '%s' "$measure_prefix" | tr '[:lower:]' '[:upper:]')" "$measure_number")"
    echo -e "\n>>> Запуск модуля: $MEASURE_CODE ($script)"
    OUTPUT=$(FSTEK_COLOR=never bash "$script" "${ENHANCE_ARGS[@]}")
    EXIT_CODE=$?
    printf '%s\n' "$OUTPUT" | fstek_colorize_statuses

    P_COUNT=$(echo "$OUTPUT" | grep -c "PASS –" || true)
    F_COUNT=$(echo "$OUTPUT" | grep -c "FAIL –" || true)
    S_COUNT=$(echo "$OUTPUT" | grep -c "SKIP –" || true)

    TOTAL_PASS=$((TOTAL_PASS + P_COUNT))
    TOTAL_FAIL=$((TOTAL_FAIL + F_COUNT))
    TOTAL_SKIP=$((TOTAL_SKIP + S_COUNT))

    if [ "$F_COUNT" -gt 0 ] || [ "$EXIT_CODE" -ne 0 ]; then
        FAILED_MEASURES+="$MEASURE_CODE"$'\n'
        FAIL_LIST+=$(echo "$OUTPUT" | grep "FAIL –" || true)
        FAIL_LIST+=$'\n'
        MEASURE_SUMMARY+="[НЕ ОК] $MEASURE_CODE: $P_COUNT PASS, $F_COUNT FAIL, $S_COUNT SKIP\n"
    else
        MEASURE_SUMMARY+="[ OK ]  $MEASURE_CODE: $P_COUNT PASS, 0 FAIL, $S_COUNT SKIP\n"
    fi
    SKIP_LINES=$(echo "$OUTPUT" | grep "SKIP –" || true)
    if [ -n "$SKIP_LINES" ]; then
        SKIP_LIST+="$SKIP_LINES"$'\n'
    fi
done

TOTAL=$((TOTAL_PASS + TOTAL_FAIL))
if [ "$TOTAL" -gt 0 ]; then
    FAIL_PERCENT=$((TOTAL_FAIL * 100 / TOTAL))
else
    FAIL_PERCENT=0
fi

echo -e "\n#########################################################"
echo "#                  ИТОГОВЫЙ ОТЧЕТ                       #"
echo "#########################################################"
if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo "Общий результат по системе: ОК"
else
    echo "Общий результат по системе: НЕ ОК"
fi
if [ -n "$FSTEK_SECURITY_CLASS" ]; then
    echo "Класс защищенности: $FSTEK_SECURITY_CLASS"
elif $WITH_ENHANCEMENTS; then
    echo "Класс защищенности: не задан, проверяются все доступные усиления"
else
    echo "Класс защищенности: не задан, проверяются базовые требования"
fi
echo "Общее количество выполненных технических проверок: $TOTAL"
echo "Количество успешных проверок: $TOTAL_PASS"
echo "Количество неуспешных проверок: $TOTAL_FAIL"
echo "Процент невыполненных проверок: $FAIL_PERCENT%"
echo "Количество неприменимых/неавтоматизируемых параметров: $TOTAL_SKIP"

echo -e "\nСводная таблица по мерам:"
printf '%b' "$MEASURE_SUMMARY" | fstek_colorize_statuses

if [ -n "$FAILED_MEASURES" ]; then
    echo "Меры, которые не были исполнены:"
    echo "$FAILED_MEASURES" | sed '/^$/d' | sort -u | sed 's/^/- /'
fi

if [ -n "$FAIL_LIST" ]; then
    echo -e "\nКонкретные параметры, которые не были исполнены:"
    echo "$FAIL_LIST" | sed '/^$/d' | sed 's/^/- /' | fstek_colorize_statuses
fi

if [ -n "$SKIP_LIST" ]; then
    echo -e "\nПараметры, которые невозможно проверить автоматически или неприменимы:"
    echo "$SKIP_LIST" | sed '/^$/d' | sed 's/^/- /' | fstek_colorize_statuses
fi

[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
