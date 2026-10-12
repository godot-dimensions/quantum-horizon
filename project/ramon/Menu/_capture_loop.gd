extends SceneTree
## Captures a looping thumbnail for one prototype, as a sprite sheet.
##
## THIS IS THE "WHAT I MEANT" SCRIPT. The menu's preview pane needs a moving
## thumbnail, because a still frame of a 4D cross-section is indistinguishable
## from a still frame of an ordinary 3D game - the entire subject of the demo is
## what happens when the slice turns. Video is the obvious answer and the wrong
## one: Godot's VideoStreamPlayer only decodes Ogg Theora natively, mp4/mpeg
## needs a third-party GDExtension, and AnimatedTexture is deprecated in 4.x.
##
## So instead of a video file, this renders N frames into ONE PNG laid out as a
## grid, and the menu steps an AtlasTexture region across it. No codec, no
## plugin, no dependency.
##
## Three properties that a screen recording would not give you:
##
## 1. **It loops perfectly by construction.** The sweep is a full 360 deg of zw
##    rotation, so the last frame's slice IS the first frame's slice. There is no
##    cut to hide and no cross-fade to tune.
## 2. **It is deterministic.** Re-running after a visual change regenerates the
##    same framing. Over eight prototypes that are all still moving, that is the
##    difference between a one-command refresh and re-recording eight clips.
## 3. **It shows the one thing that matters.** A capture of someone playing shows
##    walking around. This shows the slice turning, which is the pitch.
##
## Run with the editor CLOSED and WITHOUT --headless (headless never creates a
## rendering device, so nothing is drawn - the same reason Demo/_screenshot.gd
## exists):
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##       --path project --script res://ramon/Menu/_capture_loop.gd \
##       -- res://ramon/PhaseMaze/phase_maze.tscn phase_maze
##
## Args after `--`: scene path, output basename, then optionally frame count,
## columns, frame width, frame height.

## Shaders compile and @tool builders generate geometry over the first frames; an
## early grab catches an empty or untextured world and reads as a bug that isn't
## there. Same constant, same reason, as Demo/_screenshot.gd.
const WARMUP_FRAMES: int = 45

## Frames to let the renderer settle after each rotation step. The slice is a
## per-instance shader parameter pushed once per frame, so grabbing on the same
## frame the basis changed can catch the previous slice.
const SETTLE_FRAMES: int = 3

## Render at this size, then downscale to the frame size. Capturing large and
## shrinking is free antialiasing, and 4D cross-section edges are exactly the
## high-frequency detail that aliases badly at thumbnail scale.
const CAPTURE_SIZE: Vector2i = Vector2i(1120, 644)

## Framing is OPT-IN, and that is a lesson rather than a preference.
##
## The obvious move is to lift the camera and pitch it down for a diorama view.
## Tried at 9 m over Phase Maze, it produced 24 near-black frames: the maze is an
## enclosed room, so "above it" is outside it, looking at an unlit exterior. Any
## scene with a ceiling has the same trap.
##
## So by default the scene's own camera stays exactly where the scene put it -
## it is already pointed at the thing the prototype is about. Pass the height/
## pitch/back-off arguments only for open scenes where a raised view genuinely
## helps, and check the sheet afterwards.
const DEFAULT_PITCH_DEGREES: float = -12.0
const DEFAULT_BACK_OFF: float = 0.0

var _scene_path: String = "res://ramon/PhaseMaze/phase_maze.tscn"
var _basename: String = "phase_maze"
var _frame_count: int = 24
var _columns: int = 6
var _frame_size: Vector2i = Vector2i(280, 161)
var _eye_height: float = 0.0
var _pitch: float = DEFAULT_PITCH_DEGREES
var _back_off: float = DEFAULT_BACK_OFF
var _reframe: bool = false

var _root_node: Node = null
var _pivot: Node4D = null
var _pivot_basis: Projection = Projection()
var _sheet: Image = null

var _warmed: int = 0
var _settled: int = 0
var _captured: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene_path = args[0]
	if args.size() > 1:
		_basename = args[1]
	if args.size() > 2:
		_frame_count = maxi(1, int(args[2]))
	if args.size() > 3:
		_columns = maxi(1, int(args[3]))
	if args.size() > 5:
		_frame_size = Vector2i(int(args[4]), int(args[5]))
	if args.size() > 6:
		_eye_height = float(args[6])
		_reframe = true
	if args.size() > 7:
		_pitch = float(args[7])
	if args.size() > 8:
		_back_off = float(args[8])

	root.set_size(CAPTURE_SIZE)

	if not ResourceLoader.exists(_scene_path):
		printerr("CAPTURE: no such scene ", _scene_path)
		quit(1)
		return
	var packed: PackedScene = load(_scene_path) as PackedScene
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	# Scripts that read get_tree().current_scene - which MiegakureLook's level
	# base legitimately does to find out which level it is - see null without
	# this, and only when run from a script like this one.
	set_current_scene(_root_node)

	_hide_screen_ui(_root_node)

	_pivot = _find_camera(_root_node)
	if _pivot == null:
		printerr("CAPTURE: found no Camera4D to rotate in ", _scene_path)
		quit(1)
		return

	# Stop the controller driving itself: otherwise gravity walks the player off
	# whatever it is standing on during the capture, and _physics_process
	# rewrites the basis we are setting every frame.
	var body: Node = _pivot
	while body != null:
		if body is CharacterBody4D:
			body.set_physics_process(false)
			body.set_process(false)
			body.set_process_input(false)
			break
		body = body.get_parent()

	_frame_camera()
	_pivot_basis = _pivot.basis

	print("CAPTURE: %s -> %d frames, camera '%s'" % [_scene_path, _frame_count, _pivot.name])


