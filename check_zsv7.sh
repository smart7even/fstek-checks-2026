#!/bin/bash
# check_zsv7.sh - compatibility wrapper for manifest measure ЗСВ.7.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗСВ.7" "$@"
