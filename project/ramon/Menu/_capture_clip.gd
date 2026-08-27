extends SceneTree
## Records a real playthrough of a prototype as a numbered PNG sequence, which
## ffmpeg then turns into a looping .ogv for the menu's preview pane.
##
## EACH PROTOTYPE HAS ITS OWN CHOREOGRAPHY, written from what that prototype is
## actually for - see PERFORMANCES below. A generic walk-and-spin was tried
## first and it was worthless: it showed a corridor in Phase Maze, a grey wall in
## Portal, and in Voxel Mining it never swung the axe at all, because carving is
## on the `fire` action and nothing pressed it. A preview that does not perform
## the prototype's own verb is just a screensaver.
##
## Frames are written OUTSIDE the repository by default. Demo/_screenshot.gd
## records why: an earlier tool defaulted to res:// and 93 stray screenshots
## accumulated before anyone noticed. A frame sequence is an intermediate.
##
## Run with the editor CLOSED, WITHOUT --headless, and WITH --fixed-fps so every
## frame advances the world by exactly 1/fps - otherwise recorded motion speeds
## up and slows down with the render rate and the clip looks drunk:
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --resolution 1280x720 --fixed-fps 30 \
##       --script res://ramon/Menu/_capture_clip.gd \
##       -- res://ramon/PhaseMaze/phase_maze.tscn phase_maze 9 C:/frames

const FPS: int = 30
const WARMUP_FRAMES: int = 60

## Matches player.gd's MOUSE_SENSITIVITY scaling. Slice rotation and look are
## both driven by mouse RELATIVE motion, so they have to be fed as motion
## events, not as actions.
const LOOK_STEP: float = 2.2

# --------------------------------------------------------------------------
# Choreography
# --------------------------------------------------------------------------
#
# Beat fields, all optional except `at`:
#
#   at     seconds this beat starts; it runs until the next beat's `at`
#   keys   input actions HELD for the beat (movement is polled, so held is right)
#   slice  degrees/second of zw rotation - rotate_4d held plus mouse motion
#   yaw    degrees/second of ordinary look - the same motion WITHOUT rotate_4d
#   tap    actions pressed ONCE as the beat begins, for event-driven verbs
#   pulse  an action tapped repeatedly through the beat
#   every  seconds between pulses (default 1.0)
#   key    a raw keycode tapped once at the beat start, for keys with no action

## Fallback for anything without its own entry: establish the space, walk, turn
## the slice, turn it back.
const DEFAULT_PERFORMANCE: Array[Dictionary] = [
	{"at": 0.0, "yaw": 14.0},
	{"at": 2.0, "keys": ["move_forward"], "yaw": -8.0},
	{"at": 3.2, "slice": 22.0},
	{"at": 5.8, "yaw": -12.0},
	{"at": 7.0, "slice": -22.0},
]

