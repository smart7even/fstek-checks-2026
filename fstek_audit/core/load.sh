#!/bin/bash
# core/load.sh - shared core module loader for the audit engine.

FSTEK_CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FSTEK_AUDIT_DIR="$(cd "$FSTEK_CORE_DIR/.." && pwd)"
FSTEK_REPO_DIR="$(cd "$FSTEK_AUDIT_DIR/.." && pwd)"

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
