#!/bin/bash
# check_avz2.sh - compatibility wrapper for manifest measure АВЗ.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "АВЗ.2" "$@"
