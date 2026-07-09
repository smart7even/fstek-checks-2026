#!/bin/bash
# check_zko5.sh - compatibility wrapper for manifest measure ЗКО.5.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКО.5" "$@"
