#!/bin/bash
# check_zbd5.sh - compatibility wrapper for manifest measure ЗБД.5.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗБД.5" "$@"
