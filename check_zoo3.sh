#!/bin/bash
# check_zoo3.sh - compatibility wrapper for manifest measure ЗОО.3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗОО.3" "$@"
