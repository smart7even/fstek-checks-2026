#!/bin/bash
# check_upd1.sh - compatibility wrapper for manifest measure УПД.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "УПД.1" "$@"
