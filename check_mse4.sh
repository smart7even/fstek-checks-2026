#!/bin/bash
# check_mse4.sh - compatibility wrapper for manifest measure МСЭ.4.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "МСЭ.4" "$@"
