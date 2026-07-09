#!/bin/bash
# core/csv_engine.sh - CSV escaping/writing primitives for future report output.
# Current command-line behavior does not emit CSV yet.

fstek_csv_escape() {
    local value="$1"
    value="${value//\"/\"\"}"
    printf '"%s"' "$value"
}

fstek_csv_row() {
    local first=true field
    for field in "$@"; do
        if $first; then
            first=false
        else
            printf ','
        fi
        fstek_csv_escape "$field"
    done
    printf '\n'
}
