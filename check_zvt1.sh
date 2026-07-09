#!/bin/bash
# check_zvt1.sh - compatibility wrapper for manifest measure ЗВТ.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗВТ.1" "$@"
