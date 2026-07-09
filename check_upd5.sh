#!/bin/bash
# check_upd5.sh - compatibility wrapper for manifest measure УПД.5.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "УПД.5" "$@"
