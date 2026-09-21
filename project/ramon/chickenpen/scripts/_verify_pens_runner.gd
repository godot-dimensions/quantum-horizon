extends SceneTree
## Do all three pens load, build their avatars, stand on the ground and place a camera?
var _scenes := ["chickenpen_kirbywalker", "chickenpen_human", "chickenpen_proceduralwalker"]
var _i := 0
var _root: Node
var _f := 0
func _initialize() -> void:
	_load()
func _load() -> void:
	if _root != null: _root.queue_free()
	_root = load("res://ramon/chickenpen/%s.tscn" % _scenes[_i]).instantiate()
	root.add_child(_root); current_scene = _root
	_f = 0
func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var player := _root.get_node_or_null("Player") as CharacterBody4D
	var avatar := _root.get_node_or_null("Player/Avatar") as Node4D
	var cam := _root.get_node_or_null("Player/CameraRig/Pitch/Camera4D") as Camera4D
	var blocks := 0
	if avatar:
		var stack: Array = [avatar]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance4D: blocks += 1
			for c in n.get_children(): stack.append(c)
	print("%-24s player y %.2f on_floor %s | avatar blocks %d | camera back %.2f" % [
		_scenes[_i], player.position.y if player else -999.0,
		str(player.is_on_floor()) if player else "?", blocks,
		cam.position.z if cam else -1.0])
	_i += 1
	if _i >= _scenes.size(): return true
	_load()
	return false
