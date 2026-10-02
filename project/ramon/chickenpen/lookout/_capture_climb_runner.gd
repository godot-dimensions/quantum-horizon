extends SceneTree

## A chipmunk climbing its tree, from the side, for checking it is on the bark and not off it.
## Saves res://smoke_test_output/climb_<n>.png and prints how far its feet are from the
## trunk's surface.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_capture_climb_runner.gd

var _room: Node
var _lookout: Node
var _t: float = 0.0
var _n: int = 0
var _cam: Camera4D
var _chip: Node4D
var _tree: Node4D


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", "user://lookout_journal_climb_test.cfg")
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _t < 3.0:
		return false
	if _chip == null:
		for child in _room.get_node("UI").get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		_chip = (_lookout.get("chipmunks") as Array)[0]
		_tree = (_lookout.get("wood") as Node4D).get("tree")
		_chip.call("perform", "climb")
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 0.7)
		_room.add_child(_cam)
		_cam.make_current()
		_t = 3.0
	# Side on to wherever it is on the trunk, a couple of metres off.
	var c: Vector4 = _tree.call("trunk_at", _chip.global_position.y)
	var out: Vector4 = _chip.global_position - c
	out.y = 0.0
	var side := Vector4(-out.z, 0.0, out.x, 0.0).normalized()
	var eye: Vector4 = c + side * 2.4 + Vector4(0.0, 0.3, 0.0, 0.0)
	_cam.global_position = eye
	var dv: Vector4 = _chip.global_position - eye
	_cam.global_basis = Basis4D.from_zx(atan2(-dv.x, -dv.z)) * Basis4D.from_yz(atan2(dv.y, Vector2(dv.x, dv.z).length()))
	if _t > 3.6 + 0.9 * float(_n):
		var gap: float = Vector2(out.x, out.z).length() - float(_tree.call("trunk_radius_at", _chip.global_position.y))
		print("      climb %d: %.2f m up, feet %.3f m off the bark, state %d" % [_n, _chip.global_position.y - _tree.global_position.y, gap, int(_chip.get("state"))])
		root.get_texture().get_image().save_png("res://smoke_test_output/climb_%d.png" % _n)
		_n += 1
		if _n >= 5:
			print("CLIMB DONE")
			return true
	return false
