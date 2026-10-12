#!/usr/bin/env bash
# Records one menu film and encodes it. Lock-gated: waits (up to 45 min) for Godot to be free, takes
# the lock, runs, releases it. Usage:
#
#   film_run.sh <clip> <res://path/to/runner.gd> [runner args...]
#
# Frames go to smoke_test_output/menu_films/<clip>/frames (ignored by git); the encodes to
# smoke_test_output/menu_films/<clip>.mp4 (to review) and <clip>.ogv (for the menu), plus a contact
# sheet <clip>_sheet.jpg (one frame a second). Copying the .ogv into Menu/thumbs is a separate step.
ROOT=/d/depot/quantum-horizon
EXE="$ROOT/engine/godot/bin/godot.windows.editor.double.x86_64.console.exe"
LOCK="$ROOT/.claude/godot_in_use.txt"
clip="$1"; runner="$2"; shift 2
OUT="$ROOT/project/smoke_test_output/menu_films"
FRAMES="$OUT/$clip/frames"
LOG="$OUT/$clip.log"
mkdir -p "$OUT/$clip"

waited=0
while [ -f "$LOCK" ] || tasklist 2>/dev/null | grep -qi godot; do
	if [ $waited -ge 2700 ]; then echo "FILM $clip: Godot still busy after 45 min"; cat "$LOCK" 2>/dev/null; exit 3; fi
	sleep 15; waited=$((waited + 15))
done
echo "menu films | $clip | $(date '+%Y-%m-%d %H:%M')" > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

rm -rf "$FRAMES"; mkdir -p "$FRAMES"
cd "$ROOT"
timeout 1500 "$EXE" --path project --windowed --resolution 1920x1080 --position 40,40 --fixed-fps 30 \
	--script "$runner" -- "out=$FRAMES" "$@" > "$LOG" 2>&1
code=$?
rm -f "$LOCK"; trap - EXIT
n=$(ls "$FRAMES" 2>/dev/null | wc -l)
echo "FILM $clip: godot exit $code, $n frames"
grep -E "SCRIPT ERROR|FILM|ERROR: " "$LOG" | grep -v "Rect2 size\|leaked\|ObjectDB" | head -20
[ "$n" -gt 0 ] || exit 1

ffmpeg -y -v error -framerate 30 -i "$FRAMES/%05d.jpg" -c:v libx264 -crf 17 -pix_fmt yuv420p "$OUT/$clip.mp4"
ffmpeg -y -v error -framerate 30 -i "$FRAMES/%05d.jpg" -c:v libtheora -q:v 8 -an "$OUT/$clip.ogv"
ffmpeg -y -v error -i "$OUT/$clip.mp4" -vf "fps=1,scale=480:-1,tile=4x5" -frames:v 1 -q:v 3 "$OUT/${clip}_sheet.jpg"
ls -la "$OUT/$clip.mp4" "$OUT/$clip.ogv" "$OUT/${clip}_sheet.jpg" | awk '{print $5, $NF}'
