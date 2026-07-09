#!/bin/bash
# check_zmu5.sh - compatibility wrapper for manifest measure ЗМУ.5.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗМУ.5" "$@"
