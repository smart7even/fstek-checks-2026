#!/bin/bash
# check_mse5.sh - compatibility wrapper for manifest measure МСЭ.5.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "МСЭ.5" "$@"
