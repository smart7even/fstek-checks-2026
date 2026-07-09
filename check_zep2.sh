#!/bin/bash
# check_zep2.sh - compatibility wrapper for manifest measure ЗЭП.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗЭП.2" "$@"
