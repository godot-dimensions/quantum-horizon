extends SceneTree

## Drop a bird inside the fence: does anything move it afterwards?
##
## This is the one the earlier tests all walked past. They called on_landed() directly,
## which is only half of what happens for real - the pen's return volume ALSO runs, and it
## was rewriting the home of every third bird to a spot by the coop. Containment then tows
## it there. Going through the real volume is the whole point of this test.
##
## Every bird is checked, not a sample, because the fault keyed off chicken_id and a
## sample of one had two chances in three of looking fine.

var _root: Node
var _f := 0
var _fails: Array = []
var _dropped := {}
var _homes := {}


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var mgr: Node = _root.get_node("Chickens")
	var agents: Array = mgr.get("agents")

	if _dropped.is_empty():
		_root.get_node("Player").position = Vector4(40.0, 1.3, 40.0, 0.0)
		var spots := [Vector4(2.4, 0.0, -12.6, 0.0), Vector4(-2.2, 0.0, -9.8, 0.0),
			Vector4(1.1, 0.0, -13.4, 0.0), Vector4(-1.6, 0.0, -11.2, 0.0)]
		for i in 4:
			var agent: Node = agents[i]
			var body: Node4D = agent.get_parent() as Node4D
			var host: Node4D = body.get_parent() as Node4D
			# Carried and put down, the way a throw delivers one - then the pen's own
			# volume does the counting, not this test.
			agent.call("on_caught")
			agent.call("on_released")
			body.position = spots[i] - host.global_position
			_dropped[int(agent.get("chicken_id"))] = body.global_position
		print("\n   dropped four birds inside the fence")
		return false

	if _f < 400: return false
	print("   %6s %10s %10s" % ["id", "moved", "home moved"])
	var worst: float = 0.0
	var worst_home: float = 0.0
	for agent in agents:
		var id: int = int(agent.get("chicken_id"))
		if not _dropped.has(id):
			continue
		var body: Node4D = agent.get_parent() as Node4D
		var from: Vector4 = _dropped[id]
		var host: Node4D = body.get_parent() as Node4D
		var home: Vector4 = (agent.get("home_position") as Vector4) \
			+ (host.global_position if host != null else Vector4.ZERO)
		var moved: float = Vector2(body.global_position.x - from.x,
			body.global_position.z - from.z).length()
		var home_moved: float = Vector2(home.x - from.x, home.y - from.z).length()
		home_moved = Vector2(home.x - from.x, home.z - from.z).length()
		worst = maxf(worst, moved)
		worst_home = maxf(worst_home, home_moved)
		print("   %6d %10.2f %10.2f   %s" % [id, moved, home_moved, agent.call("describe")])
	_check("none was towed off its landing spot", worst < 1.6,
		"the furthest strayed %.2f in five seconds" % worst)
	_check("and nothing rewrote where home is", worst_home < 0.35,
		"the furthest home moved %.2f from where the bird came down" % worst_home)
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
