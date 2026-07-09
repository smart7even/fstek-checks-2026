#!/bin/bash
# check_zko3.sh - compatibility wrapper for manifest measure ЗКО.3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКО.3" "$@"
