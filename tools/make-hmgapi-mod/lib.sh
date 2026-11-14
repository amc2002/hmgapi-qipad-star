# Shared helpers for the qipad-star HMG-API mod's build and test scripts. Sourced, not run.

# native_path <path>: the path in the form a native program (java, python) takes.
# Under Git Bash on Windows that is a Windows path; elsewhere the path is unchanged.
native_path() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s\n' "$1"; fi
}

# find_python: prints the name of a working Python 3 (python or python3); fails if there is none.
# (On Windows "python3" can be a Store placeholder that only prints a hint, so each is tried.)
find_python() {
    for c in python python3; do
        if "$c" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
            echo "$c"
            return 0
        fi
    done
    return 1
}
