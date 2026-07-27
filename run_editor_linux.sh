#!/bin/sh

# Run this file to update, build, and open Quantum Horizon on Linux.

set -u

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[ "$(uname -s)" = Linux ] || die "This launcher requires Linux."

for dependency in git python3 scons pkg-config cc c++; do
    command -v "$dependency" >/dev/null 2>&1 ||
        die "Required command '$dependency' was not found. Install the Godot Linux build dependencies."
done

script_parent=$(dirname "$0")
script_dir=$(CDPATH= cd -P "$script_parent" && pwd)
project_path=$script_dir/project/project.godot
launcher_path=$script_dir/engine/scripts/run_editor_unix.sh

[ -f "$project_path" ] || die "Godot project not found: $project_path"
[ -f "$launcher_path" ] || die "Unix launcher not found: $launcher_path"

"$launcher_path" --project-path "$project_path"
