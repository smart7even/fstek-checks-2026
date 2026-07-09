#!/bin/bash
# Safe read-only smoke tests for fstek-checks-2026.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 2

FAILURES=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    FAILURES=$((FAILURES + 1))
}

ok() {
    printf 'ok: %s\n' "$1"
}

status_is_verdict() {
    case "$1" in
        0|1) return 0 ;;
        *) return 1 ;;
    esac
}

printf '== bash -n ==\n'
for file in *.sh tests/*.sh; do
    [ -f "$file" ] || continue
    if bash -n "$file"; then
        ok "syntax $file"
    else
        fail "syntax $file"
    fi
done

# shellcheck disable=SC1091
. "$ROOT_DIR/lib_fstek.sh"

printf '\n== wrapper inventory ==\n'
for script in check_*.sh; do
    [ "$script" = "check_all.sh" ] && continue
    base="${script%.sh}"
    func="${base}"
    if grep -q '^init_measure ' "$script"; then
        if declare -F "$func" >/dev/null 2>&1 && grep -q "^$func$" "$script"; then
            ok "$script calls $func"
        else
            fail "$script is a wrapper but does not call existing $func"
        fi
    fi
done

printf '\n== class mapping completeness ==\n'
for script in check_*.sh; do
    [ "$script" = "check_all.sh" ] && continue
    code="$(fstek_measure_code_from_script "$script")" || {
        fail "cannot derive measure code from $script"
        continue
    }
    if [ -n "$(fstek_measure_classes "$code")" ] || fstek_measure_intentionally_excluded "$code"; then
        ok "$code mapped or intentionally excluded"
    else
        fail "$code from $script is missing from fstek_measure_classes and exclusion list"
    fi
done

printf '\n== individual check smoke ==\n'
for script in check_*.sh; do
    [ "$script" = "check_all.sh" ] && continue
    output="$(FSTEK_COLOR=never bash "$script" --class K3 2>&1)"
    rc=$?
    if printf '%s\n' "$output" | awk '
        /^\[[^]]+\] PASS \([A-Z]+\) –/ && $0 !~ /^\[[^]]+\] PASS \((HIGH|MEDIUM)\) –/ {bad=1}
        /^\[[^]]+\] (FAIL|SKIP) \([A-Z]+\) –/ {bad=1}
        END {exit bad}
    '; then
        :
    else
        fail "$script emitted an invalid confidence-bearing status"
        printf '%s\n' "$output" >&2
        continue
    fi
    if status_is_verdict "$rc" && printf '%s\n' "$output" | grep -Eq '^\[[^]]+\] (PASS \((HIGH|MEDIUM)\)|FAIL|SKIP|INFO|NA) – '; then
        ok "$script --class K3"
    else
        fail "$script --class K3 exited $rc or emitted no verdict"
        printf '%s\n' "$output" >&2
    fi
done

printf '\n== check_all class smoke ==\n'
for class in K1 K2 K3; do
    output="$(FSTEK_COLOR=never bash check_all.sh --class "$class" 2>&1)"
    rc=$?
    if status_is_verdict "$rc" && printf '%s\n' "$output" | grep -q 'ИТОГОВЫЙ ОТЧЕТ'; then
        ok "check_all.sh --class $class"
    else
        fail "check_all.sh --class $class exited $rc or missed final report"
        printf '%s\n' "$output" >&2
    fi
done

if [ "$FAILURES" -eq 0 ]; then
    printf '\nAll smoke tests passed.\n'
else
    printf '\nSmoke tests failed: %s\n' "$FAILURES" >&2
fi

exit "$FAILURES"
