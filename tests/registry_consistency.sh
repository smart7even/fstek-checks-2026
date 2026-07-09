#!/bin/bash
# Consistency checks for the manifest-driven registry.

set -u
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 2

manifest="checks/manifest.tsv"
[ -r "$manifest" ] || { printf 'FAIL: missing %s\n' "$manifest" >&2; exit 1; }

failures=0
rows=0

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    failures=$((failures + 1))
}

header="$(head -n 1 "$manifest")"
expected_header=$'code\tsection\tfile\tfunction\tclasses\ttitle\tcomponent'
[ "$header" = "$expected_header" ] || fail "unexpected manifest header: $header"

duplicates="$(awk -F '\t' 'NR > 1 && $0 !~ /^[[:space:]]*(#|$)/ { count[$1]++ } END { for (code in count) if (count[code] > 1) print code }' "$manifest")"
[ -z "$duplicates" ] || fail "duplicate manifest codes: $duplicates"

manifest_files=""
manifest_codes=""

while IFS=$'\t' read -r code section file function classes title component; do
    [ "$code" = "code" ] && continue
    case "$code" in ""|\#*) continue ;; esac
    rows=$((rows + 1))
    manifest_files="${manifest_files}${file}"$'\n'
    manifest_codes="${manifest_codes}${code}"$'\n'

    [ -n "$section" ] || fail "$code has empty section"
    [ -n "$file" ] || fail "$code has empty file"
    [ -n "$function" ] || fail "$code has empty function"
    [ -n "$classes" ] || fail "$code has empty classes"
    [ -n "$title" ] || fail "$code has empty title"
    [ -n "$component" ] || fail "$code has empty component"

    if [ ! -r "$file" ]; then
        fail "$code references missing file $file"
        continue
    fi
    if ! grep -q "^$function()" "$file"; then
        fail "$code references missing function $function in $file"
    fi
    case "$file" in
        checks/"$section"/*) : ;;
        *) fail "$code section/file mismatch: $section vs $file" ;;
    esac
    case "$classes" in
        *K1*|*K2*|*K3*) : ;;
        *) fail "$code has no runnable class in $classes" ;;
    esac
done < "$manifest"

measure_files="$(find fstek_audit/checks -mindepth 2 -maxdepth 2 -type f -name '*.sh' \
    | sed 's#^fstek_audit/##' \
    | sort)"
manifest_files="$(printf '%s' "$manifest_files" | sed '/^$/d' | sort -u)"
manifest_codes="$(printf '%s' "$manifest_codes" | sed '/^$/d' | sort -u)"

for file in $measure_files; do
    if ! printf '%s\n' "$manifest_files" | grep -Fxq "$file"; then
        fail "measure file missing from manifest: $file"
    fi
done

for file in $manifest_files; do
    if ! printf '%s\n' "$measure_files" | grep -Fxq "$file"; then
        fail "manifest references non-measure file: $file"
    fi
done

if ! grep -q 'exec "$SCRIPT_DIR/run.sh" "$@"' check_all.sh; then
    fail "check_all.sh does not delegate to run.sh"
fi

for class in K1 K2 K3; do
    count="$(awk -F '\t' -v class="$class" '
        NR == 1 || /^[[:space:]]*(#|$)/ { next }
        {
            n = split($5, classes, ",")
            for (i = 1; i <= n; i++) {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", classes[i])
                if (classes[i] == class) { total++; break }
            }
        }
        END { print total + 0 }
    ' "$manifest")"
    [ "$count" -gt 0 ] || fail "class $class selects no measures"
done

if ./run.sh --list >/dev/null 2>&1; then
    :
else
    fail "run.sh --list failed"
fi

if [ "$failures" -eq 0 ]; then
    printf 'Registry consistency passed for %s manifest rows.\n' "$rows"
else
    printf 'Registry consistency failures: %s\n' "$failures" >&2
fi

exit "$failures"
