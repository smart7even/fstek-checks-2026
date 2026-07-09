#!/bin/bash
# check_zmu6.sh - compatibility wrapper for manifest measure ЗМУ.6.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗМУ.6" "$@"
