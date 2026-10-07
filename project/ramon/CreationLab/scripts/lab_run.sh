#!/usr/bin/env bash
# One Godot at a time (follow_up/startup.md, section 6): the lock and the running-Godot check
# gate the launch in this same process, the lock is ours for the run, and it is released on
# exit even when the run fails. Output goes to a log file first (a pipe through grep is lost
# if the timeout kills Godot), then the log is searched for errors.
#
#   lab_run.sh headless <name> res://path/runner.gd [args after --]
#   lab_run.sh windowed <name> res://path/runner.gd [args after --]
#   lab_run.sh movie    <name> res://path/runner.gd [args]    (to smoke_test_output/video/<name>.avi)
#   lab_run.sh movie_hd <name> res://path/runner.gd [args]    (the same at 1920 x 1080)
#   lab_run.sh fast     <name> res://path/runner.gd [args]    (headless, fixed 60 fps: faster than real time)
#   lab_run.sh check    <name> res://a.gd res://b.gd ...      (parse check, --check-only)
#
# Exit codes: 0 ran clean, 1 errors in the log, 3 Godot busy (someone else's turn).

ROOT=/d/depot/quantum-horizon
EXE="$ROOT/engine/godot/bin/godot.windows.editor.double.x86_64.console.exe"
LOCK="$ROOT/.claude/godot_in_use.txt"
LOGDIR="$ROOT/project/smoke_test_output/creation_lab/logs"
mkdir -p "$LOGDIR"

mode="$1"; name="$2"; shift 2

if [ -f "$LOCK" ] || tasklist 2>/dev/null | grep -qi godot; then
	echo "BUSY: Godot is someone else's right now."
	[ -f "$LOCK" ] && cat "$LOCK"
	tasklist 2>/dev/null | grep -i godot
	exit 3
fi
echo "creation lab | $mode $name | $(date '+%Y-%m-%d %H:%M')" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

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
	if [ "$mode" = "movie_hd" ]; then
		# The same at 1920 x 1080, for a film to share.
		mkdir -p "$ROOT/project/smoke_test_output/video"
		timeout 1800 "$EXE" --path project --windowed --resolution 1920x1080 --position 0,0 			--write-movie "$ROOT/project/smoke_test_output/video/$name.avi" --fixed-fps 30 --script "$runner" "${extra[@]}" >> "$log" 2>&1
	elif [ "$mode" = "movie" ]; then
		# Godot's movie writer at a fixed 30 fps (the film runners' convention), to video/<name>.avi.
		mkdir -p "$ROOT/project/smoke_test_output/video"
		timeout 1200 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 			--write-movie "$ROOT/project/smoke_test_output/video/$name.avi" --fixed-fps 30 			--script "$runner" "${extra[@]}" >> "$log" 2>&1
	elif [ "$mode" = "fast" ]; then
		# Headless at a fixed 60 fps: game time runs as fast as the machine can step it, so a
		# runner that watches three minutes of play takes seconds. Never for timings.
		timeout 900 "$EXE" --headless --path project --fixed-fps 60 --script "$runner" "${extra[@]}" >> "$log" 2>&1
	elif [ "$mode" = "windowed" ]; then
		timeout 900 "$EXE" --path project --windowed --resolution 1280x720 --position 40,40 --script "$runner" "${extra[@]}" >> "$log" 2>&1
	else
		timeout 900 "$EXE" --headless --path project --script "$runner" "${extra[@]}" >> "$log" 2>&1
	fi
	echo "exit code: $?" >> "$log"
fi

errors=$(grep -n -E "SCRIPT ERROR|Parse Error|Failed to load|Invalid call|Cannot call|Identifier .* not declared|ERROR: .*(script|Script|resource|Resource|Node not found)|SHADER ERROR" "$log" | head -40)
echo "---- log: $log ($(wc -l < "$log") lines)"
if [ -n "$errors" ]; then
	echo "---- ERRORS"
	echo "$errors"
	exit 1
fi
exit 0
