#!/bin/bash
# check_zko8.sh - compatibility wrapper for manifest measure ЗКО.8.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКО.8" "$@"
