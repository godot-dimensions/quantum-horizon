extends SceneTree
## Renders ramon/Menu.tscn to a PNG so the layout can be checked without
## opening the editor.
##
## Needs a real rendering device, so run WITHOUT --headless - headless never
## creates one and nothing is drawn (same reason Demo/_screenshot.gd exists).
## Editor must be closed: two Godot processes on one .godot cache silently
## breaks @tool buttons in the running editor.
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##       --path project --resolution 1600x900 \
##       --script res://ramon/Menu/_shot.gd -- menu_mockup.png

const SETTLE_FRAMES: int = 30

var _frames: int = 0
var _out_path: String = "menu_mockup.png"
var _select_index: int = -1
var _menu: Node = null
var _show_overlay: bool = false
var _show_notice: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = args[0]
	# Second arg picks which entry is selected, so a shot can show an entry
	# whose loop has actually been captured rather than always entry 0.
	if args.size() > 1:
		_select_index = int(args[1])
	# Last positional arg: pass "overlay" to render the launch screen.
	if args.size() > 0 and args[args.size() - 1] == "overlay":
		_show_overlay = true
	if args.size() > 0 and args[args.size() - 1] == "notice":
		_show_notice = true

	var packed: PackedScene = load("res://ramon/Menu.tscn") as PackedScene
	if packed == null:
		push_error("could not load Menu.tscn")
		quit(1)
		return
	_menu = packed.instantiate()

	# Optional style overrides, applied BEFORE the node enters the tree - the
	# menu builds its whole screen in _ready(), so assigning a style afterwards
	# would change nothing. Used to demonstrate that the modular scale really
	# does move the entire hierarchy from one number.
	if args.size() > 2:
		var style: MenuStyle = load("res://ramon/Menu/style/default_style.tres") as MenuStyle
		style = style.duplicate() as MenuStyle
		style.base_font_size = int(args[2])
		if args.size() > 3:
			style.ui_scale = float(args[3])
		if args.size() > 4:
			style.spacing_unit = int(args[4])
		if args.size() > 5:
			style.type_ratio = float(args[5])
		if args.size() > 6:
			style.preview_focus_default = float(args[6])
		_menu.style = style

	root.add_child(_menu)
	set_current_scene(_menu)


## Must return bool - SceneTree._process's signature is `(float) -> bool`, and
## returning true QUITS the tree. Declaring it `-> void` is a parse error, and
## returning true early is the trap MiegakureLook's probes hit: the harness
## exits before the thing being measured happens, with no error and exit code 0.
func _process(_delta: float) -> bool:
	_frames += 1
	# Fonts, theme overrides and container layout all settle over several
	# frames; shooting on frame 1 catches an unlaid-out screen.
	if _frames == 2 and _select_index >= 0 and _menu != null:
		_menu.call("_select", _select_index)
		# Optional: force the launch overlay up so it can be reviewed without
		# actually launching anything.
		if _show_overlay:
			var entries: Array = _menu.get("catalogue").entries
			_menu.call("_show_overlay", entries[_select_index])
		if _show_notice:
			_menu.call("_show_notice")
	if _frames < SETTLE_FRAMES:
		return false

	var image: Image = root.get_texture().get_image()
	var absolute: String = ProjectSettings.globalize_path("res://ramon/Menu/" + _out_path)
	var err: int = image.save_png(absolute)
	print("saved %s (%d)" % [absolute, err])
	quit(0)
	return true
