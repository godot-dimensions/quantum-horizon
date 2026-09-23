extends SceneTree

## The nugget-for-a-trough exchange, end to end: gold buys one, the gold leaves the belt,
## the trough lands where the birds actually are, and a bird near it changes its mind
## about where home is.
##
## The last of those is the one worth checking. A feeder that appears and does nothing
## looks identical to a feeder that works, right up until you stand and watch a chicken
## for a minute.

var _scene: Node
var _inv: Node
var _up: Node
var _mgr: Node
var _pen: Node4D
var _f: int = 0
var _stage: int = 0
var _watched: Node
var _home_before := Vector4.ZERO


func _initialize() -> void:
	_scene = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_inv = _scene.get_node("UI/Inventory")
	_up = _scene.get_node("Pen/Upgrades")
	_mgr = _scene.get_node("Chickens")
	_pen = _scene.get_node("Pen")


func _process(_d) -> bool:
	_f += 1
	if _f < 30:
		return false
	match _stage:
		0:
			print("starts with none: %s   can pay with empty belt: %s" % [
				_up.call("feeder_count") == 0, str(_up.call("can_pay"))])
			_inv.call("add_item", "found_gold")
			print("gold in belt: %s" % str(_up.call("can_pay")))
			# Pick a loose bird to watch, and remember where it thinks home is.
			for agent in _mgr.get("agents"):
				var bird: Node4D = agent.get_parent() as Node4D
				var gap: Vector4 = bird.global_position - _pen.global_position
				if Vector2(gap.x, gap.z).length() < 11.0:
					_watched = agent
					_home_before = agent.get("home_position")
					break
			print("watching a bird whose home is %v" % _home_before)
			_stage = 1
			_f = 0
		1:
			var ok: bool = bool(_up.call("buy", "feeder"))
			print("BOUGHT: %s   troughs now %d   gold still in belt: %s" % [
				str(ok), int(_up.call("feeder_count")),
				str(_inv.call("has_item", "found_gold"))])
			print("buying again with no gold: %s" % str(_up.call("buy", "feeder")))
			var trough: Node4D = _up.get_node_or_null("Feeder1") as Node4D
			if trough != null:
				var out: Vector4 = trough.global_position - _pen.global_position
				print("trough sits %.1f from the pen centre (gather_radius %.1f)" % [
					Vector2(out.x, out.z).length(), float(_up.get("gather_radius"))])
			_stage = 2
			_f = 0
		2:
			if _f < 20:
				return false
			var after: Vector4 = _watched.get("home_position") if _watched != null else Vector4.ZERO
			var moved: float = Vector2(after.x - _home_before.x, after.z - _home_before.z).length()
			print("WATCHED BIRD: home moved %.2f, and its w is unchanged: %s" % [
				moved, is_equal_approx(after.w, _home_before.w)])
			# And it should now be heading for the trough, not the pen centre.
			var trough2: Node4D = _up.get_node_or_null("Feeder1") as Node4D
			if trough2 != null:
				var d: Vector4 = after - trough2.global_position
				print("its new home is %.2f from the trough" % Vector2(d.x, d.z).length())
			return true
	if _f > 400:
		print("TIMED OUT in stage %d" % _stage)
		return true
	return false
