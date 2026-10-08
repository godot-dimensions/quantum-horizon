#!/usr/bin/env bash
# The Phase Maze remake's one way to launch Godot (follow_up/startup.md section 6: one Godot at a time).
#
# Another window is often working (Ramon, 5 Oct: "you might have to wait sometimes on the engine to get
# unlocked"), so this WAITS ITS TURN: it checks the lock file and the running Godot processes every
# 20 s, for up to RANGE_WAIT seconds (default 480), and only then takes the lock, in this same process,
# so nothing can slip in between the check and the launch. The lock is released on exit, even when the
# run fails. Output goes to a log file first (a pipe through grep is lost if the timeout kills Godot),
# then the log is searched for errors.
#
#   run.sh headless <name> res://path/runner.gd [args after --]
#   run.sh windowed <name> res://path/runner.gd [args after --]   (1280x720 at 40,40)
#   run.sh movie    <name> res://path/runner.gd [args]            (smoke_test_output/video/<name>.avi)
#   run.sh clip     <name> res://path/runner.gd [args]            (windowed, --fixed-fps 30; the runner saves frames)
#   run.sh check    <name> res://a.gd res://b.gd ...              (parse check, --check-only)
#
# Exit codes: 0 ran clean, 1 errors in the log, 3 still busy after the wait.

ROOT=/d/depot/quantum-horizon
EXE="$ROOT/engine/godot/bin/godot.windows.editor.double.x86_64.console.exe"
LOCK="$ROOT/.claude/godot_in_use.txt"
LOGDIR="$ROOT/project/smoke_test_output/phase_maze_remake/logs"
mkdir -p "$LOGDIR"
WAIT="${RANGE_WAIT:-480}"

mode="$1"; name="$2"; shift 2

busy() {
	[ -f "$LOCK" ] && return 0
	tasklist 2>/dev/null | grep -qi godot && return 0
	return 1
}

waited=0
while busy; do
	if [ "$waited" -ge "$WAIT" ]; then
		echo "BUSY: still someone else's turn after ${WAIT}s."
		[ -f "$LOCK" ] && cat "$LOCK"
		tasklist 2>/dev/null | grep -i godot
		exit 3
	fi
	if [ "$waited" -eq 0 ]; then
		echo "Waiting for the engine:"
		[ -f "$LOCK" ] && cat "$LOCK"
	fi
	sleep 20
	waited=$((waited + 20))
done
echo "phase maze remake | $mode $name | $(date '+%Y-%m-%d %H:%M')" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT
[ "$waited" -gt 0 ] && echo "Got the engine after ${waited}s."

log="$LOGDIR/$name.log"
: > "$log"
cd "$ROOT"

if [ "$mode" = "check" ]; then
	for f in "$@"; do
		echo "== $f" >> "$log"
		timeout 120 "$EXE" --headless --path project --check-only --script "$f" >> "$log" 2>&1
	done
else
	runner="$1"; shift
	extra=()
	if [ "$#" -gt 0 ]; then extra=(-- "$@"); fi
	if [ "$mode" = "movie" ]; then
		mkdir -p "$ROOT/project/smoke_test_output/video"
		timeout 1500 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 \
			--write-movie "$ROOT/project/smoke_test_output/video/$name.avi" --fixed-fps 30 \
			--script "$runner" "${extra[@]}" >> "$log" 2>&1
	elif [ "$mode" = "clip" ]; then
		# Fixed 30 fps without the movie writer: the runner saves the frames it wants (a menu clip).
		timeout 900 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 --fixed-fps 30 --script "$runner" "${extra[@]}" >> "$log" 2>&1
	elif [ "$mode" = "windowed" ]; then
		timeout 900 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 --script "$runner" "${extra[@]}" >> "$log" 2>&1
	else
		timeout 900 "$EXE" --headless --path project --script "$runner" "${extra[@]}" >> "$log" 2>&1
	fi
	echo "exit code: $?" >> "$log"
fi

errors=$(grep -n -E "SCRIPT ERROR|Parse Error|Failed to load|Invalid call|Cannot call|Identifier .* not declared|ERROR: .*(script|Script|resource|Resource|Node not found)|SHADER ERROR|Invalid access|Invalid get|Invalid set|Nonexistent function" "$log" | head -40)
echo "---- log: $log ($(wc -l < "$log") lines)"
if [ -n "$errors" ]; then
	echo "---- ERRORS"
	echo "$errors"
	exit 1
fi
exit 0
