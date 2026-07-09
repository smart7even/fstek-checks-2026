#!/bin/bash
# check_zks2.sh - compatibility wrapper for manifest measure ЗКС.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКС.2" "$@"
