extends SceneTree

## Does a penned chicken use the henhouse - in at the door, or up on the roof?
##
## Both branches are behind a coin flip and a long timer, so this forces the chance to
## certainty and shortens the stay. What it is checking is that the cycle happens and
## comes back, that a roosting bird is ON the roof rather than floating over it, and that
## none of the guards undo it - the stuck detector in particular would have teleported a
## nesting bird back out for the crime of sitting still.

var _root: Node
var _f := 0
var _fails: Array = []
var _agent: Node
var _body: Node4D
var _coop: Node4D
var _seen: Array = []
var _roof_y: float = 0.0
var _peak: float = -99.0
var _hidden := false


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _roof(of: Node) -> float:
	var top: float = -1e9
	for child in of.get_children():
		if child is MeshInstance4D and (child as MeshInstance4D).mesh is BoxTetraMesh4D:
			var m: MeshInstance4D = child
			top = maxf(top, m.global_position.y + (m.mesh as BoxTetraMesh4D).size.y * 0.5)
		top = maxf(top, _roof(child))
	return top


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _agent == null:
		_root.get_node("Player").position = Vector4(40.0, 1.3, 40.0, 0.0)
		_coop = _root.get_node("Pen/Coop")
		_roof_y = _roof(_coop)
		_agent = (_root.get_node("Chickens").get("agents") as Array)[5]
		_body = _agent.get_parent() as Node4D
		_agent.set("coop_chance", 1.0)
		_agent.set("coop_min", 1.2); _agent.set("coop_max", 1.6)
		_agent.set("wander_seconds_min", 0.4); _agent.set("wander_seconds_max", 0.6)
		# Deliver it into the pen, near the coop so the walk is short.
		_agent.call("on_caught"); _agent.call("on_released")
		var host: Node4D = _body.get_parent() as Node4D
		_body.position = Vector4(0.6, 0.0, -12.6, 0.0) - host.global_position
		_agent.call("on_landed", true)
		print("\n   the coop's roof is at y %.2f" % _roof_y)
		return false

	var now: String = ["IDLE","WANDER","ALERT","EVADE","CARRIED","THROWN","PENNED",
		"RECOVERING","TO_COOP","NESTING","ROOSTING"][int(_agent.get("state"))]
	if _seen.is_empty() or _seen[-1] != now:
		_seen.append(now)
		print("   %5.1fs  %-10s  y %.2f  %s" % [float(_f) / 60.0, now,
			_body.global_position.y, "hidden" if not _body.visible else "out"])
	if _f % 120 == 0:
		var gap: Vector4 = _coop.global_position - _body.global_position
		print("      %5.1fs %-9s %.2f from the coop, halted %s, heading %.2f"
			% [float(_f) / 60.0, now, Vector2(gap.x, gap.z).length(),
				_body.get_node("Walker").get("halted"),
				_body.get_node("Walker").get("steer_heading")])
	if now == "ROOSTING":
		_peak = maxf(_peak, _body.global_position.y)
	if now == "NESTING" and not _body.visible:
		_hidden = true
	# FORCE THE OTHER BRANCH. Which of the two it does is a coin flip, so left alone a run
	# exercises one of them and reports the other as untested by saying nothing at all -
	# and hiding a bird is the half that can strand it invisible.
	if now == "TO_COOP" and _seen.count("TO_COOP") >= 2:
		_agent.set("_roosting", false)
	if now == "TO_COOP" or now == "NESTING" or now == "ROOSTING":
		if bool(_agent.call("can_be_caught")):
			_fails.append("catchable while using the coop")

	if _f < 2400: return false
	print("\n   states in order: %s" % [_seen])
	_check("it went to the coop", _seen.has("TO_COOP"), "%s" % [_seen])
	_check("it did both", _seen.has("NESTING") and _seen.has("ROOSTING"),
		"nested: %s, roosted: %s" % [_seen.has("NESTING"), _seen.has("ROOSTING")])
	if _seen.has("ROOSTING"):
		_check("and sat ON the roof, not over it", absf(_peak - _roof_y) < 0.35,
			"it reached y %.2f against a roof at %.2f" % [_peak, _roof_y])
	if _seen.has("NESTING"):
		_check("it was out of sight inside", _hidden, "hidden while nesting")
	_check("it came back out", _seen.count("PENNED") >= 2 and _body.visible,
		"ends %s and %s" % [_seen[-1], "visible" if _body.visible else "hidden"])
	_check("never recovered out of the coop", not _seen.has("RECOVERING"),
		"the stuck guard left it alone")
	_check("never catchable while in there",
		not _fails.has("catchable while using the coop"), "stayed off limits")
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
