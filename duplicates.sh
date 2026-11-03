#!/usr/bin/env bash

# Validate command-line arguments
check_arguments() {
  if (($# < 1 || $# > 2)); then
    printf 'Error: Expected 1 or 2 arguments.\n' >&2
    return 1
  fi

  if [[ ! -d "$1" ]]; then
    printf 'Error: Invalid directory: %s\n' "$1" >&2
    return 2
  fi
}

# Search for regular files and collect their paths
search_files() {
  local file name

  while IFS= read -r -d '' file; do
    if [[ "$directory" == -* ]]; then
      file="${file#./}"
    fi

    name="${file##*/}"

    # Apply optional extension filter
    if [[ -n "$extension" && "$name" != *"$extension" ]]; then
      continue
    fi

    ((counts["$name"]++))
    paths["$name"]+="$file"$'\n'
  done < <(find "$search_directory" -type f -print0 2>"$error_file")
}

# Print duplicate groups and summary
print_duplicates() {
  local name
  local duplicate_count=0

  for name in "${!counts[@]}"; do
    if ((counts["$name"] > 1)); then
      printf 'Duplicate: %s (%d files)\n' "$name" "${counts[$name]}"
      printf '%s' "${paths[$name]}"
      printf '\n'
      ((duplicate_count++))
    fi
  done

  if ((duplicate_count > 0)); then
    printf '\n'
  fi

  printf 'Duplicate file names found: %d\n' "$duplicate_count"
}

# Main
check_arguments "$@" || exit $?

directory="$1"
extension="${2:-}"
search_directory="$directory"

# Prevent find from interpreting a leading dash as an option
if [[ "$search_directory" == -* ]]; then
  search_directory="./$search_directory"
fi

declare -A counts paths

error_file=$(mktemp) || exit 1
trap 'rm -f -- "$error_file"' EXIT

search_files

# Report unreadable directories and other find errors
while IFS= read -r error; do
  printf 'Warning: %s\n' "$error" >&2
done <"$error_file"

print_duplicates

exit 0
