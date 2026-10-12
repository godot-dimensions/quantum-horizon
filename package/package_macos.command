#!/bin/sh

# Double-click to package Quantum Horizon for both Intel and Apple Silicon Macs.
set -u
script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd) || exit 1
if [ "$(uname -s)" != Darwin ]; then
    printf 'ERROR: This launcher requires macOS.\n' >&2
    exit 1
fi
sh "$script_dir/package_unix.sh" "$@"
exit_code=$?
if [ "$exit_code" -ne 0 ] && [ -t 0 ]; then
    printf '\nPackaging failed. Press Return to close this window...'
    read -r ignored
fi
exit "$exit_code"
