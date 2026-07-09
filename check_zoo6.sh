#!/bin/bash
# check_zoo6.sh - compatibility wrapper for manifest measure ЗОО.6.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗОО.6" "$@"
