#!/bin/bash
# check_ziv1.sh - compatibility wrapper for manifest measure ЗИВ.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗИВ.1" "$@"
