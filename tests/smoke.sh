#!/bin/bash
# Safe read-only smoke tests for fstek-checks-2026.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 2
MANIFEST="$ROOT_DIR/fstek_audit/checks/manifest.tsv"

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

if grep -q 'exec "$SCRIPT_DIR/fstek_audit/run.sh" "$@"' check_all.sh; then
    ok "check_all.sh delegates to fstek_audit/run.sh"
else
    fail "check_all.sh does not delegate to fstek_audit/run.sh"
fi

# shellcheck disable=SC1091
. "$ROOT_DIR/fstek_audit/core/load.sh"

printf '\n== class mapping completeness ==\n'
while IFS=$'\t' read -r code section file function classes title component; do
    [ "$code" = "code" ] && continue
    case "$code" in ""|\#*) continue ;; esac
    if [ "$classes" = "-" ]; then
        ok "$code optional measure without class applicability"
    elif [ -n "$classes" ]; then
        ok "$code mapped to classes: $classes"
    else
        fail "$code from manifest has invalid class mapping"
    fi
done < "$MANIFEST"

printf '\n== registry consistency ==\n'
if bash tests/registry_consistency.sh; then
    ok "registry consistency"
else
    fail "registry consistency"
fi

printf '\n== manifest runner ==\n'
if ./check_all.sh --list | grep -q $'^code\tsection\tclasses\t'; then
    ok "check_all.sh --list"
else
    fail "check_all.sh --list"
fi

printf '\n== individual measure smoke ==\n'
while IFS=$'\t' read -r code section file function classes title component; do
    [ "$code" = "code" ] && continue
    case "$code" in ""|\#*) continue ;; esac
    output="$(FSTEK_COLOR=never ./check_all.sh --measure "$code" --class K3 2>&1)"
    rc=$?
    if printf '%s\n' "$output" | awk '
        /^\[[^]]+\] PASS \([A-Z]+\) –/ && $0 !~ /^\[[^]]+\] PASS \((HIGH|MEDIUM)\) –/ {bad=1}
        /^\[[^]]+\] (FAIL|SKIP|INFO|NA) \([A-Z]+\) –/ {bad=1}
        END {exit bad}
    '; then
        :
    else
        fail "check_all.sh --measure $code emitted an invalid confidence-bearing status"
        printf '%s\n' "$output" >&2
        continue
    fi
    if status_is_verdict "$rc" && printf '%s\n' "$output" | grep -Eq '^\[[^]]+\] (PASS \((HIGH|MEDIUM)\)|FAIL|SKIP|INFO|NA) – '; then
        ok "check_all.sh --measure $code --class K3"
    else
        fail "check_all.sh --measure $code --class K3 exited $rc or emitted no verdict"
        printf '%s\n' "$output" >&2
    fi
done < "$MANIFEST"

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

printf '\n== report output ==\n'
REPORT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fstek-report-smoke.XXXXXX")"
REPORT_BATCH="smoke-$(date +%s)"
if FSTEK_COLOR=never ./check_all.sh --class K3 --output-dir "$REPORT_DIR" --batch-id "$REPORT_BATCH" >/dev/null 2>&1; then
    report_rc=0
else
    report_rc=$?
fi
REPORT_ARTIFACT_DIR="$REPORT_DIR/$REPORT_BATCH"
report_log_count="$(find "$REPORT_ARTIFACT_DIR" -maxdepth 1 -type f -name '*.log' 2>/dev/null | wc -l | tr -d ' ')"
report_json_count="$(find "$REPORT_ARTIFACT_DIR" -maxdepth 1 -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
if [ -d "$REPORT_ARTIFACT_DIR" ] && [ "$report_log_count" -ge 1 ] && [ "$report_json_count" -ge 1 ]; then
    ok "check_all.sh --output-dir writes log and json"
else
    fail "check_all.sh --output-dir missing artifacts (rc=$report_rc log=$report_log_count json=$report_json_count)"
fi
if [ "$report_json_count" -ge 1 ]; then
    sample_json="$(find "$REPORT_ARTIFACT_DIR" -maxdepth 1 -type f -name '*.json' | head -n 1)"
    if grep -q '"schema"[[:space:]]*:[[:space:]]*"fstek-audit-summary/v1"' "$sample_json"; then
        ok "report json schema fstek-audit-summary/v1"
    else
        fail "report json missing expected schema"
    fi
fi
rm -rf "$REPORT_DIR"

printf '\n== fleet runner ==\n'
if grep -q 'exec "$SCRIPT_DIR/fstek_audit/run_fleet.sh"' fleet_check.sh; then
    ok "fleet_check.sh delegates to run_fleet.sh"
else
    fail "fleet_check.sh does not delegate to run_fleet.sh"
fi
if ./fleet_check.sh --help 2>&1 | grep -q 'run_fleet.sh'; then
    ok "fleet_check.sh --help"
else
    fail "fleet_check.sh --help"
fi
if ./fleet_check.sh 2>&1 | grep -q 'inventory'; then
    ok "fleet_check.sh requires inventory"
else
    fail "fleet_check.sh missing inventory validation"
fi

printf '\n== fleet aggregate ==\n'
if bash tests/aggregate.sh; then
    ok "fleet aggregate csv"
else
    fail "fleet aggregate csv"
fi

printf '\n== fleet inventory ==\n'
if bash tests/fleet_inventory.sh; then
    ok "fleet inventory auth parsing"
else
    fail "fleet inventory auth parsing"
fi

if [ "$FAILURES" -eq 0 ]; then
    printf '\nAll smoke tests passed.\n'
else
    printf '\nSmoke tests failed: %s\n' "$FAILURES" >&2
fi

exit "$FAILURES"
