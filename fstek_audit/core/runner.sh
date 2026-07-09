#!/bin/bash
# core/runner.sh - per-measure runner lifecycle helpers.

init_measure() {
    MEASURE_CODE="$1"
    MEASURE_TITLE="$2"
    detect_os
    echo "=== МОДУЛЬ $MEASURE_CODE: $MEASURE_TITLE ==="
    fstek_print_os_info
}

finish_measure() {
    printf '=== ИТОГ МОДУЛЯ %s: PASS=%s, PASS_HIGH=%s, PASS_MEDIUM=%s, FAIL=%s, SKIP=%s, INFO=%s, NA=%s ===\n' "$MEASURE_CODE" "$PASS_COUNT" "$PASS_HIGH_COUNT" "$PASS_MEDIUM_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$INFO_COUNT" "$NA_COUNT" | fstek_colorize_statuses
    [ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
}

finish_legacy_measure() {
    local code="$1"
    printf '=== ИТОГ МОДУЛЯ %s: PASS=%s, PASS_HIGH=%s, PASS_MEDIUM=%s, FAIL=%s, SKIP=%s, INFO=%s, NA=%s ===\n' "$code" "$PASS_COUNT" "$PASS_HIGH_COUNT" "$PASS_MEDIUM_COUNT" "$FAIL_COUNT" "$SKIP_COUNT" "$INFO_COUNT" "$NA_COUNT" | fstek_colorize_statuses
    [ "$FAIL_COUNT" -eq 0 ] && exit 0 || exit 1
}

fstek_run_measure_file() {
    local measure_file="$1"
    shift
    fstek_run_measure_function "$measure_file" run_check "$@"
}

fstek_run_measure_function() {
    local measure_file="$1" measure_function="$2"
    shift 2

    if [ ! -r "$measure_file" ]; then
        echo "Ошибка: файл проверки не найден: $measure_file" >&2
        exit 2
    fi

    unset -f run_check 2>/dev/null || true
    # shellcheck disable=SC1090
    . "$measure_file"

    if ! declare -F "$measure_function" >/dev/null 2>&1; then
        echo "Ошибка: файл проверки не определяет $measure_function: $measure_file" >&2
        exit 2
    fi

    "$measure_function" "$@"
}
