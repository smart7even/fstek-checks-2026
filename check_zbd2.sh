#!/bin/bash
# check_zbd2.sh - compatibility wrapper for manifest measure ЗБД.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗБД.2" "$@"
