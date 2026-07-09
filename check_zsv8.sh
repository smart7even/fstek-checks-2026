#!/bin/bash
# check_zsv8.sh - compatibility wrapper for manifest measure ЗСВ.8.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗСВ.8" "$@"
