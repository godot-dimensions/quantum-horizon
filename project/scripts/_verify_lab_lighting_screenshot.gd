extends SceneTree
## TEMPORARY - renders a scene to a PNG so real lighting can actually be
## looked at, not just assumed from reading the .tscn. Adapted from
## Ramon's project/ramon/Demo/_screenshot.gd (RamonPrototypes branch) -
## same warmup-then-grab approach, generalized to take a full res:// scene
## path instead of assuming project/ramon/Demo/, since it's being used
## against sandbox/ lab scenes here.
##
## Run with the editor closed:
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://scripts/_verify_lab_lighting_screenshot.gd -- \
##       res://sandbox/shrubbery/shrubbery_lab.tscn C:/abs/out.png 1280 720

const WARMUP_FRAMES := 45

var _root_node: Node = null
var _frames: int = 0
var _out_path: String = ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else ""
	_out_path = args[1] if args.size() > 1 else "screenshot.png"
	var width: int = int(args[2]) if args.size() > 2 else 1280
	var height: int = int(args[3]) if args.size() > 3 else 720

	root.set_size(Vector2i(width, height))

	if scene_path == "" or not ResourceLoader.exists(scene_path):
		printerr("SHOT: could not find scene ", scene_path)
		quit(1)
		return
	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("SHOT: could not load ", scene_path)
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	print("SHOT: loaded ", scene_path)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false

	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("SHOT: no viewport image - is this running without --headless?")
		quit(1)
		return true

	var err := image.save_png(_out_path)
	if err != OK:
		printerr("SHOT: save failed (%d) for %s" % [err, _out_path])
		quit(1)
		return true
	print("SHOT: wrote ", _out_path, " (", image.get_width(), "x", image.get_height(), ")")
	quit(0)
	return true
