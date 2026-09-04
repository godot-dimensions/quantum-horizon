extends SceneTree
## Renders ramon/FrontierMap.tscn to a PNG and prints what it actually built.
##
## Same rules as `_shot2.gd`: run WITHOUT --headless, because headless never
## creates a rendering device and nothing is drawn; and with the EDITOR CLOSED,
## because two Godot processes on one .godot cache silently breaks @tool buttons
## in the running editor.
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##       --path project --resolution 1920x1080 \
##       --script res://ramon/Menu/_shot_frontier.gd -- frontier_map.png
##
## The printed report matters as much as the picture: a node silently missing
## because its placement title does not match a catalogue entry is very hard to
## spot on a screen with ten circles on it, and impossible to spot if you are
## only looking at whether the render succeeded.

const SETTLE_FRAMES: int = 30

var _frames: int = 0
var _out_path: String = "frontier_map.png"
var _select_title: String = ""
var _map: Node = null
## Fourth arg: open the contextual drawer on a node, so the overlay can be
## reviewed without driving the map by hand. "signal" as a fifth arg opens it
## on the next-cycle tab instead of Activity.
var _drawer_node: String = ""
var _drawer_tab: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_path = args[0]
	# Second arg selects a node by title, so a shot can show the panel filled in
	# for a specific prototype rather than always the first.
	# "-" means "no selection" - an empty string argument is silently dropped by
	# some shells, which shifts every argument after it.
	if args.size() > 1 and args[1] != "-":
		_select_title = args[1]

	if args.size() > 3 and args[3] != "-":
		_drawer_node = args[3]
	if args.size() > 4 and args[4] == "signal":
		_drawer_tab = 1

	var packed: PackedScene = load("res://ramon/FrontierMap.tscn") as PackedScene
	if packed == null:
		push_error("could not load FrontierMap.tscn")
		quit(1)
		return
	_map = packed.instantiate()
	# Third arg opens a SUB-MAP directly, so each one can be reviewed without
	# clicking through the overview first. Assigned before the node enters the
	# tree, because the screen builds itself in _ready().
	if args.size() > 2 and args[2] != "-":
		var sub: Resource = load(args[2])
		if sub != null:
			_map.set("layout", sub)
	root.add_child(_map)
	set_current_scene(_map)


func _report() -> void:
	if _map == null:
		return
	var titles: Variant = _map.get("_placed_titles")
	var nodes: Variant = _map.get("_nodes")
	print("placed nodes: %d" % (nodes as Array).size())
	print("route order:  %s" % ", ".join(titles as PackedStringArray))
	print("selected:     %s" % str(_map.get("_selected_title")))

	var layout: Variant = _map.get("layout")
	var catalogue: Variant = _map.get("catalogue")
	var catalogue_titles := PackedStringArray()
	for entry in (catalogue as MenuCatalogue).entries:
		if entry != null:
			catalogue_titles.append(entry.title)
	for placement in (layout as FrontierLayout).placements:
		if placement == null:
			continue
		var backed: bool = catalogue_titles.has(placement.entry_title)
		print("  %-16s state=%d category=%d %s" % [
			placement.entry_title, placement.state, placement.category,
			"catalogue" if backed else "STANDALONE",
		])


## Must return bool - SceneTree._process's signature is `(float) -> bool`, and
## returning true QUITS the tree. Same trap `_shot2.gd` documents.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_report()
		if _select_title != "":
			_map.call("_select", _select_title)
		if _drawer_node != "":
			_map.call("_open_activity", _drawer_node, _drawer_tab)
	if _frames < SETTLE_FRAMES:
		return false

	var image: Image = root.get_texture().get_image()
	var absolute: String = ProjectSettings.globalize_path("res://ramon/Menu/" + _out_path)
	var err: int = image.save_png(absolute)
	print("saved %s (%d)" % [absolute, err])
	quit(0)
	return true
