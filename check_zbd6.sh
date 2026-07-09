#!/bin/bash
# check_zbd6.sh - compatibility wrapper for manifest measure ЗБД.6.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗБД.6" "$@"
