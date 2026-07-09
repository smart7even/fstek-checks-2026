#!/bin/bash
# Manifest-driven aggregate runner for FSTEK checks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR" || exit 2

# shellcheck disable=SC1091
. "$ROOT_DIR/lib_fstek.sh"

LIST_ONLY=false
MEASURE_FILTER=""
SECTION_FILTER=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --list)
            LIST_ONLY=true
            ;;
        --measure)
            shift
            [ "$#" -gt 0 ] || { echo "Ошибка: для --measure нужно указать код меры." >&2; exit 2; }
            MEASURE_FILTER="$1"
            ;;
        --measure=*)
            MEASURE_FILTER="${1#*=}"
            ;;
        --section)
            shift
            [ "$#" -gt 0 ] || { echo "Ошибка: для --section нужно указать раздел." >&2; exit 2; }
            SECTION_FILTER="$1"
            ;;
        --section=*)
            SECTION_FILTER="${1#*=}"
            ;;
        --class|--security-class|-c)
            shift
            [ "$#" -gt 0 ] || { echo "Ошибка: для $1 нужно указать K1, K2 или K3." >&2; exit 2; }
            ;;
    esac
    shift
done

MANIFEST="$(fstek_manifest_path)"
[ -r "$MANIFEST" ] || {
    echo "Ошибка: manifest не найден: $MANIFEST" >&2
    exit 2
}

if $LIST_ONLY; then
    printf 'code\tsection\tclasses\ttitle\tcomponent\tfile\n'
    awk -F '\t' '
        NR == 1 || /^[[:space:]]*(#|$)/ { next }
        { printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $5, $6, $7, $3 }
    ' "$MANIFEST"
    exit 0
fi

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
SELECTED_COUNT=0
RUN_ERROR=0

while IFS=$'\t' read -r code section file function classes title component; do
    [ "$code" = "code" ] && continue
    case "$code" in ""|\#*) continue ;; esac

    if [ -n "$MEASURE_FILTER" ] && [ "$code" != "$MEASURE_FILTER" ]; then
        continue
    fi
    if [ -n "$SECTION_FILTER" ] && [ "$section" != "$SECTION_FILTER" ]; then
        continue
    fi
    if [ -z "$MEASURE_FILTER" ] && [ -n "$FSTEK_SECURITY_CLASS" ] && ! fstek_measure_enabled "$code" "$FSTEK_SECURITY_CLASS"; then
        continue
    fi

    measure_file="$SCRIPT_DIR/$file"
    SELECTED_COUNT=$((SELECTED_COUNT + 1))

    echo -e "\n>>> Запуск модуля: $code ($file)"
    OUTPUT=$(FSTEK_COLOR=never bash "$SCRIPT_DIR/run_measure.sh" "$measure_file" "$function" "${ENHANCE_ARGS[@]}" 2>&1)
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
        FAILED_MEASURES+="$code"$'\n'
        FAIL_LIST+=$(echo "$OUTPUT" | grep -E "^\\[[^]]+\\] FAIL –" || true)
        FAIL_LIST+=$'\n'
        MEASURE_SUMMARY+="[НЕ ОК] $code: $P_COUNT PASS ($PH_COUNT HIGH, $PM_COUNT MEDIUM), $F_COUNT FAIL, $S_COUNT SKIP, $I_COUNT INFO, $N_COUNT NA\n"
        [ "$EXIT_CODE" -eq 0 ] || RUN_ERROR=$((RUN_ERROR + 1))
    else
        MEASURE_SUMMARY+="[ OK ]  $code: $P_COUNT PASS ($PH_COUNT HIGH, $PM_COUNT MEDIUM), 0 FAIL, $S_COUNT SKIP, $I_COUNT INFO, $N_COUNT NA\n"
    fi

    SKIP_LINES=$(echo "$OUTPUT" | grep -E "^\\[[^]]+\\] SKIP –" || true)
    [ -n "$SKIP_LINES" ] && SKIP_LIST+="$SKIP_LINES"$'\n'
    INFO_LINES=$(echo "$OUTPUT" | grep -E "^\\[[^]]+\\] INFO –" || true)
    [ -n "$INFO_LINES" ] && INFO_LIST+="$INFO_LINES"$'\n'
    NA_LINES=$(echo "$OUTPUT" | grep -E "^\\[[^]]+\\] NA –" || true)
    [ -n "$NA_LINES" ] && NA_LIST+="$NA_LINES"$'\n'
done < "$MANIFEST"

if [ "$SELECTED_COUNT" -eq 0 ]; then
    echo "Ошибка: по заданным фильтрам не найдено мер в manifest." >&2
    exit 2
fi

TOTAL=$((TOTAL_PASS + TOTAL_FAIL))
if [ "$TOTAL" -gt 0 ]; then
    FAIL_PERCENT=$((TOTAL_FAIL * 100 / TOTAL))
else
    FAIL_PERCENT=0
fi

echo -e "\n#########################################################"
echo "#                  ИТОГОВЫЙ ОТЧЕТ                       #"
echo "#########################################################"
if [ "$TOTAL_FAIL" -eq 0 ] && [ "$RUN_ERROR" -eq 0 ]; then
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
echo "Количество выбранных мер: $SELECTED_COUNT"
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

[ "$TOTAL_FAIL" -eq 0 ] && [ "$RUN_ERROR" -eq 0 ] && exit 0 || exit 1
