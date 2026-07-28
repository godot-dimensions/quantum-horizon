#!/bin/sh

# Builds Godot with the custom modules on macOS or Linux.

set -eu

target=editor
jobs=
dev_build=0
clean_build=0
do_not_run=0

usage() {
    printf 'Usage: %s [--target TARGET] [--jobs COUNT] [--dev] [--clean] [--do-not-run]\n' "$0"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target)
            [ "$#" -ge 2 ] || die "--target requires a value."
            target=$2
            shift 2
            ;;
        --jobs)
            [ "$#" -ge 2 ] || die "--jobs requires a value."
            jobs=$2
            shift 2
            ;;
        --dev)
            dev_build=1
            shift
            ;;
        --clean)
            clean_build=1
            shift
            ;;
        --do-not-run)
            do_not_run=1
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

case "$target" in
    *[!A-Za-z0-9_-]*|'')
        die "Target contains unsupported characters: $target"
        ;;
esac

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

if [ -z "$jobs" ]; then
    if command -v getconf >/dev/null 2>&1; then
        jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)
    fi
    if [ -z "$jobs" ] && command -v sysctl >/dev/null 2>&1; then
        jobs=$(sysctl -n hw.ncpu 2>/dev/null || true)
    fi
    [ -n "$jobs" ] || jobs=1
fi

case "$jobs" in
    *[!0-9]*|'') die "Jobs must be a positive integer." ;;
esac
[ "$jobs" -ge 1 ] || die "Jobs must be at least 1."

for dependency in git python3 scons; do
    command -v "$dependency" >/dev/null 2>&1 || die "Required command '$dependency' was not found in PATH."
done

if [ "$platform" = macos ]; then
    command -v xcrun >/dev/null 2>&1 || die "Xcode Command Line Tools were not found. Run: xcode-select --install"
    xcrun --find clang >/dev/null 2>&1 || die "Apple Clang was not found. Run: xcode-select --install"
    xcrun --show-sdk-path >/dev/null 2>&1 || die "The macOS SDK was not found. Repair or install Xcode Command Line Tools."
else
    command -v pkg-config >/dev/null 2>&1 || die "pkg-config was not found. Install the Godot Linux build dependencies."
    command -v cc >/dev/null 2>&1 || die "A C compiler was not found. Install GCC or Clang."
    command -v c++ >/dev/null 2>&1 || die "A C++ compiler was not found. Install G++ or Clang++."
fi

script_parent=$(dirname "$0")
script_dir=$(CDPATH= cd -P "$script_parent" && pwd)
engine_root=$(CDPATH= cd -P "$script_dir/.." && pwd)
engine_dir=$engine_root/godot
modules_dir=$engine_root/modules
cache_dir=$script_dir/.cache

[ -d "$engine_dir" ] || die "Engine directory not found: $engine_dir"
[ -d "$modules_dir" ] || die "Modules directory not found: $modules_dir"

dev_suffix=
dev_cache_name=standard
if [ "$dev_build" -eq 1 ]; then
    dev_suffix=.dev
    dev_cache_name=dev
fi

executable_path=$engine_dir/bin/godot.$platform.$target$dev_suffix.double.$architecture

printf '===============================================\n'
printf 'Godot Engine Build\n'
printf '===============================================\n'
printf 'Engine:       %s\n' "$engine_dir"
printf 'Modules:      %s\n' "$modules_dir"
printf 'Target:       %s\n' "$target"
printf 'Platform:     %s\n' "$platform"
printf 'Architecture: %s\n' "$architecture"
printf 'Jobs:         %s\n' "$jobs"

mkdir -p "$cache_dir"
state_file=$cache_dir/.build_state.$$
trap 'rm -f "$state_file"' 0 1 2 15

{
    printf '%s\n' \
        "compiledb=yes" \
        "warnings=all" \
        "werror=yes" \
        "precision=double" \
        "target=$target" \
        "platform=$platform" \
        "arch=$architecture" \
        "jobs=$jobs" \
        "custom_modules=../modules"
    if [ "$target" = editor ]; then
        printf '%s\n' "tests=yes"
    fi
    if [ "$dev_build" -eq 1 ]; then
        printf '%s\n' "debug_symbols=yes" "dev_build=yes" "dev_mode=yes"
    fi
} >"$state_file"

