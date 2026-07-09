#!/bin/bash
# core/profile.sh - CLI class flags and local profile/scope loading.

WITH_ENHANCEMENTS=false
FSTEK_SECURITY_CLASS=""

fstek_normalize_security_class() {
    case "$1" in
        k1|K1|к1|К1) printf 'K1' ;;
        k2|K2|к2|К2) printf 'K2' ;;
        k3|K3|к3|К3) printf 'K3' ;;
        *) return 1 ;;
    esac
}

fstek_set_security_class() {
    local class
    class="$(fstek_normalize_security_class "$1")" || {
        echo "Ошибка: неизвестный класс защищенности '$1'. Используйте K1, K2 или K3." >&2
        exit 2
    }
    FSTEK_SECURITY_CLASS="$class"
    WITH_ENHANCEMENTS=true
}

fstek_parse_cli() {
    local arg
    while [ "$#" -gt 0 ]; do
        arg="$1"
        case "$arg" in
            --with-enhancements|-e)
                WITH_ENHANCEMENTS=true
                ;;
            --class|--security-class|-c)
                shift
                [ "$#" -gt 0 ] || {
                    echo "Ошибка: для $arg нужно указать K1, K2 или K3." >&2
                    exit 2
                }
                fstek_set_security_class "$1"
                ;;
            --class=*|--security-class=*)
                fstek_set_security_class "${arg#*=}"
                ;;
            --k1|--K1|--к1|--К1)
                fstek_set_security_class "K1"
                ;;
            --k2|--K2|--к2|--К2)
                fstek_set_security_class "K2"
                ;;
            --k3|--K3|--к3|--К3)
                fstek_set_security_class "K3"
                ;;
        esac
        shift
    done
}

fstek_parse_cli "$@"

FSTEK_PROFILE_LOADED=false

fstek_load_profile() {
    local profile
    $FSTEK_PROFILE_LOADED && return 0
    FSTEK_PROFILE_LOADED=true

    for profile in ./fstek_profile.conf /etc/fstek-checks/profile.conf; do
        [ -r "$profile" ] || continue
        # shellcheck disable=SC1090
        . "$profile"
    done
}

fstek_profile_bool() {
    local name="$1" value
    fstek_load_profile
    eval "value=\"\${$name:-}\""
    case "$value" in
        1|yes|true|on|да|истина|y|Y|YES|TRUE|ON) return 0 ;;
        *) return 1 ;;
    esac
}

fstek_component_expected() {
    case "$1" in
        web) fstek_profile_bool FSTEK_EXPECT_WEB ;;
        api) fstek_profile_bool FSTEK_EXPECT_API ;;
        containers) fstek_profile_bool FSTEK_EXPECT_CONTAINERS ;;
        virtualization) fstek_profile_bool FSTEK_EXPECT_VIRTUALIZATION ;;
        mail) fstek_profile_bool FSTEK_EXPECT_MAIL ;;
        wireless) fstek_profile_bool FSTEK_EXPECT_WIRELESS ;;
        siem) fstek_profile_bool FSTEK_EXPECT_SIEM ;;
        av) fstek_profile_bool FSTEK_EXPECT_AV ;;
        *) return 1 ;;
    esac
}