const PERFORMANCES: Dictionary = {
	# Mostly unlit corridor, and the lit part is near spawn - a clip that walks
	# far ends up staring at black. Stay near spawn, spend the time rotating,
	# which is the mechanic anyway.
	"phase_maze": [
		{"at": 0.0, "yaw": 14.0},
		{"at": 1.8, "keys": ["move_forward"], "yaw": -8.0},
		{"at": 2.8, "slice": 22.0},
		{"at": 5.4, "yaw": -12.0},
		{"at": 6.6, "slice": -22.0},
	],

	# The w_gap scene's own README describes the whole clip: "Walk forward. The
	# gap is 7 m and you can jump 4.59 m, so it cannot be crossed. Hold ana -
	# the ground turns blue and a bridge is there. Cross. Hold kata to come
	# home." So that is exactly what this performs, and it is the single most
	# legible 4D demonstration in the project - the floor visibly changes colour
	# and a crossing appears.
	"ascent": [
		# Shortened: the first cut kept walking after the crossing and spent its
		# last two seconds looking at empty room. It now ends ON the far side,
		# holding kata so the bridge is visibly leaving as the loop wraps.
		{"at": 0.0, "keys": ["move_forward"]},
		{"at": 1.8, "keys": ["move_ana"]},
		{"at": 3.6, "keys": ["move_forward", "move_ana"]},
		{"at": 5.6, "keys": ["move_forward"]},
		{"at": 6.4, "keys": ["move_kata"]},
		{"at": 8.0, "yaw": -10.0},
	],

	# voxel_chunk_test: shoot the wall anywhere, any number of times, and the
	# openings merge and then heal shut. One shot proves nothing - the point is
	# cumulative cuts - so this pulses `fire` across a slow pan, then holds
	# still while the wall heals.
	"portal": [
		# Approach first: the first attempt fired from spawn and the wall filled
		# the frame as flat grey, so nothing a cut did was legible. Getting
		# closer makes each opening a readable shape rather than a hairline.
		{"at": 0.0, "keys": ["move_forward"]},
		{"at": 1.4, "pulse": "fire", "every": 0.9, "yaw": 7.0},
		{"at": 5.0, "pulse": "fire", "every": 0.9, "yaw": -9.0},
		{"at": 7.0, "slice": 16.0},
	],

	# Melee range is 3 m (mining_axe.gd MINING_RANGE), so the axe has to be
	# walked right up to a rock before `fire` does anything at all. Approach
	# first, then chip repeatedly - a single swing is invisible at preview size,
	# a dozen visibly eats the rock.
	"voxel_mining": [
		# 0.6 s of walking, not 2.2. At 5 m/s the first attempt closed the whole
		# distance and pushed the camera INSIDE the rock, so 24 of 27 sampled
		# frames were solid black. Melee range is 3 m; the approach only has to
		# cover the last couple of metres.
		# The yaw during chipping is not decoration. Swinging from a fixed aim
		# hits the SAME voxel every time, so the cavity appears on the first
		# swing and then never changes - measured exactly that. Drifting the aim
		# a few degrees per second makes each swing take a different voxel, and
		# the hole visibly eats outward across the take.
		# Walk right up to it. 0.6 s stopped 3 m short - inside melee range, so
		# the axe worked, but it reads as chipping at something across the room.
		# Closing to arm's length is what makes it look like mining.
		{"at": 0.0, "keys": ["move_forward"]},
		{"at": 0.82, "pulse": "fire", "every": 0.4, "yaw": 4.0},
		{"at": 4.6, "pulse": "fire", "every": 0.4, "yaw": -5.0},
		{"at": 6.8, "keys": ["move_back"], "yaw": 3.0},
		{"at": 7.6, "slice": 18.0},
	],

	# Targets are the subject, and the interesting 4D claim is that a target can
	# leave your slice. So: fire a few, then rotate the slice and fire again
	# into a changed arrangement.
	"quantum_range": [
		{"at": 0.0, "yaw": 9.0},
		{"at": 1.4, "pulse": "fire", "every": 0.8},
		{"at": 4.0, "slice": 20.0},
		{"at": 6.0, "yaw": -7.0, "pulse": "fire", "every": 0.8},
	],

	# The ball never rotates; the CAMERA does, and rotate_4d is an EVENT that
	# toggles a 90 degree zw turn eased over 0.7 s (miegakure_camera_3.gd). So
	# this taps it rather than holding it, and waits out the transition. The
	# route is the level's own solution: blocked by the wall, rotate, walk along
	# w into the gap lane, rotate back, walk through.
	"slice_vision": [
		{"at": 0.0, "keys": ["move_forward"]},
		{"at": 1.6, "tap": ["rotate_4d"]},
		{"at": 2.6, "keys": ["move_forward"]},
		{"at": 4.6, "tap": ["rotate_4d"]},
		{"at": 5.6, "keys": ["move_forward"]},
		{"at": 7.6, "yaw": 10.0},
	],

	# No verb at all - this one is scenery, and the claim is that the clouds are
	# real solids rather than a painted sky, so they RESHAPE under slice
	# rotation instead of merely sliding past. Slow and continuous, no walking:
	# movement would only take the sky out of frame.
	"skybox_clouds": [
		{"at": 0.0, "yaw": 8.0},
		{"at": 2.0, "slice": 14.0},
		{"at": 5.5, "yaw": -6.0},
		{"at": 6.5, "slice": -14.0},
	],
}

var _scene_path: String = "res://ramon/PhaseMaze/phase_maze.tscn"
var _basename: String = "phase_maze"
var _seconds: float = 9.0
var _out_dir: String = ""

var _root_node: Node = null
var _performance: Array = DEFAULT_PERFORMANCE
var _warmed: int = 0
var _frame: int = 0
var _held: Array[String] = []
var _beat_index: int = -1
var _next_pulse: float = 0.0
var _pending_release: Array[StringName] = []

