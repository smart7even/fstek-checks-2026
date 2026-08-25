#!/usr/bin/env bash
# Verify that every manifest measure has a methodology markdown file
# with the required sections from the IAF.1 template.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/fstek_audit/checks/manifest.tsv"
OUT="$ROOT/docs/methodology"
fail=0

section_num() {
    case "$1" in
        IAF) printf '7' ;;
        UPD) printf '8' ;;
        RSB) printf '9' ;;
        ZSV) printf '10' ;;
        ZKO) printf '11' ;;
        ZEP) printf '12' ;;
        ZVT) printf '13' ;;
        ZPI) printf '14' ;;
        ZKU) printf '15' ;;
        ZMU) printf '16' ;;
        ZIV) printf '17' ;;
        ZBD) printf '18' ;;
        AVZ) printf '19' ;;
        SOV) printf '20' ;;
        MSE) printf '21' ;;
        ZOO) printf '22' ;;
        ZKS) printf '23' ;;
        *) printf '0' ;;
    esac
}

while IFS=$'\t' read -r code section _relpath _func _classes title _component; do
    [[ "$code" =~ ^# ]] && continue
    [ -z "$code" ] && continue
    sec="$(section_num "$section")"
    mnum="${code##*.}"
    safe_title="${title//\//-}"
    expected="$(printf '%s/%s/%s.%s. %s %s.md' "$OUT" "$section" "$sec" "$mnum" "$code" "$safe_title")"
    if [ ! -f "$expected" ]; then
        echo "MISSING $code -> $expected"
        fail=1
        continue
    fi
    if ! grep -q '^Цель:' "$expected"; then
        echo "NO_GOAL $code"
        fail=1
    fi
    if ! grep -q '^Регламентирование:' "$expected"; then
        echo "NO_REG $code"
        fail=1
    fi
    if ! grep -q '| Требование | Действие | Результат |' "$expected"; then
        echo "NO_TABLE $code"
        fail=1
    fi
    if ! grep -q '^Требования к усилению:' "$expected"; then
        echo "NO_ENH $code"
        fail=1
    fi
    if ! grep -q '| Мера защиты информации | К3 | К2 | К1 |' "$expected"; then
        echo "NO_CLASS_TABLE $code"
        fail=1
    fi
done < <(tail -n +2 "$MANIFEST" | grep -v '^#')

# stray sub-measure stubs should not exist
stray="$(find "$OUT" -type f -name '*.md' ! -name 'README.md' | awk '
    BEGIN { FS="/" }
    {
        n = split($NF, a, " ")
        # measure files look like "7.1. ИАФ.1 Title.md" (section.measure.)
        # sub-measure stubs look like "7.1.1. ИАФ.1.1.md"
        if ($NF ~ /^[0-9]+\.[0-9]+\.[0-9]+\. /) print
    }
')"
if [ -n "$stray" ]; then
    echo "STRAY_SUBMEASURES:"
    printf '%s\n' "$stray"
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    echo "methodology docs check FAILED"
    exit 1
fi
echo "methodology docs check OK"
