#!/bin/bash
# check_sov1.sh - compatibility wrapper for manifest measure СОВ.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "СОВ.1" "$@"
