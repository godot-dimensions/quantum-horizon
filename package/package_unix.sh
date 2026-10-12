#!/bin/sh

# Builds ../engine/ and exports ../project/ using its existing export presets.
# Close the project editor before packaging; the presets are temporarily modified.
set -eu

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s [--debug] [--dev] [--platform macos|linuxbsd] [--architecture ARCH] [--jobs COUNT] [--clean]\n' "$0"
    printf 'Defaults: release, host platform and architecture; macOS is always universal.\n'
    printf -- '--dev implies --debug and enables engine development checks and debug symbols.\n'
    printf 'Outputs package/bin/quantum-horizon-PLATFORM-ARCH-MODE.zip.\n'
}

mode=release
dev_build=0
requested_platform=
requested_architecture=
jobs=
clean_build=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --debug) mode=debug; shift ;;
        --dev) mode=debug; dev_build=1; shift ;;
        --platform|--os)
            [ "$#" -ge 2 ] || die "$1 requires a value."
            requested_platform=$2; shift 2 ;;
        --architecture|--arch)
            [ "$#" -ge 2 ] || die "$1 requires a value."
            requested_architecture=$2; shift 2 ;;
        --jobs)
            [ "$#" -ge 2 ] || die "--jobs requires a value."
            jobs=$2; shift 2 ;;
        --clean) clean_build=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

case "$(uname -s)" in
    Darwin) platform=macos; export_platform=macOS ;;
    Linux) platform=linuxbsd; export_platform=Linux ;;
    *) die "This script requires macOS or Linux." ;;
esac
case "$(uname -m)" in
    x86_64|amd64) host_architecture=x86_64 ;;
    i386|i486|i586|i686) host_architecture=x86_32 ;;
    arm64|aarch64) host_architecture=arm64 ;;
    armv6*|armv7*) host_architecture=arm32 ;;
    riscv64) host_architecture=rv64 ;;
    ppc64|ppc64le) host_architecture=ppc64 ;;
    loongarch64) host_architecture=loongarch64 ;;
    *) die "Unsupported host architecture: $(uname -m)" ;;
esac
[ -z "$requested_platform" ] || [ "$requested_platform" = "$platform" ] ||
    die "Building $requested_platform on $platform is not supported by the Unix build script."
architecture=${requested_architecture:-$host_architecture}
if [ "$platform" = macos ]; then
    [ -z "$requested_architecture" ] || [ "$requested_architecture" = universal ] ||
        die "macOS packages are always universal; omit --architecture or use universal."
    architecture=universal
fi
case "$platform:$architecture" in
    macos:universal|linuxbsd:x86_64|linuxbsd:x86_32|linuxbsd:arm64|linuxbsd:arm32|linuxbsd:rv64|linuxbsd:ppc64|linuxbsd:loongarch64) ;;
    *) die "Unsupported $platform architecture: $architecture" ;;
esac
if [ -n "$jobs" ]; then
    case "$jobs" in *[!0-9]*) die "Jobs must be a positive integer." ;; esac
    [ "$jobs" -ge 1 ] || die "Jobs must be at least 1."
fi
command -v python3 >/dev/null 2>&1 || die "python3 was not found in PATH."
if [ "$platform" = macos ]; then
    for dependency in lipo ditto; do
        command -v "$dependency" >/dev/null 2>&1 || die "Required command '$dependency' was not found in PATH."
    done
fi

script_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
engine_root=$(CDPATH= cd -P "$script_dir/../engine" && pwd)
project_dir=$(CDPATH= cd -P "$script_dir/../project" && pwd)
build_script=$engine_root/scripts/build_engine_unix.sh
bin_dir=$engine_root/godot/bin
preset_path=$project_dir/export_presets.cfg
for required_file in "$build_script" "$project_dir/project.godot" "$preset_path"; do
    [ -f "$required_file" ] || die "Required file not found: $required_file"
done
output_dir=$script_dir/bin
dev_suffix=
package_mode=$mode
if [ "$dev_build" -eq 1 ]; then
    dev_suffix=.dev
    package_mode=dev
fi
output_name=quantum-horizon-$platform-$architecture-$package_mode.zip
mkdir -p "$output_dir" "$script_dir/.cache"
temporary_dir=$(mktemp -d "$script_dir/.cache/package.XXXXXX")
backup_path=$project_dir/export_presets.cfg.package-backup.tmp
preset_locked=0
preset_backed_up=0

