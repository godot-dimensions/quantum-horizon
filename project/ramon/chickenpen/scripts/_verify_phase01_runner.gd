extends SceneTree
## Phase 01 items 2 and 7, and Phase 02 item 9: does the copied pen scene behave like its
## source, and does the extracted chicken still walk on its own?
var _stage := 0
var _root: Node
var _f := 0
var _start := Vector4.ZERO
func _initialize() -> void:
	_load("res://ramon/chickenpen/playable_world.tscn")
func _load(path: String) -> void:
	if _root != null: _root.queue_free()
	_root = load(path).instantiate()
	root.add_child(_root); current_scene = _root
	_f = 0
func _process(_d) -> bool:
	_f += 1
	if _f < 90: return false
	if _stage == 0:
		var player := _root.get_node_or_null("Player") as CharacterBody4D
		var avatar := _root.get_node_or_null("Player/Avatar") as Node4D
		var cam := _root.get_node_or_null("Player/CameraRig/Pitch/Camera4D") as Camera4D
		var gait := _root.get_node_or_null("Player/Gait")
		print("PEN  player on_floor %s y %.2f | avatar blocks %d | camera %s | gait %s | source %s" % [
			str(player.is_on_floor()), player.position.y,
			_count_meshes(avatar), str(cam != null and cam.current), str(gait != null),
			str(_root.get_meta("copied_from", "?"))])
		_stage = 1
		_load("res://ramon/chickenpen/chicken.tscn")
		return false
	# The chicken, standalone.
	var walker := _root.get_node_or_null("Walker")
	if _f == 90:
		_start = (_root as Node4D).position
		print("CHICKEN nodes %d | walker %s | legs %s" % [
			_root.get_child_count(), str(walker != null),
			str(walker.get("_legs").size()) if walker else "?"])
		return false
	if _f < 400: return false
	var moved: float = (_root as Node4D).position.distance_to(_start)
	print("CHICKEN wandered %.2f units in %d frames -> %s" % [moved, _f - 90,
		"WALKING" if moved > 0.2 else "NOT MOVING"])
	return true
func _count_meshes(n: Node) -> int:
	if n == null: return 0
	var c := 0
	var stack: Array = [n]
	while not stack.is_empty():
		var m: Node = stack.pop_back()
		if m is MeshInstance4D: c += 1
		for g in m.get_children(): stack.append(g)
	return c
