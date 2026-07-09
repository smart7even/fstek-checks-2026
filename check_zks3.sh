#!/bin/bash
# check_zks3.sh - compatibility wrapper for manifest measure ЗКС.3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗКС.3" "$@"
