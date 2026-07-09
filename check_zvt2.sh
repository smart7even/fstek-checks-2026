#!/bin/bash
# check_zvt2.sh - compatibility wrapper for manifest measure ЗВТ.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗВТ.2" "$@"
