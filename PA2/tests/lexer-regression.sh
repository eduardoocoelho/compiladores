#!/usr/bin/env bash

set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
lexer="$project_dir/lexer"
reference_lexer=${REFERENCE_LEXER:-/var/tmp/cool/lib/.x86_64/lexer}
test_dir=$(mktemp -d /tmp/pa2-lexer-tests.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT

make -C "$project_dir" lexer >/dev/null

if [[ ! -x "$reference_lexer" ]]; then
    printf 'Reference lexer not found: %s\n' "$reference_lexer" >&2
    exit 2
fi

(cd "$project_dir" && ./lexer test.cl) >"$test_dir/test.actual"
(cd "$project_dir" && "$reference_lexer" test.cl) >"$test_dir/test.expected"
diff -u "$test_dir/test.expected" "$test_dir/test.actual"
printf 'PASS comprehensive-token-suite\n'

(
    cd "$project_dir"
    ./lexer tests/fatorial.cl
) >"$test_dir/fatorial.actual"
(
    cd "$project_dir"
    "$reference_lexer" tests/fatorial.cl
) >"$test_dir/fatorial.expected"
diff -u "$test_dir/fatorial.expected" "$test_dir/fatorial.actual"
printf 'PASS valid-factorial-program\n'

assert_stream() {
    local name=$1
    local input_spec=$2
    local expected=$3
    local actual_file="$test_dir/$name.actual"
    local expected_file="$test_dir/$name.expected"

    printf '%b' "$input_spec" | "$lexer" /dev/stdin >"$actual_file"
    printf '%s' "$expected" >"$expected_file"
    diff -u "$expected_file" "$actual_file"
    printf 'PASS %s\n' "$name"
}

assert_file_matches_reference() {
    local name=$1
    local input_file=$2
    local actual_file="$test_dir/$name.actual"
    local expected_file="$test_dir/$name.expected"

    "$lexer" "$input_file" >"$actual_file"
    "$reference_lexer" "$input_file" >"$expected_file"
    diff -u "$expected_file" "$actual_file"
    printf 'PASS %s\n' "$name"
}

assert_stream \
    "raw-null-at-eof" \
    '"a\0b' \
    $'#name "/dev/stdin"\n#1 ERROR "String contains null character."\n'

assert_stream \
    "escaped-null-at-eof" \
    '"a\\\0b' \
    $'#name "/dev/stdin"\n#1 ERROR "String contains escaped null character."\n'

assert_stream \
    "raw-null-newline-recovery" \
    '"a\0b\nclass' \
    $'#name "/dev/stdin"\n#1 ERROR "String contains null character."\n#2 CLASS\n'

assert_stream \
    "backslash-at-eof" \
    '"abc\' \
    $'#name "/dev/stdin"\n#1 ERROR "backslash at end of file"\n'

boundary_1024="$test_dir/string-1024.cl"
{
    printf '"'
    head -c 1024 /dev/zero | tr '\0' A
    printf '"'
} >"$boundary_1024"

assert_file_matches_reference "string-length-1024" "$boundary_1024"

boundary_1025="$test_dir/string-1025.cl"
{
    printf '"'
    head -c 1025 /dev/zero | tr '\0' B
    printf '" class'
} >"$boundary_1025"

assert_file_matches_reference "string-length-1025-and-recovery" "$boundary_1025"

boundary_1025_newline="$test_dir/string-1025-newline.cl"
{
    printf '"'
    head -c 1025 /dev/zero | tr '\0' D
    printf '\nclass'
} >"$boundary_1025_newline"

assert_file_matches_reference "string-length-1025-newline" "$boundary_1025_newline"

boundary_1026_eof="$test_dir/string-1026-eof.cl"
{
    printf '"'
    head -c 1026 /dev/zero | tr '\0' E
} >"$boundary_1026_eof"

assert_file_matches_reference "string-length-1026-eof" "$boundary_1026_eof"

escape_overflow_eof="$test_dir/escape-overflow-eof.cl"
{
    printf '"'
    head -c 1025 /dev/zero | tr '\0' F
    printf '\\0'
} >"$escape_overflow_eof"

assert_file_matches_reference "escape-after-length-1025-at-eof" "$escape_overflow_eof"

overlong_with_null="$test_dir/overlong-with-null.cl"
{
    printf '"'
    head -c 1025 /dev/zero | tr '\0' C
    printf '\0tail" class'
} >"$overlong_with_null"

assert_file_matches_reference "null-overrides-length-error" "$overlong_with_null"

printf 'All lexer regression tests passed.\n'