## Telemetry, so a capture reports what actually HAPPENED rather than what was
## asked for. Contact sheets show whether a clip looks good; these show whether
## the prototype's own verb ever fired. A run that walks around and never swings
## looks plausible in stills and is worthless.
var _verb_count: int = 0
var _player: Node4D = null
var _start_position: Vector4 = Vector4()
var _last_report: int = -1


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene_path = args[0]
	if args.size() > 1:
		_basename = args[1]
	if args.size() > 2:
		_seconds = maxf(1.0, float(args[2]))
	if args.size() > 3:
		_out_dir = args[3]

	if _out_dir == "":
		printerr("CLIP: no output directory given")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_performance = PERFORMANCES.get(_basename, DEFAULT_PERFORMANCE)

	if not ResourceLoader.exists(_scene_path):
		printerr("CLIP: no such scene ", _scene_path)
		quit(1)
		return
	var packed: PackedScene = load(_scene_path) as PackedScene
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	# Scripts that legitimately read get_tree().current_scene see null without
	# this, and only when run from a script like this one.
	set_current_scene(_root_node)

	_hide_screen_ui(_root_node)
	_player = _find_movable(_root_node)
	if _player != null:
		_start_position = _player.global_position
	print("CLIP: %s -> %.1f s, %d beats%s" % [
		_scene_path, _seconds, _performance.size(),
		"" if PERFORMANCES.has(_basename) else " (DEFAULT choreography)"
	])


## Removes the prototype's own screen UI from the recording. A preview
## advertises the prototype; a baked-in HUD is clutter at preview size.
##
## Structural rather than name-matching: hide every CanvasLayer, and every
## Control with no Node4D beneath it. A Control that DOES contain 4D content is
## the scene's own root wrapper - phase_maze.tscn is exactly that shape - and
## hiding it would hide the world itself.
func _hide_screen_ui(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
			continue
		if child is Control and not _contains_4d(child):
			(child as Control).visible = false
			continue
		_hide_screen_ui(child)


## Whatever the clip actually moves - a CharacterBody4D in the first-person
## scenes, the ball in MiegakureLook. Only used for telemetry.
func _find_movable(node: Node) -> Node4D:
	if node is CharacterBody4D:
		return node as Node4D
	for child in node.get_children():
		var found: Node4D = _find_movable(child)
		if found != null:
			return found
	return null


func _contains_4d(node: Node) -> bool:
	if node is Node4D:
		return true
	for child in node.get_children():
		if _contains_4d(child):
			return true
	return false


func _process(_delta: float) -> bool:
	_warmed += 1
	if _warmed <= WARMUP_FRAMES:
		return false

	var total: int = int(_seconds * FPS)
	if _frame >= total:
		return _finish()

	_flush_releases()

	var elapsed: float = float(_frame) / float(FPS)
	_drive(elapsed)
	_report(elapsed)

	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("CLIP: no viewport image - running without a rendering device?")
		quit(1)
		return true
	# Zero-padded so ffmpeg's %05d pattern picks them up in order.
	image.save_png("%s/%s_%05d.png" % [_out_dir, _basename, _frame])

	_frame += 1
	return false


## Drives the real input actions for whichever beat is current.
##
## Movement is POLLED by the controllers (Input.get_axis in _physics_process), so
## action_press is correct for it. Look and slice rotation are EVENT-driven and
## need real InputEventMouseMotion through parse_input_event - action_press alone
## never reaches _input. Verbs like `fire` are also events, and are TAPPED:
## holding fire down would fire once and then do nothing.
##
## Getting held-versus-tapped backwards looks exactly like broken input, which is
## the trap MiegakureLook's probes hit and recorded.
func _drive(elapsed: float) -> void:
	var index: int = 0
	for i in _performance.size():
		if elapsed >= float(_performance[i]["at"]):
			index = i
	var beat: Dictionary = _performance[index]

	# Beat boundary: fire one-shot taps and reset the pulse clock.
	if index != _beat_index:
		_beat_index = index
		_next_pulse = elapsed
		for action in beat.get("tap", []):
			_tap_action(StringName(action))
		if beat.has("key"):
			_tap_key(int(beat["key"]))

	if beat.has("pulse"):
		var period: float = float(beat.get("every", 1.0))
		if elapsed >= _next_pulse:
			_tap_action(StringName(beat["pulse"]))
			_next_pulse = elapsed + period

	var wanted: Array = beat.get("keys", [])
	for action in _held:
		if not wanted.has(action):
			Input.action_release(action)
	_held.clear()
	for action in wanted:
		Input.action_press(action)
		_held.append(str(action))

	var slice_rate: float = float(beat.get("slice", 0.0))
	var yaw_rate: float = float(beat.get("yaw", 0.0))

	if not is_zero_approx(slice_rate):
		# player.gd maps mouse y onto the zw plane while rotate_4d is held.
		Input.action_press(&"rotate_4d")
		_send_motion(Vector2(0.0, slice_rate / float(FPS) * LOOK_STEP))
		return

	# rotate_4d must be RELEASED before an ordinary look, or the same motion is
	# read as a slice rotation - the two share one handler and differ only by
	# whether that action is held.
	Input.action_release(&"rotate_4d")
	if not is_zero_approx(yaw_rate):
		_send_motion(Vector2(yaw_rate / float(FPS) * LOOK_STEP, 0.0))


## Taps an action so that BOTH styles of listener see it.
##
## THE BUG THIS FIXES, and it silently wasted a whole capture pass:
## `Input.action_press()` only updates the state that `Input.is_action_pressed()`
## POLLS. It never dispatches an InputEvent, so it never reaches `_input()`. And
## every verb in this project is event-driven - `mining_axe.gd`,
## `portal_gun_4d.gd` and the shooting gallery all test
## `event.is_action_pressed(&"fire")` inside `_input`, and
## `miegakure_camera_3.gd` does the same with `rotate_4d`. Firing them with
## action_press produced clips where the player walked around and never once
## swung, shot, or rotated.
##
## An InputEventAction parsed through the input singleton is delivered as a real
## event AND updates the polled state, so it covers both. MiegakureLook's own
## probe notes record this exact distinction; I had it in a comment here and
## still implemented it the wrong way round.
func _tap_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	_pending_release.append(action)
	_verb_count += 1


## Releases last frame's taps. Held down, `fire` fires once and then does
## nothing, so every tap needs a matching release before the next one.
func _flush_releases() -> void:
	for action in _pending_release:
		var release := InputEventAction.new()
		release.action = action
		release.pressed = false
		Input.parse_input_event(release)
	_pending_release.clear()


## For keys with no input action behind them - portal_gun_4d.gd reads KEY_F
## directly off the event rather than through an action.
func _tap_key(keycode: int) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)


