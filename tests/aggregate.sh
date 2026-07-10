#!/bin/bash
# Aggregate CSV tests using a sample scan log fixture.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 2

FAILURES=0
fail() { printf 'FAIL: %s\n' "$1" >&2; FAILURES=$((FAILURES + 1)); }
ok() { printf 'ok: %s\n' "$1"; }

FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fstek-aggregate-fixture.XXXXXX")"
BATCH_DIR="$FIXTURE_DIR/lab-fixture"
HOST_DIR="$BATCH_DIR/yc-lab/lab-fixture"
mkdir -p "$HOST_DIR"

cat >"$HOST_DIR/host.log" <<'EOF'
[ИАФ.1.1] PASS (HIGH) – PAM ok
[ИАФ.3.1] FAIL – pwquality missing
[ЗСВ.1] NA – libvirt not present
EOF

cat >"$HOST_DIR/host.json" <<'EOF'
{
  "hostname": "lab-host",
  "primary_ip": "10.0.0.10",
  "os_label": "Ubuntu 24.04",
  "overall_result": "FAIL"
}
EOF

# shellcheck disable=SC1091
. "$ROOT_DIR/fstek_audit/core/load.sh"
# shellcheck disable=SC1091
. "$ROOT_DIR/fstek_audit/core/aggregate.sh"

MEASURES="$BATCH_DIR/fleet-measures.csv"
ROLLUPS="$BATCH_DIR/fleet-measure-rollups.csv"

if fstek_aggregate_batch "$BATCH_DIR" "lab-fixture" "$MEASURES" "$ROLLUPS"; then
    ok "aggregate batch"
else
    fail "aggregate batch"
fi

if grep -q 'ИАФ.3.1,FAIL,' "$MEASURES" && grep -q 'ИАФ.1.1,PASS,HIGH,' "$MEASURES"; then
    ok "measure rows parsed"
else
    fail "measure rows parsed"
fi

if grep -q 'ИАФ.3.1,FAIL,1' "$ROLLUPS"; then
    ok "rollup counts"
else
    fail "rollup counts"
fi

rm -rf "$FIXTURE_DIR"

if [ "$FAILURES" -eq 0 ]; then
    printf '\nAll aggregate tests passed.\n'
else
    printf '\nAggregate tests failed: %s\n' "$FAILURES" >&2
fi
exit "$FAILURES"
