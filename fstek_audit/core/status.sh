#!/bin/bash
# core/status.sh - final status rendering, counters, and compatibility verdict helpers.
# Preserves existing PASS (HIGH), PASS (MEDIUM), FAIL, SKIP, and INFO semantics.

FAIL_COUNT=0
SKIP_COUNT=0
PASS_COUNT=0
PASS_HIGH_COUNT=0
PASS_MEDIUM_COUNT=0
INFO_COUNT=0
NA_COUNT=0

fstek_color_enabled() {
    case "${FSTEK_COLOR:-auto}" in
        always|yes|true|1) return 0 ;;
        never|no|false|0) return 1 ;;
    esac
    [ -n "${NO_COLOR:-}" ] && return 1
    [ -t 1 ]
}

fstek_init_colors() {
    if fstek_color_enabled; then
        FSTEK_C_PASS=$'\033[32m'
        FSTEK_C_FAIL=$'\033[31m'
        FSTEK_C_SKIP=$'\033[33m'
        FSTEK_C_RESET=$'\033[0m'
    else
        FSTEK_C_PASS=""
        FSTEK_C_FAIL=""
        FSTEK_C_SKIP=""
        FSTEK_C_RESET=""
    fi
}

fstek_status_color() {
    case "$1" in
        PASS) printf '%s' "$FSTEK_C_PASS" ;;
        FAIL) printf '%s' "$FSTEK_C_FAIL" ;;
        SKIP) printf '%s' "$FSTEK_C_SKIP" ;;
        INFO) printf '%s' "$FSTEK_C_SKIP" ;;
        NA) printf '%s' "$FSTEK_C_SKIP" ;;
        *) printf '' ;;
    esac
}

fstek_status_line() {
    local code="$1" status="$2" text="$3" confidence="${4:-}" color printable
    case "$status" in
        PASS)
            [ -n "$confidence" ] || confidence="HIGH"
            case "$confidence" in
                HIGH|MEDIUM) ;;
                *) confidence="" ;;
            esac
            ;;
        FAIL|SKIP|INFO|NA)
            confidence=""
            ;;
    esac
    color="$(fstek_status_color "$status")"
    printable="$status"
    [ -n "$confidence" ] && printable="$status ($confidence)"
    printf '[%s] %b%s%b – %s\n' "$code" "$color" "$printable" "$FSTEK_C_RESET" "$text"
}

fstek_colorize_statuses() {
    if fstek_color_enabled; then
        sed -E \
            -e $'s/(^|[^[:alnum:]_])(PASS)([^[:alnum:]_]|$)/\\1\033[32m\\2\033[0m\\3/g' \
            -e $'s/(^|[^[:alnum:]_])(FAIL)([^[:alnum:]_]|$)/\\1\033[31m\\2\033[0m\\3/g' \
            -e $'s/(^|[^[:alnum:]_])(SKIP)([^[:alnum:]_]|$)/\\1\033[33m\\2\033[0m\\3/g' \
            -e $'s/(^|[^[:alnum:]_])(INFO)([^[:alnum:]_]|$)/\\1\033[33m\\2\033[0m\\3/g' \
            -e $'s/(^|[^[:alnum:]_])(NA)([^[:alnum:]_]|$)/\\1\033[33m\\2\033[0m\\3/g'
    else
        cat
    fi
}

fstek_init_colors

check_pass() {
    local code="$1" confidence="HIGH" text
    shift
    if [ "$#" -ge 2 ]; then
        case "$1" in
            HIGH|MEDIUM) confidence="$1"; shift ;;
            [A-Z][A-Z]*) confidence="INFO"; shift ;;
        esac
    fi
    text="$*"
    case "$confidence" in
        MEDIUM)
            fstek_status_line "$code" "PASS" "$text" "MEDIUM"
            ((PASS_COUNT++))
            ((PASS_MEDIUM_COUNT++))
            ;;
        INFO)
            check_info "$code" "$text"
            ;;
        *)
            fstek_status_line "$code" "PASS" "$text" "HIGH"
            ((PASS_COUNT++))
            ((PASS_HIGH_COUNT++))
            ;;
    esac
    return 0
}

check_pass_high() { local code="$1"; shift; check_pass "$code" HIGH "$*"; }
check_pass_medium() { local code="$1"; shift; check_pass "$code" MEDIUM "$*"; }

check_fail() {
    local code="$1" text
    shift
    if [ "$#" -ge 2 ]; then
        case "$1" in
            HIGH|MEDIUM) shift ;;
            [A-Z][A-Z]*)
                shift
                check_info "$code" "$*"
                return 0
                ;;
        esac
    fi
    text="$*"
    fstek_status_line "$code" "FAIL" "$text"
    ((FAIL_COUNT++))
    return 0
}

check_skip() {
    local code="$1" text="$2"
    case "$text" in
        *"Средства виртуализации"*"не обнаружены"*)
            if fstek_component_expected virtualization; then
                check_fail "$code" "Профиль требует стек виртуализации, но libvirt/virsh не обнаружены"
            else
                check_na "$code" "Стек виртуализации libvirt/virsh не обнаружен"
            fi
            return 0
            ;;
        *"Средства контейнеризации"*"не обнаружены"*)
            if fstek_component_expected containers; then
                check_fail "$code" "Профиль требует контейнерный стек, но Docker/Podman/container runtime не обнаружены"
            else
                check_na "$code" "Контейнерный стек Docker/Podman/container runtime не обнаружен"
            fi
            return 0
            ;;
        *"Почтовый сервер не обнаружен"*)
            if fstek_component_expected mail; then
                check_fail "$code" "Профиль требует почтовый стек, но Postfix/Dovecot/Exim/Sendmail не обнаружены"
            else
                check_na "$code" "Почтовый стек Postfix/Dovecot/Exim/Sendmail не обнаружен"
            fi
            return 0
            ;;
    esac
    fstek_status_line "$code" "SKIP" "$text"
    ((SKIP_COUNT++))
    return 0
}
check_na() { fstek_status_line "$1" "NA" "$2"; ((NA_COUNT++)); return 0; }
check_info() { fstek_status_line "$1" "INFO" "$2"; ((INFO_COUNT++)); return 0; }
skip_enhancement() {
    local reason="проверка усилений отключена"
    [ -n "$FSTEK_SECURITY_CLASS" ] && reason="усиление не требуется для класса $FSTEK_SECURITY_CLASS"
    fstek_status_line "$1" "SKIP" "$reason"
    ((SKIP_COUNT++))
    return 0
}
