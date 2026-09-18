extends SceneTree

## Captures the controlled pair for the deck's "the verbs survive" claim, from
## the first gate of the 4x4 maze.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --resolution 1920x1080 \
##       --script res://ramon/PhaseMaze/_capture_gate.gd
##
## NOT with --headless - no rendering device means every shot is blank.
##
##   1  gate_closed   Standing in cell PATH[4] at the spawn w of 0, facing the
##                    gate. The wall is solid: the route is blocked.
##   2  gate_open     Identical position and facing, w moved to the gate's own
##                    window (-6). The same wall now has a doorway in it.
##
## The player is TELEPORTED rather than walked. Driving player.gd's polled input
## across a maze is a long chain of things that can go wrong for no gain - the
## claim is about what the slice contains, not about pathfinding, and teleporting
## guarantees the two frames share a camera exactly.
##
## The player's own PositionLabel is deliberately LEFT VISIBLE. It prints live w,
## so the pair carries its own proof that the only thing that changed is w - and
## per the Lab board's own cue, readable debug language is part of the identity
## rather than something to hide before showing anyone.

const OUT_DIR := "D:/temp_docs/deck_shots/"
const SETTLE_SECONDS := 1.5
const AFTER_TELEPORT := 0.6

## Gate 0 sits on the PATH[4]->PATH[5] edge with its w window centred here.
## Both values are read back off the builder at runtime rather than trusted.
var _gate_index: int = 0

var _root_node: Node = null
var _player: Node = null
var _builder: Node = null
var _stand: Vector4 = Vector4()
var _yaw: float = 0.0
var _gap_w: float = 0.0
var _elapsed: float = 0.0
var _step: int = 0
var _step_started: float = 0.0
var _shots: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var packed: PackedScene = load("res://ramon/PhaseMaze/phase_maze.tscn")
	if packed == null:
		printerr("CAPTURE: could not load phase_maze.tscn")
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)

	_player = _root_node.get_node_or_null("MazeWorld/Player")
	_builder = _root_node.get_node_or_null("MazeWorld/MazeBuilder")
	if _player == null or _builder == null:
		printerr("CAPTURE: expected MazeWorld/Player and MazeWorld/MazeBuilder")
		quit(1)
		return

	# MazeHud's five-line rule text is useful in play and clutter at slide size.
	# The player's own PositionLabel stays: it is the frame's proof that w is the
	# only thing that changed between the pair.
	for name in ["ReturnButton", "MazeHud"]:
		var n: Node = _root_node.get_node_or_null(name)
		if n != null and "visible" in n:
			n.visible = false

	var path: Array = _builder.get("PATH")
	var gate_after: Array = _builder.get("GATE_AFTER_PATH_INDEX")
	var gate_w: Array = _builder.get("GATE_GAP_W")
	if path == null or gate_after == null or gate_w == null:
		printerr("CAPTURE: could not read PATH / gate tables off the builder")
		quit(1)
		return

	var i: int = int(gate_after[_gate_index])
	_gap_w = float(gate_w[_gate_index])
	var cell_a: Vector2i = path[i]
	var cell_b: Vector2i = path[i + 1]
	var a: Vector2 = _builder.call("_cell_center", cell_a)
	var b: Vector2 = _builder.call("_cell_center", cell_b)

	# Stand in cell A, backed off toward its own centre, looking at the shared edge.
	var forward: Vector2 = (b - a).normalized()
	_yaw = atan2(-forward.x, -forward.y)
	var stand_xz: Vector2 = a - forward * 1.1
	_stand = Vector4(stand_xz.x, 1.0, stand_xz.y, 0.0)

	print("CAPTURE: gate %d on edge %s->%s, window w=%+.1f, standing (%.2f, %.2f)" % [
		_gate_index, cell_a, cell_b, _gap_w, stand_xz.x, stand_xz.y])


func _process(delta: float) -> bool:
	_elapsed += delta
	var in_step: float = _elapsed - _step_started

	match _step:
		0:
			if in_step >= SETTLE_SECONDS:
				_place(0.0)
				_advance()
		1:
			if in_step >= AFTER_TELEPORT:
				_shot("04_gate_closed.png")
				_advance()
		2:
			_place(_gap_w)
			_advance()
		3:
			if in_step >= AFTER_TELEPORT:
				_shot("05_gate_open.png")
				_advance()
		4:
			print("CAPTURE: wrote %d shots to %s" % [_shots.size(), OUT_DIR])
			quit(0)
			return true

	return false


func _advance() -> void:
	_step += 1
	_step_started = _elapsed


func _place(w: float) -> void:
	_player.global_position = Vector4(_stand.x, _stand.y, _stand.z, w)
	_player.global_basis = Basis4D.from_zx(_yaw)
	if "velocity" in _player:
		_player.velocity = Vector4()


func _shot(file_name: String) -> void:
	var texture: ViewportTexture = root.get_texture()
	if texture == null:
		printerr("CAPTURE: no viewport texture - headless by mistake?")
		return
	var image: Image = texture.get_image()
	if image == null:
		printerr("CAPTURE: null image for " + file_name)
		return
	image.save_png(OUT_DIR + file_name)
	_shots.append(file_name)
	var p: Vector4 = _player.global_position
	print("CAPTURE: %s | %dx%d | player w=%+.2f" % [
		file_name, image.get_width(), image.get_height(), p.w])
