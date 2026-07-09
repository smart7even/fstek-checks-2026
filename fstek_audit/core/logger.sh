#!/bin/bash
# core/logger.sh - lightweight logging helpers for future runner work.

fstek_log_info() { printf 'INFO: %s\n' "$*" >&2; }
fstek_log_warn() { printf 'WARN: %s\n' "$*" >&2; }
fstek_log_error() { printf 'ERROR: %s\n' "$*" >&2; }
