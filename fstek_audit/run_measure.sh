#!/bin/bash
# Execute one manifest measure file in an isolated process.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ "$#" -ge 2 ] || {
    echo "Usage: run_measure.sh <measure-file> <function> [args...]" >&2
    exit 2
}

MEASURE_FILE="$1"
MEASURE_FUNCTION="$2"
shift 2

# shellcheck disable=SC1091
. "$SCRIPT_DIR/core/load.sh"
fstek_run_measure_function "$MEASURE_FILE" "$MEASURE_FUNCTION" "$@"
