#!/usr/bin/env bash
# Verify the SPO wiki set: numbering from 008=ИАФ.1, no non-SPO measures,
# trial table and SPB.5 admin-UI parameters on every measure page.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/spo-wiki"
fail=0

expect_named() {
    local num="$1" needle="$2"
    local match
    match="$(find "$OUT" -maxdepth 1 -name "${num}. *.md" -print)"
    if [ -z "$match" ]; then
        echo "MISSING $num"
        fail=1
        return
    fi
    if ! printf '%s\n' "$match" | grep -Fq -- "$needle"; then
        echo "WRONG_NAME $num expected $needle got $match"
        fail=1
    fi
}

for n in 001 002 003 004 005 006 007; do
    if ! find "$OUT" -maxdepth 1 -name "${n}. *.md" | grep -q .; then
        echo "MISSING $n"
        fail=1
    fi
done

expect_named 008 "ИАФ.1"
expect_named 009 "ИАФ.2"
expect_named 010 "ИАФ.3"
expect_named 011 "ИАФ.4"
expect_named 012 "УПД.1"
expect_named 020 "УПД.9"
expect_named 021 "РСБ.1"
expect_named 025 "РСБ.5"
expect_named 026 "ЗВТ.1"
expect_named 030 "ЗВТ.5"
expect_named 031 "ЗПИ.1"
expect_named 033 "ЗПИ.3"
expect_named 034 "АВЗ.1"
expect_named 035 "ЗОО.1"
expect_named 036 "ЗОО.3"
expect_named 037 "ЗОО.5"
expect_named 038 "ПДН.1"
expect_named 043 "ПДН.6"
expect_named 044 "СПБ.1"
expect_named 057 "СПБ.14"

count="$(find "$OUT" -maxdepth 1 -name '[0-9][0-9][0-9]. *.md' | wc -l | tr -d ' ')"
if [ "$count" -ne 57 ]; then
    echo "COUNT $count expected 57 numbered pages"
    fail=1
fi

excluded="$(find "$OUT" -maxdepth 1 -name '*.md' -print0 | xargs -0 -n1 basename | grep -E 'ЗСВ\.[0-9]|ЗКО\.[0-9]|ЗЭП\.[0-9]|ЗКУ\.[0-9]|ЗМУ\.[0-9]|ЗИВ\.[0-9]|ЗБД\.[0-9]|СОВ\.[0-9]|МСЭ\.[0-9]|ЗКС\.[0-9]|АВЗ\.[234]|ЗОО\.[246]' || true)"
if [ -n "$excluded" ]; then
    echo "NON_SPO_MEASURE_PRESENT"
    printf '%s\n' "$excluded"
    fail=1
fi

while IFS= read -r f; do
    base="$(basename "$f")"
    if ! grep -Fq 'Цель' "$f"; then
        echo "NO_GOAL $base"
        fail=1
    fi
    if ! grep -Fq 'Требование' "$f" || ! grep -Fq 'Действие' "$f" || ! grep -Fq 'Результат' "$f"; then
        echo "NO_TABLE $base"
        fail=1
    fi
    if ! grep -Fq 'СПБ.5' "$f"; then
        echo "NO_SPB5 $base"
        fail=1
    fi
    if ! grep -Fq 'Требования к усилению' "$f"; then
        echo "NO_ENH $base"
        fail=1
    fi
    if ! grep -Fq 'Мера защиты информации' "$f"; then
        echo "NO_CLASS_TABLE $base"
        fail=1
    fi
    if grep -Fq 'Автопроверка Linux-хоста' "$f" || grep -Fq 'check_all.sh' "$f" || grep -Fq 'fstek_audit/checks/' "$f"; then
        echo "SCRIPT_BOUND $base"
        fail=1
    fi
done < <(find "$OUT" -maxdepth 1 -name '[0-9][0-9][0-9]. *.md' | while read -r p; do
    b="$(basename "$p")"
    n="${b%%.*}"
    n=$((10#$n))
    if [ "$n" -ge 8 ]; then
        printf '%s\n' "$p"
    fi
done)

if [ ! -f "$OUT/README.md" ]; then
    echo "MISSING README"
    fail=1
fi

if [ "$fail" -ne 0 ]; then
    echo "spo wiki check FAILED"
    exit 1
fi
echo "spo wiki check OK ($count pages)"
