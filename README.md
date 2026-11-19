# Duplicate File Name Finder

## Description

`duplicates.sh` recursively searches a directory for regular files with identical **file names**, regardless of their contents or locations. It prints each duplicate name, its number of occurrences, all matching paths, and a final summary.

Names are compared case-sensitively. Hidden files are included; symbolic links and special files are ignored. Output order is not specified.

**Requirements:** Linux and Bash 4 or newer.

## Usage

```bash
chmod +x duplicates.sh
./duplicates.sh DIRECTORY [EXTENSION]
```

`DIRECTORY` is the directory to search. Relative arguments produce relative paths; absolute arguments produce absolute paths. 

The optional `EXTENSION` must include the leading dot (e.g. `.c`). Without it, all regular files are considered.

### Example

```bash
./duplicates.sh ../bash-training .c
```

Possible output (path order may vary):

```text
Duplicate: main.c (2 files)
../bash-training/backup/main.c
../bash-training/src/main.c

Duplicate file names found: 1
```

If no duplicate names are found, the script prints `Duplicate file names found: 0`.

## Design

- **Associative arrays instead of a** `sort`**/**`uniq` **pipeline:** File names are used directly as keys. One array counts occurrences; the other collects the corresponding paths. This keeps duplicate detection in a straightforward loop.
- **Small, focused functions:** Argument validation, file collection, and output are separated so each step is easy to follow.
- **Shared arrays by design:** `counts` and `paths` are global because collection and output need the same data.
- **Controlled error handling:** `find` errors are collected in a temporary file and printed as warnings on `stderr`. `trap` cleans up the file on exit.

## Key Commands and Bash Constructs

- `find "$search_directory" -type f -print0` searches recursively for regular files. `-print0` separates paths with NUL characters so spaces and other special characters do not break the input.
- `while IFS= read -r -d '' file` processes one NUL-separated path at a time. `IFS=` preserves whitespace, `-r` preserves backslashes, and `-d ''` uses NUL as the delimiter.
- `< <(find ...)` (process substitution) keeps the `while` loop in the current shell, so the arrays remain populated after the loop.
- `${file##*/}` removes the directory portion of a path, leaving only the file name to compare.
- `declare -A counts paths` creates associative arrays indexed by file name: `counts` stores how often a name occurs, while `paths` stores its matching paths. A `for` loop and an `if` condition print only names with more than one occurrence.
- `printf` prints the formatted results and error messages. `>&2` sends errors to standard error instead of standard output.
- `mktemp` creates a temporary file for `find` error messages; `trap ... EXIT` removes it when the script exits. Unreadable subdirectories produce warnings, while the remaining search continues.

File names containing newline characters are not supported, because the collected paths are stored with newline separators.
