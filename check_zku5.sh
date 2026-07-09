#!/bin/bash
# check_zku5.sh - compatibility wrapper for manifest measure ЗКУ.5.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКУ.5" "$@"
