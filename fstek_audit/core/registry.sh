#!/bin/bash
# core/registry.sh - measure class and enhancement registry.
# Keep mappings behavior-compatible with the legacy library.

fstek_required_enhancements() {
    case "$1:$2" in
        ИАФ.1:K2|ИАФ.1:K1) printf '1' ;;
        ИАФ.3:K1) printf '1' ;;
        УПД.1:K2|УПД.1:K1) printf '1 2' ;;
        УПД.2:K2) printf '1' ;;
        УПД.2:K1) printf '1 2' ;;
        УПД.3:K2) printf '1' ;;
        УПД.3:K1) printf '1 2' ;;
        УПД.4:K2|УПД.4:K1) printf '1 2' ;;
        УПД.7:K1) printf '1a 1а' ;;
        РСБ.1:K3) printf '1' ;;
        РСБ.1:K2) printf '1 2' ;;
        РСБ.1:K1) printf '1 2 3' ;;
        ЗСВ.1:K2) printf '1' ;;
        ЗСВ.1:K1) printf '1 2' ;;
        ЗСВ.2:K2|ЗСВ.2:K1) printf '1 2' ;;
        ЗСВ.6:K1) printf '1' ;;
        ЗКО.1:K2) printf '1 2' ;;
        ЗКО.1:K1) printf '1 2 3 4 5 6' ;;
        ЗКО.5:K2|ЗКО.5:K1) printf '1' ;;
        ЗКО.8:K2|ЗКО.8:K1) printf '1 2' ;;
        ЗЭП.4:K2|ЗЭП.4:K1) printf '1' ;;
        ЗВТ.2:K2|ЗВТ.2:K1) printf '1' ;;
        ЗВТ.3:K1) printf '1' ;;
        ЗПИ.1:K2|ЗПИ.1:K1) printf '1' ;;
        ЗПИ.3:K1) printf '1' ;;
        ЗКУ.3:K2|ЗКУ.3:K1) printf '1' ;;
        ЗКУ.6:K2|ЗКУ.6:K1) printf '1' ;;
        ЗМУ.1:K2|ЗМУ.1:K1) printf '1' ;;
        ЗМУ.3:K2) printf '1' ;;
        ЗМУ.3:K1) printf '1 2' ;;
        ЗМУ.4:K1) printf '1' ;;
        ЗМУ.9:K2|ЗМУ.9:K1) printf '1' ;;
        ЗИВ.3:K2|ЗИВ.3:K1) printf '1' ;;
        ЗИВ.5:K2|ЗИВ.5:K1) printf '1' ;;
        ЗБД.1:K1) printf '1' ;;
        ЗБД.6:K2|ЗБД.6:K1) printf '1' ;;
        СОВ.1:K2|СОВ.1:K1) printf '1' ;;
        МСЭ.1:K1) printf '1' ;;
        ЗОО.2:K1) printf '1' ;;
        *) printf '' ;;
    esac
}

fstek_manifest_path() {
    if [ -n "${FSTEK_MANIFEST:-}" ]; then
        printf '%s\n' "$FSTEK_MANIFEST"
    elif [ -n "${FSTEK_AUDIT_DIR:-}" ]; then
        printf '%s\n' "$FSTEK_AUDIT_DIR/checks/manifest.tsv"
    else
        printf '%s\n' "fstek_audit/checks/manifest.tsv"
    fi
}

fstek_manifest_field() {
    local code="$1" field="$2" manifest
    manifest="$(fstek_manifest_path)"
    [ -r "$manifest" ] || return 1
    awk -F '\t' -v code="$code" -v field="$field" '
        NR == 1 || /^[[:space:]]*(#|$)/ { next }
        $1 == code { print $field; found = 1; exit }
        END { exit found ? 0 : 1 }
    ' "$manifest"
}

fstek_manifest_has_code() {
    local code="$1" manifest
    manifest="$(fstek_manifest_path)"
    [ -r "$manifest" ] || return 1
    awk -F '\t' -v code="$code" '
        NR == 1 || /^[[:space:]]*(#|$)/ { next }
        $1 == code { found = 1; exit }
        END { exit found ? 0 : 1 }
    ' "$manifest"
}

fstek_manifest_class_contains() {
    local code="$1" wanted="$2" manifest
    manifest="$(fstek_manifest_path)"
    [ -r "$manifest" ] || return 1
    awk -F '\t' -v code="$code" -v wanted="$wanted" '
        NR == 1 || /^[[:space:]]*(#|$)/ { next }
        $1 == code {
            n = split($5, classes, ",")
            for (i = 1; i <= n; i++) {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", classes[i])
                if (classes[i] == wanted) {
                    found = 1
                    exit
                }
            }
        }
        END { exit found ? 0 : 1 }
    ' "$manifest"
}

fstek_measure_classes() {
    local classes
    classes="$(fstek_manifest_field "$1" 5)" || return 0
    printf '%s\n' "$classes" | tr ',' ' '
}

fstek_measure_intentionally_excluded() {
    return 1
}

fstek_measure_enabled() {
    fstek_manifest_class_contains "$1" "$2"
}

fstek_enhancement_enabled() {
    local measure="$1" required id want
    shift
    $WITH_ENHANCEMENTS || return 1
    [ -n "$FSTEK_SECURITY_CLASS" ] || return 0
    required="$(fstek_required_enhancements "$measure" "$FSTEK_SECURITY_CLASS")"
    [ -n "$required" ] || return 1
    for want in "$@"; do
        [ "$want" = "1а" ] && want="1a"
        for id in $required; do
            [ "$id" = "1а" ] && id="1a"
            [ "$id" = "$want" ] && return 0
        done
    done
    return 1
}
