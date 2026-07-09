#!/bin/bash
# check_zmu9.sh - compatibility wrapper for manifest measure ЗМУ.9.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗМУ.9" "$@"
