extends SceneTree

## Renders a scene to a PNG so it can actually be looked at.
##
## Everything else in this folder runs `--headless`, which loads scenes and runs
## scripts but never creates a rendering device - no shader compiles and nothing
## is drawn. That is fine for checking structure and useless for checking whether
## a texture looks right, which is why every visual change so far has had to be
## sent off unverified.
##
## This runs WITH a rendering device, waits for the renderer to settle, grabs the
## viewport and writes a file. Run it with the editor closed, same as the other
## tools here.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/Demo/_screenshot.gd -- hub1.tscn shot.png 60 1280 720
##
## Args after `--`: scene name in ramon/Demo/, output filename, camera to use
## (see below), then optional width and height.
##
## Frames are waited out rather than captured immediately: the first frames of a
## scene render before shaders finish compiling and before @tool scripts have
## rebuilt their geometry, so an early grab shows an empty or untextured world and
## looks like a bug that is not there.

const WARMUP_FRAMES := 30

var _root_node: Node = null
var _frames: int = 0
var _out_path: String = ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_name: String = args[0] if args.size() > 0 else "hub1.tscn"
	_out_path = args[1] if args.size() > 1 else "screenshot.png"
	var width: int = int(args[2]) if args.size() > 2 else 1280
	var height: int = int(args[3]) if args.size() > 3 else 720

	root.set_size(Vector2i(width, height))

	var scene_path := "res://ramon/Demo/" + scene_name
	if not ResourceLoader.exists(scene_path):
		# Allow a full res:// path too, so this works outside the Demo folder.
		scene_path = scene_name
	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("SHOT: could not load ", scene_path)
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	# Play mode (F5/F6) sets this automatically; scripts that read
	# get_tree().current_scene (a normal, correct thing to do) would otherwise
	# see null here and nowhere else. This script IS the SceneTree, hence self.
	set_current_scene(_root_node)
	print("SHOT: loaded ", scene_path)

	# Optional camera override: height then pitch in degrees. Looking straight
	# down is the only way to judge whether a floor grid is actually square -
	# from eye height, lines running away from the viewer and lines running
	# across it converge completely differently, and a correct grid reads as
	# though it were stretched along one axis.
	if args.size() > 4:
		var height_m := float(args[4])
		var pitch := deg_to_rad(float(args[5])) if args.size() > 5 else -90.0
		_place_camera(height_m, pitch)


func _place_camera(height_m: float, pitch: float) -> void:
	var camera: Node4D = _find_camera(_root_node)
	if camera == null:
		printerr("SHOT: no Camera4D found, using the scene's own view")
		return
	# Detach from the player rig so moving it does not fight the controller.
	var holder: Node = camera.get_parent()
	if holder != null and holder != _root_node:
		holder.remove_child(camera)
		_root_node.add_child(camera)
	camera.position = Vector4(0.0, height_m, 0.0, 0.0)
	var c := cos(pitch)
	var s := sin(pitch)
	# Pitch about X: -90 degrees points local -Z straight down.
	camera.basis = Projection(
		Vector4(1.0, 0.0, 0.0, 0.0),
		Vector4(0.0, c, s, 0.0),
		Vector4(0.0, -s, c, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0)
	)
	print("SHOT: camera at %.1f m, pitch %.0f deg" % [height_m, rad_to_deg(pitch)])


func _find_camera(node: Node) -> Node4D:
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
		printerr("SHOT: no viewport image - is this running without --headless?")
		quit(1)
		return true

	var absolute := ProjectSettings.globalize_path("res://ramon/Demo/" + _out_path)
	var err := image.save_png(absolute)
	if err != OK:
		printerr("SHOT: save failed (%d) for %s" % [err, absolute])
		quit(1)
		return true
	print("SHOT: wrote ", absolute, " (", image.get_width(), "x", image.get_height(), ")")
	quit(0)
	return true
