#!/bin/bash
# check_zep3.sh - compatibility wrapper for manifest measure ЗЭП.3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗЭП.3" "$@"
