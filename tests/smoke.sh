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
syntax_output="$(bash tests/syntax.sh 2>&1)"
syntax_rc=$?
if [ "$syntax_rc" -eq 0 ]; then
    ok "syntax all shell files"
else
    fail "syntax all shell files"
    printf '%s\n' "$syntax_output" >&2
fi

printf '\n== measure files ==\n'
while IFS= read -r file; do
    if grep -q '^run_check()' "$file"; then
        ok "$file defines run_check"
    else
        fail "$file lacks run_check"
    fi
done < <(find fstek_audit/checks -mindepth 2 -maxdepth 2 -type f -name '*.sh' | sort)

printf '\n== compatibility wrappers ==\n'
for script in check_*.sh; do
    [ "$script" = "check_all.sh" ] && continue
    measure_code="$(sed -n 's|.*run\.sh" --measure "\([^"]*\)".*|\1|p' "$script")"
    if [ -z "$measure_code" ]; then
        fail "$script does not delegate to run.sh --measure"
        continue
    fi
    if awk -F '\t' -v code="$measure_code" 'NR > 1 && $0 !~ /^[[:space:]]*(#|$)/ && $1 == code { found = 1 } END { exit found ? 0 : 1 }' checks/manifest.tsv; then
        ok "$script -> manifest measure $measure_code"
    else
        fail "$script points to missing manifest measure $measure_code"
    fi
    if grep -Eq 'fstek_run_measure_file|fstek_run_measure_function|^check_[a-z0-9_]+$' "$script"; then
        fail "$script bypasses the manifest runner"
    fi
done

if grep -q 'exec "$SCRIPT_DIR/run.sh" "$@"' check_all.sh; then
    ok "check_all.sh delegates to run.sh"
else
    fail "check_all.sh does not delegate to run.sh"
fi

# shellcheck disable=SC1091
. "$ROOT_DIR/lib_fstek.sh"

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

printf '\n== registry consistency ==\n'
if bash tests/registry_consistency.sh; then
    ok "registry consistency"
else
    fail "registry consistency"
fi

printf '\n== manifest runner ==\n'
if ./run.sh --list | grep -q $'^code\tsection\tclasses\t'; then
    ok "run.sh --list"
else
    fail "run.sh --list"
fi

printf '\n== individual check smoke ==\n'
for script in check_*.sh; do
    [ "$script" = "check_all.sh" ] && continue
    output="$(FSTEK_COLOR=never bash "$script" --class K3 2>&1)"
    rc=$?
    if printf '%s\n' "$output" | awk '
        /^\[[^]]+\] PASS \([A-Z]+\) –/ && $0 !~ /^\[[^]]+\] PASS \((HIGH|MEDIUM)\) –/ {bad=1}
        /^\[[^]]+\] (FAIL|SKIP|INFO|NA) \([A-Z]+\) –/ {bad=1}
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

printf '\n== run.sh class smoke ==\n'
for class in K1 K2 K3; do
    output="$(FSTEK_COLOR=never ./run.sh --class "$class" 2>&1)"
    rc=$?
    if status_is_verdict "$rc" && printf '%s\n' "$output" | grep -q 'ИТОГОВЫЙ ОТЧЕТ'; then
        ok "run.sh --class $class"
    else
        fail "run.sh --class $class exited $rc or missed final report"
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
