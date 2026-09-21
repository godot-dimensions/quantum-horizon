extends SceneTree

## Does the cat go to the crate, get on it, sit, wash, and leave when approached?

var _root: Node
var _f := 0
var _t0 := 0
var _cat: Node4D
var _player: Node4D
var _seen: Array = []
var _peak_y: float = -99.0
var _chased := false


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _cat == null:
		_cat = _root.get_node("World/Cat")
		_player = _root.get_node("Player")
		# Park the player far away so it settles before being disturbed.
		_player.position = Vector4(20.0, 1.3, 20.0, 0.0)
		# Hurry it along: a short patience so the test does not wait a minute.
		_cat.set("_mood_left", 0.6)
		_t0 = Time.get_ticks_msec()
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var mood: int = int(_cat.get("_mood"))
	var names := ["WANDER", "TO_CRATE", "JUMP", "SIT", "FLEE"]
	if _seen.is_empty() or _seen[-1] != names[mood]:
		_seen.append(names[mood])
		print("   %5.1fs  %-8s  cat y %.2f" % [elapsed, names[mood], _cat.global_position.y])
	_peak_y = maxf(_peak_y, _cat.global_position.y)

	# Once it has sat down, walk up to it and see if it leaves.
	if not _chased and names[mood] == "SIT" and elapsed > 2.0:
		_chased = true
		var at: Vector4 = _cat.global_position
		_player.position = Vector4(at.x + 1.0, 1.3, at.z + 1.0, at.w)
		print("   -- player walks up to it --")

	if elapsed < 26.0:
		return false
	print("\nmoods in order: %s" % [_seen])
	print("highest the cat got: %.2f (crate top is about 0.85)" % _peak_y)
	return true
