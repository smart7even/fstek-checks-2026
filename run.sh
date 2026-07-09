#!/bin/bash
# Root audit runner compatibility entrypoint.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/fstek_audit/run.sh" "$@"
