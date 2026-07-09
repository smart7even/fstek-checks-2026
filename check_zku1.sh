#!/bin/bash
# check_zku1.sh - compatibility wrapper for manifest measure ЗКУ.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКУ.1" "$@"
