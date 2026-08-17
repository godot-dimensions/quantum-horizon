extends SceneTree

## Headless structural check for the Demo hub.
##
## The hub's gates and billboards are generated at runtime and deliberately not
## saved into the scene, so opening `hub.tscn` in a text editor tells you nothing
## about whether they were actually built. This instantiates the scene, walks the
## resulting tree and prints it, which is the only way to confirm the ring ran
## without opening the editor.
##
## The checks run on the first _process frame, not in _initialize(). Nodes added
## during _initialize() are not yet flagged as inside the tree, so _ready() has
## not fired and the ring has not built anything yet - checking there reports a
## false failure.
##
## Run with the editor CLOSED - two Godot processes touching the same project's
## .godot cache is what silently breaks @tool buttons in a running editor:
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe \
##       --headless --path project --script res://ramon/Demo/_verify_hub.gd

const DEFAULT_HUB := "res://ramon/Demo/hub.tscn"

var _hub: Node = null
var _failed: bool = false


## Scene to check, from user args after `--`. Defaults to the main hub:
##   ... --script res://ramon/Demo/_verify_hub.gd -- hub2.tscn
static func _hub_path() -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		return DEFAULT_HUB
	return "res://ramon/Demo/" + args[0]


func _initialize() -> void:
	var hub_path := _hub_path()
	print("checking: ", hub_path)
	var packed: PackedScene = load(hub_path)
	if packed == null:
		printerr("VERIFY: could not load ", hub_path)
		_failed = true
		return
	_hub = packed.instantiate()
	root.add_child(_hub)


func _process(_delta: float) -> bool:
	if _failed or _hub == null:
		quit(1)
		return true

	print("\n===== hub tree =====")
	_dump(_hub, 0)

	var ring: Node = _hub.get_node_or_null("GateRing")
	if ring == null:
		printerr("VERIFY: no GateRing node")
		quit(1)
		return true

	var gate_count := ring.get_child_count()
	print("\n===== summary =====")
	print("catalogue entries: ", ring.gates.size())
	print("gates generated:   ", gate_count)

	var billboards := 0
	var labels := 0
	var sprites := 0
	var frames := 0
	for gate in ring.get_children():
		var billboard := gate.get_node_or_null("Billboard")
		if billboard != null:
			billboards += 1
			for child in billboard.get_children():
				if child is Label3D:
					labels += 1
				elif child is Sprite3D:
					sprites += 1
		var frame := gate.get_node_or_null("Frame")
		if frame != null:
			frames += frame.get_child_count()
		var bb_pos := "none"
		if billboard != null:
			bb_pos = str(billboard.position)
		print("  %-26s gate=%s  sign=%s" % [gate.name, str(gate.position), bb_pos])

	print("billboards: %d   Label3D: %d   Sprite3D: %d   frame segments: %d"
		% [billboards, labels, sprites, frames])

	# Nothing is owned by the scene, so a saved hub.tscn must never contain the
	# generated nodes. Catching a regression here is cheaper than finding stale
	# geometry committed into the scene weeks later.
	var owned_leaks := 0
	for gate in ring.get_children():
		if gate.owner != null:
			owned_leaks += 1
	print("generated nodes wrongly owned by the scene: ", owned_leaks)

	if gate_count == 0 or billboards == 0 or frames == 0:
		printerr("VERIFY: FAILED - something did not generate")
		quit(1)
		return true
	if owned_leaks > 0:
		printerr("VERIFY: FAILED - generated nodes would be serialised into the scene")
		quit(1)
		return true
	print("VERIFY: OK")
	quit(0)
	return true


func _dump(node: Node, depth: int) -> void:
	var line := ""
	for i in depth:
		line += "  "
	line += "%s [%s]" % [node.name, node.get_class()]
	print(line)
	# Frame segments are numerous and identical; summarise rather than list.
	if node.name == "Frame":
		var pad := ""
		for i in depth + 1:
			pad += "  "
		print(pad, "... %d segments" % node.get_child_count())
		return
	for child in node.get_children():
		_dump(child, depth + 1)
