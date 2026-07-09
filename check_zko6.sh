#!/bin/bash
# check_zko6.sh - compatibility wrapper for manifest measure ЗКО.6.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКО.6" "$@"
