extends SceneTree

## Where the chicken pen's frame actually goes. It runs at about ten frames a second, and
## that is true with the sky and clouds removed entirely, so it is not the lighting.
##
## MEASURED AS SEQUENTIAL BLOCKS, which is normally the wrong method - run-to-run drift of
## a millisecond or two swamps small differences. It is fine here precisely because nothing
## being looked for is small: a frame is 95 ms and the question is which tens of
## milliseconds belong to whom.
##
## Each stage turns something off and KEEPS it off, so the last stage is the floor.

var _stages: Array = []
var _stage: int = 0
var _f: int = 0
var _total: float = 0.0
var _n: int = 0
var _scene: Node


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_stages = [
		["everything on", Callable()],
		["- 12 chicken walkers", _kill_chickens],
		["- the pig", _kill_pig],
		["- the voxel rock", _kill_rock],
		["- the cat and Mithra", _kill_others],
	]


func _kill_chickens() -> void:
	var flock: Node = _scene.get_node_or_null("Chickens")
	if flock == null:
		return
	for bird in flock.get_children():
		bird.set_process_mode(Node.PROCESS_MODE_DISABLED)
		for part in bird.get_children():
			if part is Node4D and part.has_method("set_visible"):
				part.visible = false


func _kill_pig() -> void:
	var nike: Node = _scene.get_node_or_null("World/Nike")
	if nike != null:
		nike.set_process_mode(Node.PROCESS_MODE_DISABLED)
		nike.get_node("Hide").visible = false


func _kill_rock() -> void:
	var rock: Node = _scene.get_node_or_null("World/MiningRock")
	if rock != null:
		rock.set_process_mode(Node.PROCESS_MODE_DISABLED)
		if rock is Node4D:
			(rock as Node4D).visible = false


func _kill_others() -> void:
	for path in ["World/Cat", "World/RedCat", "Mithra", "World/Trym", "World/Keeper"]:
		var node: Node = _scene.get_node_or_null(path)
		if node != null:
			node.set_process_mode(Node.PROCESS_MODE_DISABLED)
			if node is Node4D:
				(node as Node4D).visible = false


func _process(delta: float) -> bool:
	_f += 1
	# Ten frames of settle after each change, then thirty of measurement.
	if _f > 10:
		_total += delta
		_n += 1
	if _f < 40:
		return false
	print("%-24s %6.2f ms" % [String(_stages[_stage][0]), _total / maxf(float(_n), 1.0) * 1000.0])
	_stage += 1
	if _stage >= _stages.size():
		return true
	var fn: Callable = _stages[_stage][1]
	if fn.is_valid():
		fn.call()
	_f = 0
	_total = 0.0
	_n = 0
	return false
