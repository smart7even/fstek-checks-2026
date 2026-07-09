#!/bin/bash
# core/os_detector.sh - target Linux distribution detection.

detect_os() {
    OS_NAME="Unknown"; OS_PRETTY="Unknown"; OS_VER=""; OS_ID=""; OS_ID_LIKE=""
    OS_TYPE="generic"; OS_LABEL="Unknown"; OS_SUPPORTED=false
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="${NAME:-Unknown}"
        OS_PRETTY="${PRETTY_NAME:-$OS_NAME}"
        OS_VER="${VERSION_ID:-}"
        OS_ID="${ID:-}"
        OS_ID_LIKE="${ID_LIKE:-}"
    fi

    local os_match
    os_match="$(printf '%s' "$OS_ID $OS_ID_LIKE $OS_NAME $OS_PRETTY" | tr '[:upper:]' '[:lower:]')"
    OS_LABEL="${OS_PRETTY:-$OS_NAME}"

    case "$os_match" in
        *astra*|*alse*)
            case "$OS_VER" in
                1.7*) OS_TYPE="astra17"; OS_SUPPORTED=true; OS_LABEL="Astra Linux Special Edition 1.7" ;;
                1.8*) OS_TYPE="astra18"; OS_SUPPORTED=true; OS_LABEL="Astra Linux Special Edition 1.8" ;;
                *) OS_TYPE="astra"; OS_LABEL="${OS_PRETTY:-Astra Linux}" ;;
            esac
            ;;
        *redos*|*"red os"*|*red-os*|*red_os*)
            OS_TYPE="redos"
            OS_SUPPORTED=true
            OS_LABEL="${OS_PRETTY:-RED OS}"
            ;;
        *altlinux*|*"alt linux"*|*alt*)
            OS_TYPE="alt"
            OS_SUPPORTED=true
            OS_LABEL="${OS_PRETTY:-ALT Linux}"
            ;;
    esac
}

fstek_print_os_info() {
    local supported_note=""
    [ "$OS_SUPPORTED" = true ] || supported_note=" (ОС не входит в целевой список: ALSE 1.7/1.8, RED OS, ALT Linux)"
    echo "ОС: ${OS_LABEL:-Unknown}${supported_note}"
}
