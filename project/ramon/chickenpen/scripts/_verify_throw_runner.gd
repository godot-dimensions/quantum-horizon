extends SceneTree

## How far does a thrown chicken actually go, how high, and what happens when it misses?
##
## A miss must leave a loose, catchable chicken and must not score. That is the rule that
## makes the throw a decision rather than a formality.

var _root: Node
var _f := 0
var _t0 := 0
var _stage := 0
var _mgr: Node
var _fence: Node
var _catcher: Node
var _player: Node4D
var _bird: Node
var _body: Node4D
var _from := Vector4.ZERO
var _peak := 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _mgr == null:
		_mgr = _root.get_node("Chickens")
		_fence = _root.get_node("Pen/Fence")
		_catcher = _root.get_node("Player/Catcher")
		_player = _root.get_node("Player")
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0

	match _stage:
		0:
			# Stand well away from the pen and throw into open ground: a deliberate miss.
			_bird = (_mgr.get("agents") as Array)[0]
			_body = _bird.get_parent() as Node4D
			_player.position = Vector4(0.0, 1.3, 12.0, 0.0)
			_stage = 1
			_t0 = Time.get_ticks_msec()
		1:
			if elapsed < 0.5:
				return false
			_catcher.call("_catch", _bird)
			_stage = 2
			_t0 = Time.get_ticks_msec()
		2:
			if elapsed < 0.5:
				return false
			_from = _body.global_position
			_peak = _from.y
			_catcher.call("_release", true)
			_stage = 3
			_t0 = Time.get_ticks_msec()
		3:
			_peak = maxf(_peak, _body.global_position.y)
			if elapsed < 3.0:
				return false
			var landed: Vector4 = _body.global_position
			print("--- the throw ---")
			print("   thrown from %.2v" % _from)
			print("   landed at   %.2v" % landed)
			print("   travelled %.2f m across the ground, peaked %.2f m up" % [
				Vector2(landed.x - _from.x, landed.z - _from.z).length(),
				_peak - landed.y])
			print("\n--- it missed the pen ---")
			print("   inside the fence: %s" % _fence.call("contains_point", landed))
			print("   counted: %s" % (_mgr.call("returned_count")))
			print("   marked returned: %s" % _bird.get("returned"))
			print("   catchable again: %s" % _bird.call("can_be_caught"))
			print("   offered by the locator: %s" % (_mgr.call("locator_candidates") as Array).has(_bird))
			print("   its state: %s (0=IDLE, so it is loose and pecking)" % _bird.get("state"))
			return true
	return false