directory_checksum() {
    directory_path=$1
    file_list=$(mktemp "${TMPDIR:-/tmp}/quantum-horizon-files.XXXXXX") || return 1

    if ! git -C "$directory_path" ls-files -co --exclude-standard -- . >"$file_list"; then
        rm -f "$file_list"
        return 1
    fi
    LC_ALL=C sort -o "$file_list" "$file_list" || {
        rm -f "$file_list"
        return 1
    }

    while IFS= read -r relative_path; do
        [ -f "$directory_path/$relative_path" ] || continue
        printf '%s\n' "$relative_path"
        cksum <"$directory_path/$relative_path"
    done <"$file_list" | cksum
    checksum_status=$?
    rm -f "$file_list"
    return "$checksum_status"
}

cacheable=1
for repository_path in "$engine_dir" "$modules_dir"/*; do
    [ -d "$repository_path" ] || continue
    commit=
    changes=
    content_checksum=
    if [ -e "$repository_path/.git" ]; then
        commit=$(git -C "$repository_path" rev-parse HEAD) || die "Could not read Git revision for: $repository_path"
        changes=$(git -C "$repository_path" status --porcelain=v1 --untracked-files=all) ||
            die "Could not read Git status for: $repository_path"
    else
        content_checksum=$(directory_checksum "$repository_path") ||
            die "Could not calculate content checksum for: $repository_path"
    fi

    if [ -n "$changes" ]; then
        cacheable=0
    fi
    printf 'repository=%s\ncommit=%s\ncontent_checksum=%s\n' \
        "$repository_path" "$commit" "$content_checksum" >>"$state_file"
done

current_build_key=$(cksum <"$state_file")
cache_file=$cache_dir/build_cache_${platform}_${architecture}_${target}_${dev_cache_name}.txt
should_skip_build=0

if [ "$clean_build" -eq 0 ] && [ "$cacheable" -eq 1 ] && [ -f "$cache_file" ] && [ -x "$executable_path" ]; then
    cached_build_key=$(sed -n '1p' "$cache_file")
    if [ "$cached_build_key" = "$current_build_key" ]; then
        should_skip_build=1
    fi
fi

set -- \
    "compiledb=yes" \
    "warnings=all" \
    "werror=yes" \
    "precision=double" \
    "target=$target" \
    "platform=$platform" \
    "arch=$architecture"

if [ "$target" = editor ]; then
    set -- "$@" "tests=yes"
fi
set -- "$@" "-j$jobs" "custom_modules=../modules"
if [ "$dev_build" -eq 1 ]; then
    set -- "$@" "debug_symbols=yes" "dev_build=yes" "dev_mode=yes"
fi

if [ "$should_skip_build" -eq 0 ] && [ -e "$executable_path" ]; then
    rm -f "$executable_path" ||
        die "Could not remove the existing Godot executable: $executable_path. You must close Godot before re-running the build script."
fi

if [ "$clean_build" -eq 1 ]; then
    printf '\nCleaning this build configuration...\n'
    (
        cd "$engine_dir"
        scons "$@" --clean
    )
fi

if [ "$should_skip_build" -eq 1 ]; then
    printf '\n[SKIP] Sources and build options have not changed.\n'
    printf 'Using: %s\n' "$executable_path"
else
    if [ "$cacheable" -eq 0 ]; then
        printf '\nUncommitted source changes detected; the build cache will not be used.\n'
    fi

    printf '\nStarting build...\n'
    (
        cd "$engine_dir"
        scons "$@"
    )

    [ -x "$executable_path" ] || die "The build finished, but the expected executable was not found: $executable_path"

    if [ "$cacheable" -eq 1 ]; then
        cache_tmp=${cache_file}.tmp.$$
        {
            printf '%s\n' "$current_build_key"
            date -u '+%Y-%m-%dT%H:%M:%SZ'
        } >"$cache_tmp"
        mv "$cache_tmp" "$cache_file"
    fi
fi

rm -f "$state_file"
trap - 0 1 2 15

[ -x "$executable_path" ] || die "Godot executable not found: $executable_path"

printf '\n===============================================\n'
printf 'Engine is ready.\n'
printf '===============================================\n'

if [ "$do_not_run" -eq 0 ]; then
    printf 'Running: %s\n' "$executable_path"
    "$executable_path" --project-manager
fi
