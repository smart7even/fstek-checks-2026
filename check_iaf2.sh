#!/bin/bash
# check_iaf2.sh - compatibility wrapper for manifest measure ИАФ.2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "ИАФ.2" "$@"
