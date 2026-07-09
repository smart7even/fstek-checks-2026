#!/bin/bash
# lib_fstek.sh - compatibility loader for legacy check scripts.
# New shared implementation lives under fstek_audit/core/.
# Scripts only read OS configuration and state.

FSTEK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FSTEK_CORE_DIR="$FSTEK_LIB_DIR/fstek_audit/core"

# shellcheck disable=SC1091
. "$FSTEK_CORE_DIR/profile.sh"
# shellcheck disable=SC1091
. "$FSTEK_CORE_DIR/registry.sh"
# shellcheck disable=SC1091
. "$FSTEK_CORE_DIR/logger.sh"
# shellcheck disable=SC1091
. "$FSTEK_CORE_DIR/csv_engine.sh"
# shellcheck disable=SC1091
. "$FSTEK_CORE_DIR/os_detector.sh"
# shellcheck disable=SC1091
. "$FSTEK_CORE_DIR/status.sh"
# shellcheck disable=SC1091
. "$FSTEK_CORE_DIR/runner.sh"
# shellcheck disable=SC1091
. "$FSTEK_CORE_DIR/common.sh"
