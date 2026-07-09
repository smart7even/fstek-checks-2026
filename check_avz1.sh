#!/bin/bash
# check_avz1.sh - compatibility wrapper for manifest measure АВЗ.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "АВЗ.1" "$@"
