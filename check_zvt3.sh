#!/bin/bash
# check_zvt3.sh - compatibility wrapper for manifest measure ЗВТ.3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗВТ.3" "$@"
