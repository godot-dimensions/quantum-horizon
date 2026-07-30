#!/bin/sh

# Updates dependencies, builds Godot, and opens the Quantum Horizon project.

set -eu

project_path=
dev_build=0
do_not_update=0
skip_ide_setup=0

usage() {
    printf 'Usage: %s [--project-path PATH] [--dev] [--do-not-update] [--skip-ide-setup]\n' "$0"
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
        --do-not-update)
            do_not_update=1
            shift
            ;;
        --skip-ide-setup)
            skip_ide_setup=1
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
            i386|i486|i586|i686) architecture=x86_32 ;;
            arm64|aarch64) architecture=arm64 ;;
            armv6*|armv7*) architecture=arm32 ;;
            riscv64) architecture=rv64 ;;
            ppc64|ppc64le) architecture=ppc64 ;;
            loongarch64) architecture=loongarch64 ;;
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
update_script=$script_dir/update_submodules_unix.sh
vscode_setup_script=$script_dir/setup_vscode_unix.sh
build_script=$script_dir/build_engine_unix.sh

[ -f "$update_script" ] || die "Update script not found: $update_script"
[ -f "$build_script" ] || die "Build script not found: $build_script"
if [ "$skip_ide_setup" -eq 0 ]; then
    [ -f "$vscode_setup_script" ] || die "VS Code setup script not found: $vscode_setup_script"
fi

resolved_project_directory=
if [ -n "$project_path" ]; then
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
fi

printf '===============================================\n'
printf 'Quantum Horizon Editor Launcher\n'
printf '===============================================\n'

if [ "$do_not_update" -eq 0 ]; then
    printf '\nStep 1 of 4: Checking for engine updates...\n'
    "$update_script"
else
    printf '\nStep 1 of 4: Update skipped.\n'
fi

printf '\nStep 2 of 4: Making sure the engine is built...\n'
if [ "$dev_build" -eq 1 ]; then
    "$build_script" --dev --do-not-run
    dev_suffix=.dev
else
    "$build_script" --do-not-run
    dev_suffix=
fi

if [ "$skip_ide_setup" -eq 1 ]; then
    printf '\nStep 3 of 4: IDE setup skipped.\n'
else
    printf '\nStep 3 of 4: Setting up VS Code IntelliSense...\n'
    # Metadata-only SCons runs overwrite this with their much smaller node count,
    # which would make the next real build report 100% progress almost immediately.
    node_count_file=$engine_root/godot/.scons_node_count
    node_count_existed=0
    node_count=
    if [ -f "$node_count_file" ]; then
        node_count=$(sed -n '1p' "$node_count_file")
        node_count_existed=1
    fi

    setup_exit_code=0
    "$vscode_setup_script" || setup_exit_code=$?

    if [ "$node_count_existed" -eq 1 ]; then
        printf '%s\n' "$node_count" >"$node_count_file"
    else
        rm -f "$node_count_file"
    fi

    [ "$setup_exit_code" -eq 0 ] || exit "$setup_exit_code"
fi

printf '\nStep 4 of 4: Opening the editor...\n'
executable_path=$engine_root/godot/bin/godot.$platform.editor$dev_suffix.double.$architecture

[ -x "$executable_path" ] || die "Godot executable not found: $executable_path"
printf 'Running: %s\n' "$executable_path"

if [ -n "$resolved_project_directory" ]; then
    printf 'Project: %s\n' "$resolved_project_directory"
    "$executable_path" --path "$resolved_project_directory" --editor
else
    printf 'Opening the project manager.\n'
    "$executable_path" --project-manager
fi
