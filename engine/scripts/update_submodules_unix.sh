#!/bin/sh

# Updates the Godot engine and custom-module repositories on macOS or Linux.

set -eu

godot_version=4.5

usage() {
    printf 'Usage: %s [--godot-version VERSION]\n' "$0"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --godot-version)
            [ "$#" -ge 2 ] || die "--godot-version requires a value."
            godot_version=$2
            shift 2
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

command -v git >/dev/null 2>&1 || die "Git was not found. Install Git and make sure 'git' is available in PATH."

script_parent=$(dirname "$0")
script_dir=$(CDPATH= cd -P "$script_parent" && pwd)
host_repo_path=$(CDPATH= cd -P "$script_dir/../.." && pwd)
engine_repo_path=$script_dir/../godot
modules_dir=$script_dir/../modules
cache_dir=$script_dir/.cache
update_cache_file=$cache_dir/update_cache_unix.json

[ -e "$host_repo_path/.git" ] || die "Host Git repository not found: $host_repo_path"
[ -e "$engine_repo_path" ] || die "Engine repository not found: $engine_repo_path"
[ -d "$modules_dir" ] || die "Modules directory not found: $modules_dir"

repository_changed=0

update_repository() {
    repo_path=$1
    default_branch=$2

    repo_path=$(CDPATH= cd -P "$repo_path" && pwd)
    printf '===== Updating: %s =====\n' "$repo_path"

    if [ ! -e "$repo_path/.git" ]; then
        case "$repo_path" in
            "$host_repo_path"/*)
                submodule_path=${repo_path#"$host_repo_path"/}
                printf '  Missing .git metadata. Attempting to initialize host submodule: %s\n' "$submodule_path"
                git -C "$host_repo_path" submodule update --init --recursive -- "$submodule_path"
                ;;
        esac
    fi

    if [ ! -e "$repo_path/.git" ]; then
        printf '  No Git repository metadata found; skipping parent-tracked directory.\n\n'
        return 0
    fi

    if ! status_output=$(git -C "$repo_path" status --porcelain=v1 --untracked-files=all); then
        die "Could not read Git status for: $repo_path"
    fi
    if [ -n "$status_output" ]; then
        printf 'Repository has uncommitted changes. Commit or discard them before updating:\n%s\n' "$status_output" >&2
        exit 1
    fi
    printf '  Working tree is clean.\n'

    printf '  Checking for updates...\n'
    if ! git -C "$repo_path" fetch --all --prune; then
        printf 'WARNING: Could not contact the remote. Cached remote information will be used.\n' >&2
    fi

    if ! current_branch=$(git -C "$repo_path" symbolic-ref --quiet --short HEAD 2>/dev/null); then
        current_branch=
    fi

    switch_branch=$default_branch
    remote_ref=origin/$default_branch

    if [ -n "$current_branch" ]; then
        if upstream_name=$(git -C "$repo_path" rev-parse --abbrev-ref "${current_branch}@{upstream}" 2>/dev/null); then
            if [ -n "$upstream_name" ]; then
                switch_branch=$current_branch
                remote_ref=$upstream_name
                printf '  Using tracked branch: %s -> %s\n' "$switch_branch" "$remote_ref"
            fi
        fi
    fi

    if ! remote_commit=$(git -C "$repo_path" rev-parse --verify "${remote_ref}^{commit}" 2>/dev/null); then
        die "Remote branch '$remote_ref' is unavailable. Connect to the internet and try again."
    fi

    snapshot_before=$(git -C "$repo_path" rev-parse HEAD)

    if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$switch_branch"; then
        local_commit=$(git -C "$repo_path" rev-parse "refs/heads/$switch_branch")

        if git -C "$repo_path" merge-base --is-ancestor "$local_commit" "$remote_commit"; then
            :
        else
            merge_base_status=$?
            if [ "$merge_base_status" -ne 1 ]; then
                die "Could not compare local and remote history for: $repo_path"
            fi

            timestamp=$(date '+%Y-%m-%d-%H%M%S')
            backup_branch=${switch_branch}-backup-${timestamp}
            git -C "$repo_path" branch "$backup_branch" "$local_commit"
            printf '  Preserved local commits on: %s\n' "$backup_branch"
        fi

        git -C "$repo_path" switch "$switch_branch"
    else
        git -C "$repo_path" switch --create "$switch_branch" --track "$remote_ref"
    fi

    printf '  Synchronizing %s with %s...\n' "$switch_branch" "$remote_ref"
    git -C "$repo_path" reset --hard "$remote_ref" >/dev/null
    git -C "$repo_path" submodule sync --recursive >/dev/null
    git -C "$repo_path" submodule update --init --recursive

    snapshot_after=$(git -C "$repo_path" rev-parse HEAD)
    if [ "$snapshot_before" != "$snapshot_after" ]; then
        repository_changed=1
    fi

    printf '  [OK] Repository is up to date.\n\n'
}

engine_branch=dimensions-fixes-$godot_version
printf 'Engine target branch: %s\n\n' "$engine_branch"

update_repository "$engine_repo_path" "$engine_branch"

modules_found=0
for module_path in "$modules_dir"/*; do
    [ -d "$module_path" ] || continue
    modules_found=1
    update_repository "$module_path" main
done

if [ "$modules_found" -eq 0 ]; then
    printf 'WARNING: No modules found in %s\n' "$modules_dir" >&2
fi

mkdir -p "$cache_dir"
if [ "$repository_changed" -eq 1 ]; then
    changed_json=true
else
    changed_json=false
fi

cache_tmp=${update_cache_file}.tmp.$$
trap 'rm -f "$cache_tmp"' 0 1 2 15
{
    printf '{\n'
    printf '  "reposChanged": %s,\n' "$changed_json"
    printf '  "lastUpdateTime": "%s"\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '}\n'
} >"$cache_tmp"
mv "$cache_tmp" "$update_cache_file"
trap - 0 1 2 15

printf '[OK] All engine repositories are up to date.\n'
if [ "$repository_changed" -eq 1 ]; then
    printf 'New source revisions were downloaded.\n'
else
    printf 'No source revisions changed.\n'
fi
