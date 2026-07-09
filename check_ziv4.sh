#!/bin/bash
# check_ziv4.sh - compatibility wrapper for manifest measure ЗИВ.4.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗИВ.4" "$@"
