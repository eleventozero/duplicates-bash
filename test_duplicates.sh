#!/usr/bin/env bash
# Regression tests for duplicates.sh
# Run: ./test_duplicates.sh

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$script_dir/duplicates.sh"

if [[ ! -x "$script" ]]; then
  printf 'Error: %s is missing or not executable.\n' "$script" >&2
  exit 1
fi

test_dir=$(mktemp -d) || exit 1
base="$test_dir/tree with spaces"
stdout_file="$test_dir/stdout.txt"
stderr_file="$test_dir/stderr.txt"
trap 'chmod 700 -- "$base/restricted" 2>/dev/null; rm -rf -- "$test_dir"' EXIT

passed=0
failed=0

check() {
  local label=$1
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
    ((passed += 1))
  else
    printf 'FAIL  %s\n' "$label"
    ((failed += 1))
  fi
}

run() {
  "$script" "$@" >"$stdout_file" 2>"$stderr_file"
  status=$?
}

has_no_match() { ! grep -Fq -- "$1" "$2"; }
file_is_empty() { [[ ! -s "$1" ]]; }
stdout_equals() { [[ $(<"$stdout_file") == "$1" ]]; }
summary_has_blank_line() {
  [[ $(tail -n 2 "$stdout_file") == $'\n'"Duplicate file names found: $1" ]]
}

mkdir -p -- "$base/src/nested/deeper" "$base/backup" \
  "$base/docs" "$base/empty" "$base/unique-only" "$base/restricted"

# Three matches with different contents: only names must be compared.
printf 'first\n' >"$base/src/config.txt"
printf 'second\n' >"$base/backup/config.txt"
printf 'third\n' >"$base/src/nested/deeper/config.txt"

# Common and unusual duplicate file names.
for name in 'main.c' '.hidden' 'space name.txt' '-dash.txt' \
  'a*b?.txt' 'file[1].txt' "it's.txt" 'two  spaces.txt' 'back\slash.txt'; do
  touch -- "$base/src/$name" "$base/backup/$name"
done

# Names differing only in case, as well as single-occurrence names.
touch -- "$base/src/Case.txt" "$base/backup/case.txt"
touch -- "$base/docs/README.md" "$base/unique-only/one.txt" \
  "$base/unique-only/two.c"

# These must not be counted as regular files.
ln -s -- ../src/config.txt "$base/backup/link-only.txt"
ln -s -- ../backup "$base/src/link-to-backup"
mkfifo -- "$base/src/pipe-test" "$base/backup/pipe-test"

printf '\n=== Duplicate detection and unusual names ===\n'
run "$base"
check 'Successful search exits with 0' test "$status" -eq 0
check 'Exactly 10 duplicate groups' grep -Fqx -- \
  'Duplicate file names found: 10' "$stdout_file"
check 'Three config.txt occurrences' grep -Fqx -- \
  'Duplicate: config.txt (3 files)' "$stdout_file"
check 'Blank line before nonempty summary' summary_has_blank_line 10
for path in "$base/src/config.txt" "$base/backup/config.txt" \
  "$base/src/nested/deeper/config.txt"; do
  check "Full path: ${path##*/} (${path%/*})" grep -Fqx -- "$path" "$stdout_file"
done
for name in '.hidden' 'space name.txt' '-dash.txt' 'a*b?.txt' \
  'file[1].txt' "it's.txt" 'two  spaces.txt' 'back\slash.txt'; do
  check "Special name: $name" grep -Fqx -- \
    "Duplicate: $name (2 files)" "$stdout_file"
done
check 'Case-sensitive names are not duplicates' has_no_match 'Duplicate: Case.txt' "$stdout_file"
check 'Symlinks are ignored' has_no_match 'link-only.txt' "$stdout_file"
check 'Symlink directories are not traversed' has_no_match 'link-to-backup/' "$stdout_file"
check 'Named pipes are ignored' has_no_match 'pipe-test' "$stdout_file"
check 'No unexpected warnings' file_is_empty "$stderr_file"

printf '\n=== Extension filter and empty results ===\n'
run "$base" .c
check 'Only one .c duplicate group' grep -Fqx -- \
  'Duplicate file names found: 1' "$stdout_file"

