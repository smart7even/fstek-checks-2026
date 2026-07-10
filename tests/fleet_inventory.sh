#!/bin/bash
# Unit-style tests for fleet inventory parsing and SSH auth resolution.

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

# shellcheck disable=SC1091
. "$ROOT_DIR/fstek_audit/core/load.sh"
# shellcheck disable=SC1091
. "$ROOT_DIR/fstek_audit/core/fleet.sh"

printf '== host line parsing ==\n'
fstek_fleet_parse_host_line "vm1.example.com|10.0.0.11" "root" "22" "/opt/repo"
if [ "$FLEET_HOSTNAME" = "vm1.example.com" ] && [ "$FLEET_IP" = "10.0.0.11" ] && [ "$FLEET_USER" = "root" ]; then
    ok "minimal host line"
else
    fail "minimal host line"
fi

fstek_fleet_parse_host_line "vm2|10.0.0.12|ops|2222|/srv/repo|/tmp/key|FSTEK_PASS_VM2" "root" "22" "/opt/repo"
if [ "$FLEET_PORT" = "2222" ] && [ "$FLEET_SSH_KEY" = "/tmp/key" ] && [ "$FLEET_PASSWORD_ENV" = "FSTEK_PASS_VM2" ]; then
    ok "extended host line"
else
    fail "extended host line"
fi

printf '\n== auth resolution auto ==\n'
KEY_FILE="$(mktemp "${TMPDIR:-/tmp}/fstek-key.XXXXXX")"
touch "$KEY_FILE"
chmod 600 "$KEY_FILE"

fstek_fleet_parse_host_line "vm-key|10.0.0.20|root|22|/opt/repo|$KEY_FILE" "root" "22" "/opt/repo"
if fstek_fleet_resolve_auth "" "FSTEK_SSH_PASSWORD" "auto" && [ "$FLEET_AUTH_MODE" = "key" ]; then
    ok "auto prefers host key"
else
    fail "auto prefers host key"
fi

fstek_fleet_parse_host_line "vm-pass|10.0.0.21|root|22|/opt/repo|-" "root" "22" "/opt/repo"
export FSTEK_SSH_PASSWORD='secret'
if fstek_fleet_resolve_auth "" "FSTEK_SSH_PASSWORD" "auto" && [ "$FLEET_AUTH_MODE" = "password" ]; then
    ok "auto falls back to password env"
else
    fail "auto falls back to password env"
fi
unset FSTEK_SSH_PASSWORD

fstek_fleet_parse_host_line "vm-none|10.0.0.22|root|22|/opt/repo" "root" "22" "/opt/repo"
if fstek_fleet_resolve_auth "" "FSTEK_SSH_PASSWORD" "auto"; then
    fail "auto without credentials should fail"
else
    ok "auto without credentials fails clearly"
fi

rm -f "$KEY_FILE"

printf '\n== remote sudo prefix ==\n'
prefix="$(fstek_fleet_remote_sudo_prefix true)"
if [ "$prefix" = "sudo -n " ]; then
    ok "remote sudo enabled"
else
    fail "remote sudo enabled"
fi
prefix="$(fstek_fleet_remote_sudo_prefix false)"
if [ -z "$prefix" ]; then
    ok "remote sudo disabled"
else
    fail "remote sudo disabled"
fi

if [ "$FAILURES" -eq 0 ]; then
    printf '\nAll fleet inventory tests passed.\n'
else
    printf '\nFleet inventory tests failed: %s\n' "$FAILURES" >&2
fi

exit "$FAILURES"
