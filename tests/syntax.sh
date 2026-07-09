#!/bin/bash
# Syntax check for all shell scripts in the repository.

set -u
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 2

failures=0
while IFS= read -r file; do
    if bash -n "$file"; then
        printf 'ok: syntax %s\n' "$file"
    else
        printf 'FAIL: syntax %s\n' "$file" >&2
        failures=$((failures + 1))
    fi
done < <(find . -type f -name '*.sh' -not -path './.git/*' -print | sort)

if [ "$failures" -eq 0 ]; then
    printf 'All shell scripts passed syntax checks.\n'
else
    printf 'Syntax failures: %s\n' "$failures" >&2
fi

exit "$failures"