func _send_motion(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	motion.screen_relative = relative
	Input.parse_input_event(motion)


## One line per second of the take: where the mover is, and how many verb taps
## have landed. This is what makes "did anything actually happen" answerable
## without opening a single frame - a run whose position never changes was
## blocked, and a run whose verb count stays 0 never performed its mechanic.
func _report(elapsed: float) -> void:
	var second: int = int(elapsed)
	if second == _last_report:
		return
	_last_report = second
	if _player == null:
		print("  t=%ds  (no movable found)  verbs=%d" % [second, _verb_count])
		return
	var position: Vector4 = _player.global_position
	var moved: Vector4 = position - _start_position
	print("  t=%ds  pos (%.1f, %.1f, %.1f, w %.1f)  moved %.1f m  verbs=%d" % [
		second, position.x, position.y, position.z, position.w,
		Vector4(moved.x, moved.y, moved.z, moved.w).length(), _verb_count
	])


func _finish() -> bool:
	_flush_releases()
	for action in _held:
		Input.action_release(action)
	Input.action_release(&"rotate_4d")

	print("CLIP: wrote %d frames as %s/%s_%%05d.png" % [_frame, _out_dir, _basename])
	# Stated loudly, because a clip that never fired its verb is the failure that
	# looks fine in stills and is worthless as a preview.
	var expects_verb: bool = false
	for beat in _performance:
		if beat.has("pulse") or beat.has("tap") or beat.has("key"):
			expects_verb = true
	if expects_verb and _verb_count == 0:
		printerr("CLIP: *** NO VERB EVER FIRED *** - the choreography asked for taps and none landed")
		quit(1)
		return true
	print("CLIP: %d verb taps delivered" % _verb_count)
	quit(0)
	return true
