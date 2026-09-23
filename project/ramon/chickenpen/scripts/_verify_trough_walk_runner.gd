extends SceneTree

## Does a bird actually WALK to the trough?
##
## The earlier check proved the feeder moves a chicken's home_position onto the trough and
## leaves its w alone. That is the mechanism, not the result: a bird whose home has moved
## and which then stands exactly where it was looks identical in a single frame. This one
## watches the distance close over time.
##
## It samples every bird in range rather than one, because a single chicken can spend a
## long stretch idling by design - idle_seconds_max is 3.5 - and one unlucky pick would
## read as a broken feeder.

var _scene: Node
var _up: Node
var _mgr: Node
var _f: int = 0
var _started: bool = false
var _watch: Array = []
var _first: Array[float] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_up = _scene.get_node("Pen/Upgrades")
	_mgr = _scene.get_node("Chickens")


func _trough() -> Node4D:
	return _up.get_node_or_null("Feeder1") as Node4D


func _gap(agent: Node) -> float:
	var bird: Node4D = agent.get_parent() as Node4D
	var d: Vector4 = bird.global_position - _trough().global_position
	return Vector2(d.x, d.z).length()


func _process(_d) -> bool:
	_f += 1
	if _f < 40:
		return false
	if not _started:
		_started = true
		_scene.get_node("UI/Inventory").call("add_item", "found_gold")
		assert(bool(_up.call("buy", "feeder")), "could not buy the trough")
		for agent in _mgr.get("agents"):
			if not is_instance_valid(agent):
				continue
			var gap: float = _gap(agent)
			# In range of the trough, and not already sitting on it.
			if gap < float(_up.get("draw_radius")) and gap > 2.0:
				_watch.append(agent)
				_first.append(gap)
		print("trough up; watching %d birds in range" % _watch.size())
		_f = 0
		return false
	if _f % 400 != 0:
		return _f > 1700
	var closed: int = 0
	var total: float = 0.0
	for i in _watch.size():
		var now: float = _gap(_watch[i])
		total += _first[i] - now
		if now < _first[i] - 0.5:
			closed += 1
	print("after %4d frames: %d of %d have closed on it, mean gain %+.2f" % [
		_f, closed, _watch.size(), total / maxf(float(_watch.size()), 1.0)])
	if _f <= 1700:
		return false
	print("VERDICT: %s" % ("they walk to it" if closed > _watch.size() / 2
		else "they are NOT converging - the feeder moves homes but birds stay put"))
	return true
