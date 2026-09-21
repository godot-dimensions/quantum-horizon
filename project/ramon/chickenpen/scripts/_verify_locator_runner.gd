extends SceneTree

## Phase 07: does the locator pick sensibly, report ana/kata, strengthen as the player
## aligns, lock when in-slice, and drop chickens that are already home?
##
## STAGED ACROSS FRAMES, not done in one. Writing a Node4D position and reading
## global_position back in the same frame returns the stale transform, so an earlier
## version of this test moved the player and then measured from where it used to be -
## and blamed the locator for the answer.
var _root: Node
var _f := 0
var _stage := 0
var _player: Node4D
var _loc: Node
var _mgr: Node
var _readout: Label
var _w_bird: Node


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 50:
		return false
	if _player == null:
		_player = _root.get_node("Player")
		_loc = _root.get_node("Systems/Locator")
		_mgr = _root.get_node("Chickens")
		_readout = _root.get_node("UI/Locator")
		for a in (_mgr.get("agents") as Array):
			if absf((a.get("home_position") as Vector4).w) > 0.5:
				_w_bird = a
				break

	# One stage every 20 frames, so transforms have settled before anything is measured.
	if _f % 20 != 0:
		return false
	_stage += 1
	var body: Node4D = _w_bird.get_parent() as Node4D

	match _stage:
		1:
			_player.position = Vector4(0.0, 0.0, 0.0, 0.0)
		2:
			_dump()
			var picked: Node = _loc.get("target")
			print("from the origin, locator picks #%d" % (picked.get("chicken_id") if picked else -1))
			print("   %s" % _readout.text)
			# Stand near the off-slice bird, but stay in slice zero.
			_player.position = Vector4(body.global_position.x, 0.0, body.global_position.z - 1.8, 0.0)
			_loc.set("target", null)
		3:
			_dump()
			var picked2: Node = _loc.get("target")
			print("beside #%d (w %.2f) but in slice 0, locator picks #%d" % [
				_w_bird.get("chicken_id"), (_w_bird.get("home_position") as Vector4).w,
				picked2.get("chicken_id") if picked2 else -1])
			print("   %s" % _readout.text)
			# Now move into the chicken's slice.
			_player.position = Vector4(_player.position.x, 0.0, _player.position.z, body.global_position.w)
		4:
			print("after matching its slice:")
			print("   %s" % _readout.text)
			_w_bird.set("returned", true)
		5:
			var picked3: Node = _loc.get("target")
			print("after marking #%d returned, locator moved to #%d" % [
				_w_bird.get("chicken_id"), picked3.get("chicken_id") if picked3 else -1])
			return true
	return false


func _dump() -> void:
	var lp: Node4D = _loc.get("_player") as Node4D
	print("   player(test) at %.2v" % _player.global_position)
	print("   player(loc)  is %s at %.2v" % ["<null>" if lp == null else lp.name, Vector4.ZERO if lp == null else lp.global_position])
	var rows: Array = []
	for a in _loc.get("_manager").call("locator_candidates"):
		var b: Node4D = a.get_parent() as Node4D
		rows.append([b.global_position.distance_to(_player.global_position), a.get("chicken_id"), b.global_position])
	rows.sort()
	for r in rows.slice(0, 4):
		print("      #%d at %.2v  gap %.2f" % [r[1], r[2], r[0]])
