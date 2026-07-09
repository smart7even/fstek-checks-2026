#!/bin/bash
# check_zku4.sh - compatibility wrapper for manifest measure ЗКУ.4.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКУ.4" "$@"
