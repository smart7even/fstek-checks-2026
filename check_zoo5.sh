#!/bin/bash
# check_zoo5.sh - compatibility wrapper for manifest measure ЗОО.5.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗОО.5" "$@"
