extends SceneTree

## Renders THE 4D ASCENT from an arbitrary viewpoint, so a vertical course can
## actually be judged.
##
## `Demo/_screenshot.gd` always parks the camera at (0, h, 0), which for this
## scene is INSIDE the spine - the one place in the level with nothing to see.
## This one takes a full eye position and a look-at target, which is what a tower
## needs. It also lets the w coordinate be set, so the same framing can be
## re-shot from a different slice to check what appears and disappears.
##
## Run with the editor closed, WITHOUT --headless (headless creates no rendering
## device and every shot comes out blank):
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_shot.gd -- ascent.tscn out.png 30 20 30 0 0 16 0
##
## Args after `--`: scene (name or res:// path), output filename, eye x y z w,
## then target x y z.

const DEFAULT_SCENE := "res://ramon/ObstacleCourse/ascent.tscn"

## Shaders compile and @tool builders rebuild over the first few frames, so an
## early grab shows an empty or untextured world - a bug that is not there.
const WARMUP_FRAMES := 30

var _root_node: Node = null
var _frames: int = 0
var _out_path: String = ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	if not scene_path.begins_with("res://"):
		scene_path = "res://ramon/ObstacleCourse/" + scene_path
	_out_path = args[1] if args.size() > 1 else "shot.png"
	var eye := Vector4(
			float(args[2]) if args.size() > 2 else 26.0,
			float(args[3]) if args.size() > 3 else 20.0,
			float(args[4]) if args.size() > 4 else 26.0,
			float(args[5]) if args.size() > 5 else 0.0)
	var target := Vector4(
			float(args[6]) if args.size() > 6 else 0.0,
			float(args[7]) if args.size() > 7 else 16.0,
			float(args[8]) if args.size() > 8 else 0.0,
			0.0)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("SHOT: could not load ", scene_path)
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)
	_place_camera(eye, target)


## Builds an orthonormal 4D basis looking from [param eye] to [param target].
##
## Only the xyz part is aimed; the w column is pinned to the fourth axis so the
## shot is taken in the home slice. Aiming w as well would silently slice-rotate
## the view, and every "why has that vanished" would be this function's fault
## rather than the level's.
func _place_camera(eye: Vector4, target: Vector4) -> void:
	var camera: Camera4D = _find_camera(_root_node)
	if camera == null:
		printerr("SHOT: no Camera4D found")
		quit(1)
		return
	# Detach from the player rig so moving it does not fight the controller.
	var holder: Node = camera.get_parent()
	if holder != null and holder != _root_node:
		holder.remove_child(camera)
		_root_node.add_child(camera)

	var forward_3d := Vector3(target.x - eye.x, target.y - eye.y, target.z - eye.z).normalized()
	# Camera4D looks along its own -Z, matching the player rig.
	var back := -forward_3d
	var world_up := Vector3(0.0, 1.0, 0.0)
	if absf(back.dot(world_up)) > 0.999:
		world_up = Vector3(0.0, 0.0, 1.0)
	var right := world_up.cross(back).normalized()
	var up := back.cross(right).normalized()

	camera.position = eye
	camera.basis = Projection(
		Vector4(right.x, right.y, right.z, 0.0),
		Vector4(up.x, up.y, up.z, 0.0),
		Vector4(back.x, back.y, back.z, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0)
	)
	print("SHOT: eye %s -> target %s" % [eye, target])


func _find_camera(node: Node) -> Camera4D:
	if node is Camera4D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("SHOT: no viewport image - remove --headless")
		quit(1)
		return true
	var absolute := ProjectSettings.globalize_path("res://ramon/ObstacleCourse/" + _out_path)
	var err := image.save_png(absolute)
	if err != OK:
		printerr("SHOT: save failed (%d)" % err)
		quit(1)
		return true
	print("SHOT: wrote ", absolute)
	quit()
	return true
