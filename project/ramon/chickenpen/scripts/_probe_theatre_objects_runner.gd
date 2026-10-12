extends SceneTree
## What is drawn in the cinema at a few moments: every MeshInstance4D visible in the tree,
## counted by where it hangs (its first three path parts under the cinema), with its
## tetrahedra. For finding what makes a slide cost more objects than it should.
##
## Windowed or headless (it only counts). Args after --: at=<seconds into slide I> (several,
## comma separated), default 1,6.

var _root: Node
var _show: Node
var _seat: Node
var _player: CharacterBody4D
var _f := 0
var _at: Array = [1.0, 6.0]
var _done: Array = []


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("at="):
			_at = []
			for s in a.substr(3).split(","):
				_at.append(float(s))
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _f == 1:
		_show = _root.get_node("Show")
		_seat = _root.get_node("UI/Seat")
		_player = _root.get_node("Player") as CharacterBody4D
		_show.set("opening_seconds", 2.0)
		_seat.set("sit_seconds", 0.3)
		return false
	if _f == 3:
		var stage: Node4D = _root.get_node("Stage") as Node4D
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.set_physics_process(false)
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18, lerpf(top.z, foot.z, 0.5), 0.0)
		return false
	if _f > 6000:
		print("OBJECTS FAIL: never reached slide I")
		quit(1)
		return true
	if bool(_seat.call("is_offering")) and not bool(_seat.call("is_seated")):
		_seat.call("sit")
	var act: int = int(_show.call("current_act"))
	if act == -1 and bool(_seat.call("is_settled")) and not _done.has(-1.0):
		_done.append(-1.0)
		_count("seated, before slide I")
	if act == 0:
		var phase: float = float(_show.get("_phase"))
		for at in _at:
			if phase >= at and not _done.has(at):
				_done.append(at)
				_count("slide I at %.1f s" % at)
	if act > 0 or _done.size() > _at.size():
		quit()
		return true
	return false


func _count(what: String) -> void:
	var groups: Dictionary = {}
	var total := 0
	var tets := 0
	for node in _root.find_children("*", "MeshInstance4D", true, false):
		var mi := node as MeshInstance4D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var path: String = String(_root.get_path_to(mi))
		var parts: PackedStringArray = path.split("/")
		var key: String = "/".join(parts.slice(0, mini(3, parts.size() - 1)))
		if not groups.has(key):
			groups[key] = [0, 0]
		groups[key][0] += 1
		var n := 0
		if mi.mesh is ArrayTetraMesh4D:
			n = (mi.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		groups[key][1] += n
		total += 1
		tets += n
	print("\n%s: %d visible meshes, %d tetrahedra (render objects %d)" % [what, total, tets,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b): return groups[a][0] > groups[b][0])
	for k in keys:
		print("  %5d  %8d tets  %s" % [groups[k][0], groups[k][1], k])
