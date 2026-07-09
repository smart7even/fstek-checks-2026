#!/bin/bash
# check_zep6.sh - compatibility wrapper for manifest measure ЗЭП.6.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗЭП.6" "$@"
