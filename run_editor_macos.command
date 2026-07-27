#!/bin/sh

# Double-click this file to update, build, and open Quantum Horizon on macOS.

set -u

die_and_wait() {
    printf '\nERROR: %s\n' "$*" >&2
    printf 'Press Return to close this window...'
    read ignored
    exit 1
}

[ "$(uname -s)" = Darwin ] || die_and_wait "This launcher requires macOS."

for dependency in git python3 scons xcrun; do
    command -v "$dependency" >/dev/null 2>&1 ||
        die_and_wait "Required command '$dependency' was not found."
done

xcrun --find clang >/dev/null 2>&1 ||
    die_and_wait "Xcode Command Line Tools are missing. Run: xcode-select --install"

script_parent=$(dirname "$0")
script_dir=$(CDPATH= cd -P "$script_parent" && pwd)
project_path=$script_dir/project/project.godot
launcher_path=$script_dir/engine/scripts/run_editor_unix.sh

[ -f "$project_path" ] || die_and_wait "Godot project not found: $project_path"
[ -f "$launcher_path" ] || die_and_wait "Unix launcher not found: $launcher_path"

"$launcher_path" --project-path "$project_path"
exit_code=$?

if [ "$exit_code" -ne 0 ]; then
    printf '\nQuantum Horizon could not be opened. Review the error above.\n' >&2
    printf 'Press Return to close this window...'
    read ignored
fi

exit "$exit_code"
