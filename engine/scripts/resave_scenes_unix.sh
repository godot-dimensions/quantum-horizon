#!/bin/sh

# Opens and re-saves every text scene through the Godot editor.

set -eu

project_path=
dev_build=0

usage() {
    printf 'Usage: %s --project-path PATH [--dev]\n' "$0"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --project-path)
            [ "$#" -ge 2 ] || die "--project-path requires a value."
            project_path=$2
            shift 2
            ;;
        --dev)
            dev_build=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown argument: $1"
            ;;
    esac
done

[ -n "$project_path" ] || die "--project-path is required."

os_name=$(uname -s)
machine_arch=$(uname -m)

case "$os_name" in
    Darwin)
        platform=macos
        case "$machine_arch" in
            arm64|aarch64) architecture=arm64 ;;
            x86_64|amd64) architecture=x86_64 ;;
            *) die "Unsupported macOS architecture: $machine_arch" ;;
        esac
        ;;
    Linux)
        platform=linuxbsd
        case "$machine_arch" in
            x86_64|amd64) architecture=x86_64 ;;
            arm64|aarch64) architecture=arm64 ;;
            riscv64) architecture=rv64 ;;
            *) die "Unsupported Linux architecture: $machine_arch" ;;
        esac
        ;;
    *)
        die "This script supports macOS and Linux only. Detected: $os_name"
        ;;
esac

script_parent=$(dirname "$0")
script_dir=$(CDPATH= cd -P "$script_parent" && pwd)
engine_root=$(CDPATH= cd -P "$script_dir/.." && pwd)
resave_script=$script_dir/resave_scenes.gd

[ -e "$project_path" ] || die "Godot project not found: $project_path"
if [ -d "$project_path" ]; then
    resolved_project_directory=$(CDPATH= cd -P "$project_path" && pwd)
    project_file=$resolved_project_directory/project.godot
else
    [ "$(basename "$project_path")" = project.godot ] ||
        die "Project path must be a project directory or a project.godot file: $project_path"
    project_directory=$(dirname "$project_path")
    resolved_project_directory=$(CDPATH= cd -P "$project_directory" && pwd)
    project_file=$resolved_project_directory/project.godot
fi

[ -f "$project_file" ] || die "project.godot not found: $project_file"
[ -f "$resave_script" ] || die "Scene re-save script not found: $resave_script"

if [ "$dev_build" -eq 1 ]; then
    dev_suffix=.dev
else
    dev_suffix=
fi

executable_relative_path=./bin/godot.$platform.editor$dev_suffix.double.$architecture
executable_path=$engine_root/godot/bin/godot.$platform.editor$dev_suffix.double.$architecture
[ -x "$executable_path" ] ||
    die "Godot editor executable not found: $executable_path. Run the platform's run_editor script first to build the engine."

printf '===============================================\n'
printf 'Quantum Horizon Scene Re-saver\n'
printf '===============================================\n'
printf 'Project: %s\n' "$resolved_project_directory"
printf 'Editor:  %s\n' "$executable_path"

resave_exit_code=0
(
    cd "$engine_root/godot"
    "$executable_relative_path" --headless --editor \
        --path "$resolved_project_directory" --script "$resave_script"
) || resave_exit_code=$?

[ "$resave_exit_code" -eq 0 ] ||
    die "Godot scene re-save failed with exit code $resave_exit_code."

printf '[OK] All project scenes were re-saved.\n'
