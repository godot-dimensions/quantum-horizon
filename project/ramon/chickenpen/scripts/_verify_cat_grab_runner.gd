extends SceneTree

## Two outcomes: hold it too long and it scratches you; throw it in time and it goes and
## sits on the coop.

var _root: Node
var _f := 0
var _t0 := 0
var _cat: Node4D
var _grab: Node
var _player: Node4D
var _tag: Node
var _stage := 0
var _log: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _cat == null:
		_cat = _root.get_node("World/Cat")
		_grab = _root.get_node("Systems/CatGrab")
		_player = _root.get_node("Player")
		_tag = _root.get_node("UI/PlayerTag")
		print("cat starts in mood %d at y %.2f (3 = SIT)" % [_cat.get("_mood"), _cat.global_position.y])
		_t0 = Time.get_ticks_msec()
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var moods := ["WANDER", "TO_CRATE", "JUMP", "SIT", "FLEE", "CARRIED", "THROWN", "TO_PERCH"]
	var mood: int = int(_cat.get("_mood"))

	# Stand next to it, in its slice.
	if _stage < 4:
		var at: Vector4 = _cat.global_position
		_player.position = Vector4(at.x + 0.9, 1.3, at.z + 0.9, at.w)

	match _stage:
		0:
			if elapsed < 0.5: return false
			print("\n--- outcome one: hold it too long ---")
			_grab.call("_grab")
			print("   grabbed: holding %s, cat %s" % [_grab.get("holding"), moods[mood]])
			_stage = 1; _t0 = Time.get_ticks_msec()
		1:
			if elapsed < 1.5: return false
			print("   after 1.5s: cat is %.2f above the player (held overhead)" % [
				_cat.global_position.y - _player.global_position.y])
			_stage = 2
		2:
			if elapsed < 4.0: return false
			print("   after %.1fs: holding %s, cat %s" % [elapsed, _grab.get("holding"), moods[mood]])
			print("   tag says: '%s'" % _tag.get("_text"))
			print("   player knocked down for %.1fs" % _player.get("_down"))
			_stage = 3; _t0 = Time.get_ticks_msec()
		3:
			if elapsed < 5.0: return false
			print("\n--- outcome two: throw it in time ---")
			# Put it back on its crate and face the player at the coop.
			var crate: Node4D = _root.get_node("World/RockPile")
			_cat.position = crate.position + Vector4(0.0, float(_cat.get("crate_top")), 0.0, 0.0)
			_cat.set("_mood", 3)
			_player.position = Vector4(_cat.global_position.x + 0.8, 1.3,
				_cat.global_position.z + 0.8, _cat.global_position.w)
			_stage = 4; _t0 = Time.get_ticks_msec()
		4:
			if elapsed < 0.6: return false
			_grab.call("_grab")
			_grab.call("_throw")
			print("   thrown: cat is %s" % moods[int(_cat.get("_mood"))])
			_stage = 5; _t0 = Time.get_ticks_msec()
		5:
			if not _log.has(moods[mood]):
				_log.append(moods[mood])
			if elapsed < 40.0: return false
			print("   moods after the throw: %s" % [_log])
			print("   ended at y %.2f in mood %s  (coop top is about 2.45)" % [
				_cat.global_position.y, moods[mood]])
			return true
	return false
