#!/bin/bash
# check_zbd3.sh - compatibility wrapper for manifest measure ЗБД.3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗБД.3" "$@"
