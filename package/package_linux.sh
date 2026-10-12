#!/bin/sh

# Packages Quantum Horizon on Linux, forwarding all arguments to the shared script.
set -eu
[ "$(uname -s)" = Linux ] || { printf 'ERROR: This launcher requires Linux.\n' >&2; exit 1; }
script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
exec sh "$script_dir/package_unix.sh" "$@"
