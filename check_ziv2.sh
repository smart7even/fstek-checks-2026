#!/bin/bash
# check_ziv2.sh - compatibility wrapper for manifest measure ЗИВ.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗИВ.2" "$@"
