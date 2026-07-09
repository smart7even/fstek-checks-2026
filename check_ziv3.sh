#!/bin/bash
# check_ziv3.sh - compatibility wrapper for manifest measure ЗИВ.3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗИВ.3" "$@"
