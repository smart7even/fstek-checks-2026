#!/bin/bash
# check_zep5.sh - compatibility wrapper for manifest measure ЗЭП.5.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗЭП.5" "$@"
