extends SceneTree

## PathCreator's builder (PLAN.md step 79): F4 into build mode, then a scripted session through the
## builder's own mouse and key handling: pick a node and drag it, add a node joined to it, change
## its W on the wheel, split a route, cycle a route's W mode, undo, redo, save; the saved file read
## back and compared. It works on a copy of the yard's graph in user://, so the real graph files are
## never touched. Frames of the builder's view to res://smoke_test_output/pathcreator/builder/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_builder res://ramon/CreationLab/PathCreator/scripts/_capture_builder_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/builder/"
const COPY := "user://pathcreator_builder_test.tres"

var _g: Node
var _b: Control
var _fails: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _shot(what: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _mouse(kind: String, at: Vector2, button: int = MOUSE_BUTTON_LEFT, pressed: bool = true, shift: bool = false) -> void:
	var e: InputEvent
	if kind == "move":
		var mm := InputEventMouseMotion.new()
		mm.position = at
		e = mm
	else:
		var mb := InputEventMouseButton.new()
		mb.position = at
		mb.button_index = button
		mb.pressed = pressed
		mb.shift_pressed = shift
		e = mb
	_b.call("_gui_input", e)
	await process_frame


func _key(code: Key, ctrl: bool = false) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	k.ctrl_pressed = ctrl
	_b.call("_unhandled_key_input", k)
	await process_frame


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.0)
	# The yard's graph, copied, so the session never touches the real file.
	var net: Node = _g.get_node("YardNetwork")
	var copy: Resource = (net.get("graph") as Resource).duplicate(true)
	ResourceSaver.save(copy, COPY)
	copy = load(COPY)
	net.set("graph", copy)
	_g.get_node("WFieldNetwork").set("graph", null)
	await _wait(0.5)
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(-12.0, 0.05, -34.0, 0.0)
	await _wait(0.3)
	_g.call("set_build", true)
	_b = _g.get("builder")
	await _wait(0.6)
	_check(bool(_g.get("building")) and _b.visible, "F4's build mode is on")
	await _shot("builder_yard")
	var nodes_before: int = copy.nodes.size()
	# Pick the choice junction (node 2) and drag it two metres north.
	var j: Dictionary = copy.call("node", 2)
	var jp: Vector4 = j["pos"]
	var s0: Vector2 = _b.call("to_screen", jp.x, jp.z)
	await _mouse("move", s0)
	await _mouse("button", s0)
	var s1: Vector2 = _b.call("to_screen", jp.x, jp.z - 2.0)
	await _mouse("move", s1)
	await _mouse("button", s1, MOUSE_BUTTON_LEFT, false)
	var moved: Vector4 = copy.call("node", 2)["pos"]
	_check(absf(moved.z - (jp.z - 2.0)) < 0.3, "a node drags (z %.2f to %.2f)" % [jp.z, moved.z])
	# A new node joined from it, beside it; then its W up a metre on the wheel.
	await _mouse("move", _b.call("to_screen", jp.x + 3.0, jp.z - 2.0))
	await _key(KEY_N)
	_check(copy.nodes.size() == nodes_before + 1, "N adds a node")
	var new_id: int = int(copy.nodes.back()["id"])
	var np: Vector4 = copy.call("node", new_id)["pos"]
	var ns: Vector2 = _b.call("to_screen", np.x, np.z)
	for i in 4:
		await _mouse("button", ns, MOUSE_BUTTON_WHEEL_UP)
	_check(absf(float((copy.call("node", new_id)["pos"] as Vector4).w) - 1.0) < 0.01, "the wheel on a node sets its W (+1.00)")
	# Split the long corridor (between the second turn and the pen's fork).
	var a: Vector4 = copy.call("node", 5)["pos"]
	var c: Vector4 = copy.call("node", 6)["pos"]
	var mid: Vector2 = _b.call("to_screen", (a.x + c.x) * 0.5, (a.z + c.z) * 0.5)
	await _mouse("move", mid)
	var edges_before: int = copy.edges.size()
	await _key(KEY_X)
	_check(copy.edges.size() == edges_before + 1, "X splits a route with a chord")
	# The hovered route's W mode.
	await _mouse("move", _b.call("to_screen", (a.x + c.x) * 0.5 - 0.6, (a.z + c.z) * 0.5))
	await _key(KEY_M)
	var modes: Array = []
	for e in copy.edges:
		modes.append(String(e["w_mode"]))
	_check("here" in modes, "M cycles the hovered route's W mode")
	await _shot("builder_edited")
	# Undo the W mode, redo it.
	await _key(KEY_Z, true)
	var after_undo: int = 0
	for e in copy.edges:
		if String(e["w_mode"]) == "here":
			after_undo += 1
	await _key(KEY_Y, true)
	var after_redo: int = 0
	for e in copy.edges:
		if String(e["w_mode"]) == "here":
			after_redo += 1
	_check(after_undo == 0 and after_redo == 1, "Ctrl+Z undoes, Ctrl+Y redoes")
	# Save, read back.
	await _key(KEY_S, true)
	var back: Resource = ResourceLoader.load(COPY, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(back != null and back.nodes.size() == copy.nodes.size() and back.edges.size() == copy.edges.size(), "Ctrl+S saves the graph (%d nodes, %d edges)" % [copy.nodes.size(), copy.edges.size()])
	# The slice through W from above.
	await _key(KEY_BRACKETRIGHT)
	await _key(KEY_BRACKETRIGHT)
	await _key(KEY_BRACKETRIGHT)
	await _key(KEY_BRACKETRIGHT)
	_check(absf(float(_b.get("slice_w")) - 1.0) < 0.01, "] moves the slice through W")
	await _shot("builder_slice_w1")
	_g.call("set_build", false)
	await _wait(0.4)
	_check(not bool(_g.get("building")), "F4 again walks")
	await _shot("walking_again")
	print("BUILDER %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
