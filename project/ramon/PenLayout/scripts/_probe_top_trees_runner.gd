extends SceneTree

## Why the trees are gone from the map from above (7 Oct: the top view for the path dev log showed no trees, the
## 6 Oct one had them). The pen in the art look, an orthographic camera straight down over the middle, as
## _capture_pen_runner.gd's top shots are, and what each tree's culling says: shown or not, and by whom.
##
##   lab_run.sh windowed probe_top res://ramon/PenLayout/scripts/_probe_top_trees_runner.gd look=art

var _room: Node


func _initialize() -> void:
	root.unfocusable = true
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://probe_top_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _count(label: String) -> void:
	var trees: Node = _room.get_node("World/Trees")
	var shown: int = 0
	var all: int = 0
	var hidden_tree: int = 0
	for oak in trees.find_children("*", "Node4D", true, false):
		var t: Variant = oak.get("_tree")
		if t == null or not (t is Node4D):
			continue
		all += 1
		if (t as Node4D).visible and (oak as Node4D).is_visible_in_tree():
			shown += 1
		elif not (t as Node4D).visible:
			hidden_tree += 1
	print("TOP TREES %s: %d trees, %d shown, %d with their tree hidden" % [label, all, shown, hidden_tree])
	for ex in _room.find_children("*", "Node4D", true, false):
		if ex.has_method("_on_pre_render") and "_cull_on" in ex:
			var on: PackedByteArray = ex.get("_cull_on")
			var n: int = 0
			for b in on:
				n += 1 if b == 1 else 0
			print("TOP TREES %s: exploder %s culls %d, %d on (ready %s)" % [label, ex.name, on.size(), n, str(ex.get("_cull_ready"))])


func _run() -> void:
	await _wait(7.0)
	(_room.get_node("Player") as Node).set("input_enabled", false)
	await _count("eye")
	var cam := Camera4D.new()
	_room.add_child(cam)
	cam.projection_type = Camera4D.PROJECTION4D_ORTHOGRAPHIC
	cam.orthographic_size = 24.0
	cam.position = Vector4(-2.0, 120.0, 8.0, 0.0)
	cam.look_at(Vector4(-2.0, 0.0, 8.0, 0.0), Vector4(0, 0, -1, 0))
	cam.make_current()
	await _wait(1.0)
	print("TOP TREES camera basis x %s y %s z %s w %s fov4d %s" % [str(cam.global_basis.x), str(cam.global_basis.y), str(cam.global_basis.z),
		str(cam.global_basis.w), str(cam.get("field_of_view_4d"))])
	await _count("top")
	quit(0)
