#!/bin/bash
# check_rsb1.sh - compatibility wrapper for manifest measure РСБ.1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" --measure "РСБ.1" "$@"
