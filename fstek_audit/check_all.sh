#!/bin/bash
# Compatibility wrapper for the manifest-driven runner.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run.sh" "$@"
