#!/bin/sh

# Generates repository-root VS Code IntelliSense configuration for the engine and custom modules.

set -eu

force=0
script_version=2

usage() {
    printf 'Usage: %s [--force]\n' "$0"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --force)
            force=1
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

for dependency in git python3 scons cksum; do
    command -v "$dependency" >/dev/null 2>&1 ||
        die "Required command '$dependency' was not found in PATH."
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
repository_root=$(CDPATH= cd -P "$engine_root/.." && pwd)
engine_dir=$engine_root/godot
modules_dir=$engine_root/modules
cache_dir=$script_dir/.cache
vscode_dir=$repository_root/.vscode
compile_commands_file=$engine_dir/compile_commands.json
cpp_properties_file=$vscode_dir/c_cpp_properties.json
settings_file=$vscode_dir/settings.json
extensions_file=$vscode_dir/extensions.json
state_file=$vscode_dir/quantum_horizon_vscode.state

[ -d "$engine_dir" ] || die "Engine directory not found: $engine_dir"
[ -d "$modules_dir" ] || die "Modules directory not found: $modules_dir"

mkdir -p "$cache_dir"
signature_input=$cache_dir/.vscode_signature.$$
trap 'rm -f "$signature_input"' 0 1 2 15

{
    printf 'schema=%s\n' "$script_version"
    printf 'platform=%s\n' "$platform"
    printf 'target=editor\n'
    printf 'arch=%s\n' "$architecture"
    printf 'precision=double\n'
    printf 'custom_modules=../modules\n'
} >"$signature_input"

for repository_path in "$engine_dir" "$modules_dir"/*; do
    [ -d "$repository_path" ] || continue

    repository_path=$(CDPATH= cd -P "$repository_path" && pwd)
    printf 'repository=%s\n' "$repository_path" >>"$signature_input"

    printf 'commit=%s\n' "$(git -C "$repository_path" rev-parse HEAD)" >>"$signature_input"

    git -C "$repository_path" status --porcelain=v1 --untracked-files=all -- . |
        grep -E '\.(c|cc|cpp|cxx|m|mm|h|hh|hpp|hxx|inc)$|(^|/)(SConstruct|SCsub|config\.py)$' |
        sed 's/^/status=/' >>"$signature_input" || true

    git -C "$repository_path" ls-files -co --exclude-standard -- . |
        LC_ALL=C sort -u |
        while IFS= read -r relative_path; do
            case "$relative_path" in
                *.c|*.cc|*.cpp|*.cxx|*.m|*.mm)
                    printf 'source=%s\n' "$relative_path" >>"$signature_input"
                    ;;
                *.h|*.hh|*.hpp|*.hxx|*.inc)
                    printf 'header=%s\n' "$relative_path" >>"$signature_input"
                    ;;
            esac

            case "$relative_path" in
                SConstruct|SCsub|config.py|*/SConstruct|*/SCsub|*/config.py)
                    if [ -f "$repository_path/$relative_path" ]; then
                        checksum=$(cksum "$repository_path/$relative_path")
                        printf 'build-file=%s:%s\n' "$relative_path" "$checksum" >>"$signature_input"
                    fi
                    ;;
            esac
        done
done

current_signature=$(cksum <"$signature_input")
is_current=0
if [ "$force" -eq 0 ] &&
    [ -f "$state_file" ] &&
    [ -f "$cpp_properties_file" ] &&
    [ -f "$settings_file" ] &&
    [ -f "$extensions_file" ] &&
    [ -f "$compile_commands_file" ] &&
    grep -Eq 'modules/4d/' "$compile_commands_file" &&
    grep -Eq 'modules/quantum_horizon/' "$compile_commands_file"; then
    saved_signature=$(sed -n '1p' "$state_file")
    if [ "$saved_signature" = "$current_signature" ]; then
        is_current=1
    fi
fi

if [ "$is_current" -eq 1 ]; then
    printf '[SKIP] VS Code IntelliSense is already configured.\n'
    rm -f "$signature_input"
    trap - 0 1 2 15
    exit 0
fi

printf 'Generating VS Code IntelliSense metadata...\n'
(
    cd "$engine_dir"
    scons \
        compiledb=yes \
        warnings=all \
        werror=yes \
        precision=double \
        target=editor \
        platform="$platform" \
        arch="$architecture" \
        tests=yes \
        custom_modules=../modules \
        compile_commands.json
)

[ -f "$compile_commands_file" ] ||
    die "Compilation database was not generated: $compile_commands_file"
grep -Eq 'modules/4d/' "$compile_commands_file" ||
    die "The generated compilation database does not contain the 4D module: $compile_commands_file"
grep -Eq 'modules/quantum_horizon/' "$compile_commands_file" ||
    die "The generated compilation database does not contain the Quantum Horizon module: $compile_commands_file"

mkdir -p "$vscode_dir"
python3 - "$vscode_dir" <<'PYTHON'
import json
import os
import sys

vscode_dir = sys.argv[1]
compile_commands = "${workspaceFolder}/engine/godot/compile_commands.json"


def read_json_map(path):
    if not os.path.isfile(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as file:
            value = json.load(file)
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Could not parse '{path}'. The generated VS Code files must contain valid JSON.\n{error}")
    if not isinstance(value, dict):
        raise SystemExit(f"Expected a JSON object in '{path}'.")
    return value


def write_json(path, value):
    temporary_path = path + ".tmp"
    with open(temporary_path, "w", encoding="utf-8", newline="\n") as file:
        json.dump(value, file, indent=4)
        file.write("\n")
    os.replace(temporary_path, path)


write_json(
    os.path.join(vscode_dir, "c_cpp_properties.json"),
    {
        "configurations": [
            {
                "name": "Quantum Horizon",
                "compileCommands": compile_commands,
            }
        ],
        "version": 4,
    },
)

settings_path = os.path.join(vscode_dir, "settings.json")
settings = read_json_map(settings_path)
settings["C_Cpp.default.compileCommands"] = compile_commands
clangd_arguments = settings.get("clangd.arguments", [])
if not isinstance(clangd_arguments, list):
    clangd_arguments = []
clangd_arguments = [
    argument
    for argument in clangd_arguments
    if not str(argument).startswith("--compile-commands-dir=")
]
clangd_arguments.append("--compile-commands-dir=${workspaceFolder}/engine/godot")
settings["clangd.arguments"] = clangd_arguments
write_json(settings_path, settings)

extensions_path = os.path.join(vscode_dir, "extensions.json")
extensions = read_json_map(extensions_path)
recommendations = extensions.get("recommendations", [])
if not isinstance(recommendations, list):
    recommendations = []
recommendations.append("ms-vscode.cpptools")
extensions["recommendations"] = sorted(set(recommendations))
write_json(extensions_path, extensions)
PYTHON

printf '%s\n' "$current_signature" >"$state_file"

rm -f "$signature_input"
trap - 0 1 2 15

printf '[OK] VS Code IntelliSense is configured for the engine and custom modules.\n'
printf 'Compilation database: %s\n' "$compile_commands_file"
