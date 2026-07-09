#!/bin/bash
# check_zmu2.sh - compatibility wrapper for manifest measure ЗМУ.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗМУ.2" "$@"
