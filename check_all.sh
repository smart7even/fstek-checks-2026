#!/bin/bash
# check_all.sh - агрегатор проверок мер защиты ФСТЭК 2026.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 2
. "$SCRIPT_DIR/lib_fstek.sh"

ENHANCE_ARGS=()
if [ -n "$FSTEK_SECURITY_CLASS" ]; then
    ENHANCE_ARGS=(--class "$FSTEK_SECURITY_CLASS")
    echo ">>> Режим проверки базового набора мер и усилений для класса $FSTEK_SECURITY_CLASS включен."
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
TOTAL_PASS_HIGH=0
TOTAL_PASS_MEDIUM=0
TOTAL_FAIL=0
TOTAL_SKIP=0
TOTAL_INFO=0
TOTAL_NA=0
FAIL_LIST=""
SKIP_LIST=""
INFO_LIST=""
NA_LIST=""
MEASURE_SUMMARY=""
FAILED_MEASURES=""

for script in check_*.sh; do
    [[ "$script" == "check_all.sh" ]] && continue
    [[ ! -x "$script" ]] && chmod +x "$script" 2>/dev/null

    MEASURE_CODE="$(fstek_measure_code_from_script "$script")" || {
        echo -e "\n>>> Пропуск модуля: не удалось определить код меры для $script"
        continue
    }

    if [ -n "$FSTEK_SECURITY_CLASS" ] && ! fstek_measure_enabled "$MEASURE_CODE" "$FSTEK_SECURITY_CLASS"; then
        if fstek_measure_intentionally_excluded "$MEASURE_CODE"; then
            echo -e "\n>>> Пропуск модуля: $MEASURE_CODE ($script) намеренно не входит в базовый набор классов K1/K2/K3 по таблице методики."
            continue
        fi
        echo -e "\n>>> Пропуск модуля: $MEASURE_CODE ($script) не входит в базовый набор для класса $FSTEK_SECURITY_CLASS."
        continue
    fi

    echo -e "\n>>> Запуск модуля: $MEASURE_CODE ($script)"
    OUTPUT=$(FSTEK_COLOR=never bash "$script" "${ENHANCE_ARGS[@]}")
    EXIT_CODE=$?
    printf '%s\n' "$OUTPUT" | fstek_colorize_statuses

    PH_COUNT=$(echo "$OUTPUT" | grep -Ec "^\\[[^]]+\\] PASS \\(HIGH\\) –" || true)
    PM_COUNT=$(echo "$OUTPUT" | grep -Ec "^\\[[^]]+\\] PASS \\(MEDIUM\\) –" || true)
    P_COUNT=$((PH_COUNT + PM_COUNT))
    F_COUNT=$(echo "$OUTPUT" | grep -Ec "^\\[[^]]+\\] FAIL –" || true)
    S_COUNT=$(echo "$OUTPUT" | grep -Ec "^\\[[^]]+\\] SKIP –" || true)
    I_COUNT=$(echo "$OUTPUT" | grep -Ec "^\\[[^]]+\\] INFO –" || true)
    N_COUNT=$(echo "$OUTPUT" | grep -Ec "^\\[[^]]+\\] NA –" || true)

    TOTAL_PASS=$((TOTAL_PASS + P_COUNT))
    TOTAL_PASS_HIGH=$((TOTAL_PASS_HIGH + PH_COUNT))
    TOTAL_PASS_MEDIUM=$((TOTAL_PASS_MEDIUM + PM_COUNT))
    TOTAL_FAIL=$((TOTAL_FAIL + F_COUNT))
    TOTAL_SKIP=$((TOTAL_SKIP + S_COUNT))
    TOTAL_INFO=$((TOTAL_INFO + I_COUNT))
    TOTAL_NA=$((TOTAL_NA + N_COUNT))

    if [ "$F_COUNT" -gt 0 ] || [ "$EXIT_CODE" -ne 0 ]; then
        FAILED_MEASURES+="$MEASURE_CODE"$'\n'
        FAIL_LIST+=$(echo "$OUTPUT" | grep -E "^\\[[^]]+\\] FAIL –" || true)
        FAIL_LIST+=$'\n'
        MEASURE_SUMMARY+="[НЕ ОК] $MEASURE_CODE: $P_COUNT PASS ($PH_COUNT HIGH, $PM_COUNT MEDIUM), $F_COUNT FAIL, $S_COUNT SKIP, $I_COUNT INFO, $N_COUNT NA\n"
    else
        MEASURE_SUMMARY+="[ OK ]  $MEASURE_CODE: $P_COUNT PASS ($PH_COUNT HIGH, $PM_COUNT MEDIUM), 0 FAIL, $S_COUNT SKIP, $I_COUNT INFO, $N_COUNT NA\n"
    fi
    SKIP_LINES=$(echo "$OUTPUT" | grep -E "^\\[[^]]+\\] SKIP –" || true)
    if [ -n "$SKIP_LINES" ]; then
        SKIP_LIST+="$SKIP_LINES"$'\n'
    fi
    INFO_LINES=$(echo "$OUTPUT" | grep -E "^\\[[^]]+\\] INFO –" || true)
    if [ -n "$INFO_LINES" ]; then
        INFO_LIST+="$INFO_LINES"$'\n'
    fi
    NA_LINES=$(echo "$OUTPUT" | grep -E "^\\[[^]]+\\] NA –" || true)
    if [ -n "$NA_LINES" ]; then
        NA_LIST+="$NA_LINES"$'\n'
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
echo "Количество PASS HIGH: $TOTAL_PASS_HIGH"
echo "Количество PASS MEDIUM: $TOTAL_PASS_MEDIUM"
echo "Количество неуспешных проверок: $TOTAL_FAIL"
echo "Процент невыполненных проверок: $FAIL_PERCENT%"
echo "Количество ручных параметров: $TOTAL_SKIP"
echo "Количество информационных наблюдений: $TOTAL_INFO"
echo "Количество неприменимых параметров: $TOTAL_NA"

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
    echo -e "\nПараметры, которые невозможно проверить автоматически:"
    echo "$SKIP_LIST" | sed '/^$/d' | sed 's/^/- /' | fstek_colorize_statuses
fi

if [ -n "$INFO_LIST" ]; then
    echo -e "\nИнформационные наблюдения:"
    echo "$INFO_LIST" | sed '/^$/d' | sed 's/^/- /' | fstek_colorize_statuses
fi

if [ -n "$NA_LIST" ]; then
    echo -e "\nНеприменимые параметры:"
    echo "$NA_LIST" | sed '/^$/d' | sed 's/^/- /' | fstek_colorize_statuses
fi

[ "$TOTAL_FAIL" -eq 0 ] && exit 0 || exit 1
