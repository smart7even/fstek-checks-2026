#!/bin/bash
# check_zsv6.sh - compatibility wrapper for manifest measure ЗСВ.6.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗСВ.6" "$@"
