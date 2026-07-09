#!/bin/bash
# check_zep1.sh - compatibility wrapper for manifest measure ЗЭП.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗЭП.1" "$@"
