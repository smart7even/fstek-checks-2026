#!/bin/bash
# Fleet audit wrapper.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/fstek_audit/run_fleet.sh" "$@"