## Removes the prototype's own screen UI from the shot. The first capture baked
## the maze HUD and the "BACK TO HUB" prompt into all 24 frames, which is both
## ugly at thumbnail size and actively wrong - the thumbnail advertises the
## prototype, it is not a screenshot of someone playing it.
##
## The rule is structural rather than name-matching: hide every [CanvasLayer],
## and every [Control] with no [Node4D] anywhere beneath it. A Control that DOES
## contain 4D content is the scene's own root wrapper (phase_maze.tscn is
## exactly that shape) and hiding it would hide the world itself.
func _hide_screen_ui(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
			continue
		if child is Control and not _contains_4d(child):
			(child as Control).visible = false
			continue
		_hide_screen_ui(child)


func _contains_4d(node: Node) -> bool:
	if node is Node4D:
		return true
	for child in node.get_children():
		if _contains_4d(child):
			return true
	return false


## Lifts the camera out of the player rig and parks it as a diorama view.
##
## Detached from its holder first, for the reason Demo/_screenshot.gd gives:
## left under the rig, the controller's own transform fights whatever is set
## here. Pitch is applied about X, so local -Z points down-and-forward.
func _frame_camera() -> void:
	if not _reframe:
		return

	var holder: Node = _pivot.get_parent()
	var anchor: Vector4 = _pivot.global_position
	if holder != null and holder != _root_node:
		holder.remove_child(_pivot)
		# Clearing the owner first silences "will make owner inconsistent" -
		# the node was owned by the player scene it is being pulled out of.
		_pivot.owner = null
		_root_node.add_child(_pivot)

	_pivot.position = Vector4(anchor.x, _eye_height, anchor.z + _back_off, anchor.w)

	var radians: float = deg_to_rad(_pitch)
	var c: float = cos(radians)
	var s: float = sin(radians)
	_pivot.basis = Projection(
		Vector4(1.0, 0.0, 0.0, 0.0),
		Vector4(0.0, c, s, 0.0),
		Vector4(0.0, -s, c, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0)
	)


func _find_camera(node: Node) -> Node4D:
	if node is Camera4D:
		return node as Node4D
	for child in node.get_children():
		var found: Node4D = _find_camera(child)
		if found != null:
			return found
	return null


func _process(_delta: float) -> bool:
	_warmed += 1
	if _warmed < WARMUP_FRAMES:
		return false

	if _captured >= _frame_count:
		return _write_sheet()

	# Hold the new slice for a few frames before grabbing it.
	_settled += 1
	if _settled <= SETTLE_FRAMES:
		if _settled == 1:
			_apply_slice(_captured)
		return false
	_settled = 0

	var shot: Image = root.get_texture().get_image()
	if shot == null:
		printerr("CAPTURE: no viewport image - running without a rendering device?")
		quit(1)
		return true
	shot.resize(_frame_size.x, _frame_size.y, Image.INTERPOLATE_LANCZOS)

	if _sheet == null:
		var rows: int = ceili(float(_frame_count) / float(_columns))
		_sheet = Image.create_empty(_frame_size.x * _columns, _frame_size.y * rows, false, shot.get_format())

	var column: int = _captured % _columns
	var row: int = _captured / _columns
	_sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, _frame_size), Vector2i(column * _frame_size.x, row * _frame_size.y))

	_captured += 1
	return false


## One full turn across the whole sheet, so frame N-1 hands back to frame 0.
##
## Composed on the RIGHT of the pivot's original basis, matching how player.gd
## applies its own slice rotation (`body_basis *= Basis4D.from_zw(...)`), i.e. in
## the body's local frame rather than the world's. Composing on the left instead
## reads as the whole scene tumbling rather than the slice turning - the same
## order-matters trap MiegakureLook's camera notes record.
func _apply_slice(index: int) -> void:
	var theta: float = TAU * float(index) / float(_frame_count)
	_pivot.basis = Basis4D.orthonormalized(_pivot_basis * Basis4D.from_zw(theta))


func _write_sheet() -> bool:
	if _sheet == null:
		printerr("CAPTURE: nothing captured")
		quit(1)
		return true

	var dir: String = "res://ramon/Menu/thumbs/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out: String = ProjectSettings.globalize_path("%s%s_loop.png" % [dir, _basename])
	var err: int = _sheet.save_png(out)
	if err != OK:
		printerr("CAPTURE: save failed (%d) for %s" % [err, out])
		quit(1)
		return true

	# Printed so the menu's ENTRIES can be filled in without opening the file.
	print("CAPTURE: wrote %s  (%dx%d, %d frames, %d cols)" % [out, _sheet.get_width(), _sheet.get_height(), _frame_count, _columns])
	quit(0)
	return true
