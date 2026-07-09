#!/bin/bash
# check_zmu8.sh - compatibility wrapper for manifest measure ЗМУ.8.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗМУ.8" "$@"
