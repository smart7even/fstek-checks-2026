#!/bin/bash
# check_all.sh - агрегатор проверок мер защиты ФСТЭК 2026.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 2

ENHANCE_FLAG=""
if [[ "$1" == "--with-enhancements" || "$1" == "-e" ]]; then
    ENHANCE_FLAG="-e"
    echo ">>> Режим проверки с учетом требований к усилению включен."
else
    echo ">>> Режим проверки только базовых требований."
fi
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

    MEASURE_CODE=$(echo "$script" | sed -E 's/check_([a-z]+)([0-9]+)\.sh/\U\1.\2/')
    echo -e "\n>>> Запуск модуля: $MEASURE_CODE ($script)"
    OUTPUT=$(bash "$script" $ENHANCE_FLAG)
    EXIT_CODE=$?
    echo "$OUTPUT"

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
echo "Общее количество выполненных технических проверок: $TOTAL"
echo "Количество успешных проверок: $TOTAL_PASS"
echo "Количество неуспешных проверок: $TOTAL_FAIL"
echo "Процент невыполненных проверок: $FAIL_PERCENT%"
echo "Количество неприменимых/неавтоматизируемых параметров: $TOTAL_SKIP"

echo -e "\nСводная таблица по мерам:"
echo -e "$MEASURE_SUMMARY"

if [ -n "$FAILED_MEASURES" ]; then
    echo "Меры, которые не были исполнены:"
    echo "$FAILED_MEASURES" | sed '/^$/d' | sort -u | sed 's/^/- /'
fi

if [ -n "$FAIL_LIST" ]; then
    echo -e "\nКонкретные параметры, которые не были исполнены:"
    echo "$FAIL_LIST" | sed '/^$/d' | sed 's/^/- /'
fi

if [ -n "$SKIP_LIST" ]; then
    echo -e "\nПараметры, которые невозможно проверить автоматически или неприменимы:"
    echo "$SKIP_LIST" | sed '/^$/d' | sed 's/^/- /'
fi

[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