cleanup() {
    exit_code=$?
    trap - 0
    if [ "$preset_backed_up" -eq 1 ]; then
        if ! cp "$backup_path" "$preset_path"; then
            printf 'ERROR: Could not restore presets. Recover them from: %s\n' "$backup_path" >&2
            exit 1
        fi
    fi
    if [ "$preset_locked" -eq 1 ]; then rm -f "$backup_path"; fi
    # Only remove the private staging directory created by mktemp above.
    case "$temporary_dir" in
        "$script_dir/.cache/package."*) rm -rf "$temporary_dir" ;;
        *) printf 'ERROR: Unexpected staging path: %s\n' "$temporary_dir" >&2; exit 1 ;;
    esac
    exit "$exit_code"
}
trap cleanup 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15

build_engine() {
    set -- --target "$1" --architecture "$2" --do-not-run
    if [ -n "$jobs" ]; then set -- "$@" --jobs "$jobs"; fi
    if [ "$clean_build" -eq 1 ]; then set -- "$@" --clean; fi
    if [ "$dev_build" -eq 1 ]; then set -- "$@" --dev; fi
    sh "$build_script" "$@"
}

target=template_$mode
printf 'Building %s %s %s template...\n' "$platform" "$architecture" "$package_mode"
if [ "$platform" = macos ]; then
    build_engine "$target" x86_64
    build_engine "$target" arm64
    template_app=$temporary_dir/macos_template.app
    cp -R "$engine_root/godot/misc/dist/macos_template.app" "$template_app"
    mkdir -p "$template_app/Contents/MacOS"
    universal_binary=$template_app/Contents/MacOS/godot_macos_$mode.universal
    lipo -create "$bin_dir/godot.macos.$target$dev_suffix.double.x86_64" "$bin_dir/godot.macos.$target$dev_suffix.double.arm64" -output "$universal_binary"
    lipo "$universal_binary" -verify_arch x86_64 arm64
    chmod +x "$universal_binary"
    template_path=$temporary_dir/macos-template.zip
    ditto -c -k --keepParent "$template_app" "$template_path"
else
    build_engine "$target" "$architecture"
    template_path=$bin_dir/godot.$platform.$target$dev_suffix.double.$architecture
fi
[ -s "$template_path" ] || die "Built template not found or empty: $template_path"
editor_path=$bin_dir/godot.$platform.editor$dev_suffix.double.$host_architecture
if [ ! -x "$editor_path" ]; then build_engine editor "$host_architecture"; fi
[ -x "$editor_path" ] || die "Godot editor not found: $editor_path"

# The backup doubles as an exclusive lock, matching the Windows packaging script.
(set -C; : > "$backup_path") 2>/dev/null || die "Preset backup already exists: $backup_path"
preset_locked=1
cp "$preset_path" "$backup_path"
preset_backed_up=1
preset_name=$(python3 - "$preset_path" "$export_platform" "$architecture" "$mode" "$template_path" <<'PY'
import json
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
platform, architecture, mode, template = sys.argv[2:]
config = path.read_bytes().decode("utf-8-sig")
sections = re.finditer(r"(?ms)^\[preset\.(\d+)\]\r?\n(.*?)(?=^\[|\Z)", config)
section = next((s for s in sections if re.search(r"(?m)^platform=" + re.escape(json.dumps(platform)) + r"\r?$", s[2])), None)
if section is None:
    sys.exit(f"Export preset for {platform} not found in: {path}")
name = re.search(r'(?m)^name=(".*")\r?$', section[2])
options = re.search(r"(?ms)^\[preset\." + section[1] + r"\.options\]\r?\n(.*?)(?=^\[|\Z)", config)
if name is None or options is None:
    sys.exit(f"Export preset name or options missing in: {path}")
updated = options[1]
overrides = {"custom_template/debug": "", "custom_template/release": "", "binary_format/architecture": architecture}
overrides[f"custom_template/{mode}"] = template
for key, value in overrides.items():
    pattern = r"(?m)^" + re.escape(key) + r"=[^\r\n]*"
    if not re.search(pattern, updated):
        sys.exit(f"Export option '{key}' missing in: {path}")
    updated = re.sub(pattern, lambda _: key + "=" + json.dumps(value, ensure_ascii=False), updated)
path.write_bytes((config[:options.start(1)] + updated + config[options.end(1):]).encode("utf-8"))
print(json.loads(name[1]))
PY
)
printf 'Importing project resources...\n'
"$editor_path" --headless --path "$project_dir" --import
printf 'Exporting %s package...\n' "$package_mode"
temporary_output=$temporary_dir/$output_name
"$editor_path" --headless --path "$project_dir" "--export-$mode" "$preset_name" "$temporary_output"
[ -s "$temporary_output" ] || die "Export did not produce a nonempty ZIP: $temporary_output"
mv -f "$temporary_output" "$output_dir/$output_name"
printf 'Package ready: %s\n' "$output_dir/$output_name"
