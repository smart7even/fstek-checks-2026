#!/bin/bash
# check_zpi1.sh - compatibility wrapper for manifest measure ЗПИ.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗПИ.1" "$@"
