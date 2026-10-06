#!/usr/bin/env bash
# Crosswise's Godot launcher. One Godot at a time (follow_up/startup.md, section 6): the lock and
# the running-Godot check gate the launch in this same process, the lock is ours for the whole run
# and is released on exit even when a run fails. Output goes to a log first, then the log is searched.
#
#   run.sh headless <name> res://path/runner.gd [args after --]
#   run.sh windowed <name> res://path/runner.gd [args after --]
#   run.sh movie    <name> res://path/runner.gd [args]   (to smoke_test_output/video/<name>.avi)
#   run.sh check    <name> res://a.gd res://b.gd ...     (parse check, --check-only)
#   run.sh import   <name>                               (import new assets: sounds, the scene's uids)
#   run.sh batch    <file>                               (one job per line: "<mode> <name> <runner> [args]",
#                                                         all under one hold of the lock)
#   run.sh wait <any of the above>                       (waits for the lock instead of refusing; 60 min)
#
# Exit codes: 0 ran clean, 1 errors in a log, 3 Godot busy (someone else's turn).

ROOT=/d/depot/quantum-horizon
EXE="$ROOT/engine/godot/bin/godot.windows.editor.double.x86_64.console.exe"
LOCK="$ROOT/.claude/godot_in_use.txt"
LOGDIR="$ROOT/project/smoke_test_output/crosswise/logs"
mkdir -p "$LOGDIR"

busy() { [ -f "$LOCK" ] || tasklist 2>/dev/null | grep -qi godot; }

WAITING=0
if [ "$1" = "wait" ]; then
	WAITING=1
	shift
fi
ME="crosswise | $1 $2 | $(date '+%Y-%m-%d %H:%M')"

# Take the lock: wait while anyone holds it (in wait mode), then write ours and read it back a
# moment later, because another window can take it in the same second; if it is not ours, wait on.
waited=0
while true; do
	if busy; then
		if [ "$WAITING" = "0" ]; then
			echo "BUSY: Godot is someone else's right now."
			[ -f "$LOCK" ] && cat "$LOCK"
			tasklist 2>/dev/null | grep -i godot
			exit 3
		fi
		if [ "$waited" -ge 3600 ]; then echo "BUSY for 60 min, giving up."; [ -f "$LOCK" ] && cat "$LOCK"; exit 3; fi
		[ $((waited % 120)) -eq 0 ] && { echo "waiting for Godot ($waited s):"; [ -f "$LOCK" ] && cat "$LOCK"; }
		sleep 10; waited=$((waited + 10))
		continue
	fi
	echo "$ME" > "$LOCK"
	sleep 2
	if [ "$(cat "$LOCK" 2>/dev/null)" = "$ME" ] && ! tasklist 2>/dev/null | grep -qi godot; then
		break
	fi
	echo "lost the race for the lock, waiting again"
	# Our line must not stay behind and keep everyone (us included) waiting on it.
	if [ "$(cat "$LOCK" 2>/dev/null)" = "$ME" ]; then rm -f "$LOCK"; fi
	if [ "$WAITING" = "0" ]; then exit 3; fi
	sleep 10; waited=$((waited + 12))
done
trap 'if [ "$(cat "$LOCK" 2>/dev/null | cut -c1-9)" = "crosswise" ]; then rm -f "$LOCK"; fi' EXIT
cd "$ROOT"

status=0

run_one() {
	local mode="$1" name="$2"; shift 2
	local log="$LOGDIR/$name.log"
	: > "$log"
	echo "crosswise | $mode $name | $(date '+%Y-%m-%d %H:%M')" > "$LOCK"
	if [ "$mode" = "import" ]; then
		timeout 600 "$EXE" --headless --path project --import >> "$log" 2>&1
		echo "exit code: $?" >> "$log"
	elif [ "$mode" = "check" ]; then
		for f in "$@"; do
			echo "== $f" >> "$log"
			timeout 120 "$EXE" --headless --path project --check-only --script "$f" >> "$log" 2>&1
		done
	else
		local runner="$1"; shift
		local extra=()
		if [ "$#" -gt 0 ]; then extra=(-- "$@"); fi
		if [ "$mode" = "movie" ]; then
			mkdir -p "$ROOT/project/smoke_test_output/video"
			timeout 1500 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 \
				--write-movie "$ROOT/project/smoke_test_output/video/$name.avi" --fixed-fps 30 \
				--script "$runner" "${extra[@]}" >> "$log" 2>&1
		elif [ "$mode" = "windowed" ]; then
			timeout 600 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 --script "$runner" "${extra[@]}" >> "$log" 2>&1
		elif [ "$mode" = "big" ]; then
			timeout 600 "$EXE" --path project --windowed --resolution 1920x1080 --position 40,40 --script "$runner" "${extra[@]}" >> "$log" 2>&1
		else
			timeout 600 "$EXE" --headless --path project --script "$runner" "${extra[@]}" >> "$log" 2>&1
		fi
		echo "exit code: $?" >> "$log"
	fi
	local errors
	errors=$(grep -n -E "SCRIPT ERROR|Parse Error|Failed to load|Invalid call|Cannot call|Identifier .* not declared|ERROR: .*(script|Script|resource|Resource|Node not found)|SHADER ERROR| FAIL" "$log" | head -40)
	echo "---- $name: $log ($(wc -l < "$log") lines)"
	grep -E "PASS|FAIL|done|saved" "$log" | head -60
	if [ -n "$errors" ]; then
		echo "---- ERRORS in $name"
		echo "$errors"
		status=1
	fi
}

if [ "$1" = "batch" ]; then
	while read -r line; do
		[ -z "$line" ] && continue
		case "$line" in \#*) continue ;; esac
		# shellcheck disable=SC2086
		run_one $line
	done < "$2"
else
	run_one "$@"
fi
exit $status
