#!/bin/bash
# check_zoo4.sh - compatibility wrapper for manifest measure ЗОО.4.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗОО.4" "$@"
