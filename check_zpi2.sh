#!/bin/bash
# check_zpi2.sh - compatibility wrapper for manifest measure ЗПИ.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ЗПИ.2" "$@"
