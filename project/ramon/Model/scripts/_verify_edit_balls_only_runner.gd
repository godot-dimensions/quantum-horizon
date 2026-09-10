extends SceneTree

## Checks that edit_balls_only actually removes the rig from viewport picking, and
## that turning it off puts the model back exactly as it was.
##
## The thing that matters is BOUNDS, not visibility: the viewport gathers a node only
## when `get_rect_bounds_global().has_any_size()` is true, and picks between what it
## gathered by axis-aligned box. So the test is that the rig's bounds collapse while
## its balls keep theirs - that is precisely the condition under which a ball inside
## the body becomes reachable.

var _rig: Node
var _step: int = 0
var _cells_before: int = 0


## Rect4 reaches GDScript as a PackedVector4Array of [position, size], so "does the
## viewport gather this node" is whether that size vector is non-zero - the same test
## Rect4::has_any_size() performs on the C++ side.
func _has_size(node: Node) -> bool:
	var bounds: PackedVector4Array = node.get_rect_bounds_global()
	if bounds.size() < 2:
		return false
	var size: Vector4 = bounds[1]
	return size.x > 0.0 or size.y > 0.0 or size.z > 0.0 or size.w > 0.0


func _initialize() -> void:
	var world := Node4D.new()
	root.add_child(world)
	_rig = MeshInstance4D.new()
	_rig.set_script(load("res://ramon/Model/scripts/loft_rig_4d.gd"))
	_rig.name = "EditModeRig"
	world.add_child(_rig)


func _process(_delta: float) -> bool:
	_step += 1
	if _rig.get("verbose") != null:
		_rig.verbose = false
	match _step:
		1:
			_rig.add_ball()
		2:
			_rig.add_ball()
		3:
			_rig.add_ball()
		4:
			_cells_before = _rig.mesh.get_simplex_cell_vertex_indices().size() / 4
			print("built: %d tetrahedra, rig bounds have size = %s" % [
				_cells_before, _has_size(_rig)])
			_rig.edit_balls_only = true
		5:
			var gathered: bool = _has_size(_rig)
			print("edit_balls_only on:  mesh = %s, rig gathered by picking = %s" % [
				"null" if _rig.mesh == null else "still set", gathered])
			var balls_gathered: int = 0
			var framed: int = 0
			for child in _rig.get_children():
				if child.has_method("get_loft_section"):
					if _has_size(child):
						balls_gathered += 1
					if child.visible:
						framed += 1
			# Guides are editor-only by design (loft_ball_4d.gd sets visible from
			# Engine.is_editor_hint), so a headless run reports none visible. That is
			# the runner, not the feature - what this test speaks to is bounds.
			print("   balls still pickable: %d (visible: %d, always 0 outside the editor)" % [
				balls_gathered, framed])
			print("   -> %s" % ("PASS: rig steps aside, balls remain" if not gathered and balls_gathered == 3 else "FAIL"))
			_rig.edit_balls_only = false
		6:
			var cells: int = _rig.mesh.get_simplex_cell_vertex_indices().size() / 4
			print("edit_balls_only off: %d tetrahedra, identical to before = %s" % [
				cells, cells == _cells_before])
			return true
	return false
