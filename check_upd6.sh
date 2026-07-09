#!/bin/bash
# check_upd6.sh - compatibility wrapper for manifest measure УПД.6.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "УПД.6" "$@"
