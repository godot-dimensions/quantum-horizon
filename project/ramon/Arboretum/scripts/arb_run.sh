#!/usr/bin/env bash
# The Arboretum's runner launcher (after CreationLab/scripts/lab_run.sh). One Godot at a time
# (follow_up/startup.md, section 6): the lock and the running-Godot check gate the launch in this
# same process, the lock is ours for the run, and it is released on exit even when the run fails.
# Output goes to a log file first, then the log is searched for errors.
#
#   arb_run.sh headless <name> res://path/runner.gd [args after --]
#   arb_run.sh windowed <name> res://path/runner.gd [args after --]
#   arb_run.sh movie    <name> res://path/runner.gd [args]    (to smoke_test_output/video/<name>.avi)
#   arb_run.sh check    <name> res://a.gd res://b.gd ...      (parse check, --check-only)
#   arb_run.sh batch    <name> <spec file>                   (several runs under ONE lock: each line
#                                                              "mode name runner [args]"; a line
#                                                              starting "check" lists scripts; a run
#                                                              that fails stops the batch)
#
# WAIT=<seconds> waits that long for another window's Godot to finish (checking every 15 s) before
# giving up; without it a busy Godot is exit 3 at once.
#
# Exit codes: 0 ran clean, 1 errors in a log, 3 Godot busy (someone else's turn).

ROOT=/d/depot/quantum-horizon
EXE="$ROOT/engine/godot/bin/godot.windows.editor.double.x86_64.console.exe"
LOCK="$ROOT/.claude/godot_in_use.txt"
LOGDIR="$ROOT/project/smoke_test_output/arboretum/logs"
mkdir -p "$LOGDIR"

mode="$1"; name="$2"; shift 2

busy() {
	[ -f "$LOCK" ] || tasklist 2>/dev/null | grep -qi godot
}

waited=0
limit="${WAIT:-0}"
while busy; do
	if [ "$waited" -ge "$limit" ]; then
		echo "BUSY: Godot is someone else's right now."
		[ -f "$LOCK" ] && cat "$LOCK"
		tasklist 2>/dev/null | grep -i godot
		exit 3
	fi
	sleep 15
	waited=$((waited + 15))
done
echo "arboretum | $mode $name | $(date '+%Y-%m-%d %H:%M')" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT
cd "$ROOT"

# One run: mode, log name, then the runner and its args (or, for check, the scripts).
run_one() {
	local m="$1"; local n="$2"; shift 2
	local log="$LOGDIR/$n.log"
	: > "$log"
	if [ "$m" = "check" ]; then
		for f in "$@"; do
			echo "== $f" >> "$log"
			timeout 120 "$EXE" --headless --path project --check-only --script "$f" >> "$log" 2>&1
		done
	else
		local runner="$1"; shift
		local extra=()
		if [ "$#" -gt 0 ]; then extra=(-- "$@"); fi
		if [ "$m" = "movie" ]; then
			mkdir -p "$ROOT/project/smoke_test_output/video"
			timeout 1200 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 \
				--write-movie "$ROOT/project/smoke_test_output/video/$n.avi" --fixed-fps 30 \
				--script "$runner" "${extra[@]}" >> "$log" 2>&1
		elif [ "$m" = "windowed" ]; then
			timeout 900 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 --script "$runner" "${extra[@]}" >> "$log" 2>&1
		else
			timeout 900 "$EXE" --headless --path project --script "$runner" "${extra[@]}" >> "$log" 2>&1
		fi
		echo "exit code: $?" >> "$log"
	fi
	local errors
	# (The exit's "resources still in use" leak note is not a failure of the run.)
	errors=$(grep -n -E "SCRIPT ERROR|Parse Error|Failed to load|Invalid call|Cannot call|Identifier .* not declared|ERROR: .*(script|Script|resource|Resource|Node not found)|SHADER ERROR" "$log" | grep -v "still in use at exit" | head -40)
	echo "---- log: $log ($(wc -l < "$log") lines)"
	if [ -n "$errors" ]; then
		echo "---- ERRORS"
		echo "$errors"
		return 1
	fi
	return 0
}

if [ "$mode" = "batch" ]; then
	spec="$1"
	status=0
	while IFS= read -r line || [ -n "$line" ]; do
		[ -z "$line" ] && continue
		case "$line" in \#*) continue ;; esac
		# shellcheck disable=SC2086
		set -- $line
		echo "==== $*"
		if ! run_one "$@"; then
			status=1
			break
		fi
	done < "$spec"
	exit $status
fi

run_one "$mode" "$name" "$@"
exit $?
