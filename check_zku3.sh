#!/bin/bash
# check_zku3.sh - compatibility wrapper for manifest measure ЗКУ.3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКУ.3" "$@"
