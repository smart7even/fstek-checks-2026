#!/bin/bash
# check_iaf4.sh - compatibility wrapper for manifest measure ИАФ.4.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ИАФ.4" "$@"
