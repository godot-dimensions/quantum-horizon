extends SceneTree

## The walk into the dark and out into the light (pen_cave_fade_4d.gd): the screen goes
## black with depth in the hill's tunnel, is black when the crossing fires, clears in the
## cave; goes white toward the cave's daylight, is white when the way out fires, clears on
## the field. Headless is fine - it reads the fade's colour, not the frame.
##
## Steps wait in drawn frames, as in _verify_cave_runner.gd; the clearing is timed in
## seconds, since the fade clears on a clock and headless frames are far shorter than real
## ones.

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")

var _room: Node
var _fade: ColorRect
var _crossing: Node
var _hill
var _f := 0
var _step := 0
var _wait := 0
var _i := 0
var _failed := 0
var _alphas: Array = []
var _clear_at := -1.0
var _t := 0.0

const INTO := [0.0, 2.0, 3.0, 5.0, 7.0, 8.4]
const GAPS := [6.0, 4.0, 2.5, 1.6]


func _initialize() -> void:
	# Never takes focus, so a mouse moving over the window cannot turn its camera.
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	_hill = CaveHill.new()


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _player() -> CharacterBody4D:
	return _room.get_node("Player") as CharacterBody4D


func _hold(at: Vector4) -> void:
	_player().global_position = at
	_player().linear_velocity = Vector4.ZERO


func _alpha() -> float:
	return _fade.color.a if (_fade.get_parent() as CanvasLayer).visible else 0.0


## A point [param into] metres into the hill's tunnel, on its middle line. The hill's constants are
## in its own frame; since 6 Oct the Cave unit can be moved and turned.
func _in_tunnel(into: float) -> Vector4:
	return CaveHill.to_world(CaveHill.node_in(_room), Vector4(CaveHill.MOUTH.x, 1.05, CaveHill.MOUTH.z + 0.5 - into, CaveHill.MOUTH.w))


func _cave() -> Node4D:
	return _crossing.get("_theatre") as Node4D


## A point [param gap] metres short of the cave's daylight.
func _toward_daylight(gap: float) -> Vector4:
	var cave := _cave()
	return cave.global_position + cave.global_basis * Vector4(0.0, 1.05, CaveRock.DAYLIGHT_Z - gap, 0.0)


func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_fade = _room.get_node("Systems/CaveFade/Fade") as ColorRect
		_crossing = _room.get_node("CaveCrossing")
	if _f < 20:
		return false
	match _step:
		0:
			# Deeper and deeper into the hill, reading the fade at each.
			if _wait == 0:
				_hold(_in_tunnel(INTO[_i]))
			_wait += 1
			if _wait == 8:
				_alphas.append(_alpha())
				print("   %.1f m in: %.3f" % [INTO[_i], _alphas[-1]])
				_wait = 0
				_i += 1
				if _i == INTO.size():
					_check("clear at the mouth", _alphas[0] < 0.01)
					_check("still clear 2 m in", _alphas[1] < 0.01)
					_check("darkening between", _alphas[3] > 0.2 and _alphas[3] < 0.9, "%.2f" % _alphas[3])
					_check("never lighter going in", _alphas[1] <= _alphas[2] and _alphas[2] <= _alphas[3] and _alphas[3] <= _alphas[4] and _alphas[4] <= _alphas[5])
					_check("black before the crossing", _alphas[5] > 0.99, "%.3f" % _alphas[5])
					_step = 1
		1:
			# On into the trigger, holding there until it fires.
			var way: Array = _hill.way_in()
			_hold(CaveHill.to_world(CaveHill.node_in(_room), way[0] - Vector4(0.0, 0.15, 0.0, 0.0)))
			if bool(_crossing.call("is_away")):
				var a := _alpha()
				_check("black the moment you arrive", a > 0.95, "%.3f" % a)
				_step = 2
				_t = 0.0
				_clear_at = -1.0
		2:
			_t += d
			if _alpha() < 0.01 and _clear_at < 0.0:
				_clear_at = _t
			if _t > 2.5:
				_check("clears in the cave, not at once", _clear_at > 0.8 and _clear_at < 1.6, "after %.2f s" % _clear_at)
				_step = 3
				_i = 0
				_wait = 0
				_alphas.clear()
		3:
			# Toward the cave's daylight.
			if _wait == 0:
				_hold(_toward_daylight(GAPS[_i]))
			_wait += 1
			if _wait == 8:
				_alphas.append(_alpha())
				print("   %.1f m from daylight: %.3f" % [GAPS[_i], _alphas[-1]])
				_wait = 0
				_i += 1
				if _i == GAPS.size():
					_check("clear back in the cave", _alphas[0] < 0.01)
					_check("whitening toward the light", _alphas[1] > 0.05 and _alphas[2] > _alphas[1])
					_check("white before the way out", _alphas[3] > 0.99, "%.3f" % _alphas[3])
					var tint: Color = _fade.color
					_check("it is the light, not the dark", tint.r > 0.9 and tint.g > 0.85, str(tint))
					_step = 4
		4:
			if bool(_crossing.call("is_away")):
				_hold(_toward_daylight(0.8))
			else:
				var tint: Color = _fade.color
				_check("white the moment you are home", _alpha() > 0.95 and tint.r > 0.9, "%.3f %s" % [_alpha(), tint])
				_step = 5
				_t = 0.0
				_clear_at = -1.0
		5:
			_t += d
			if _alpha() < 0.01 and _clear_at < 0.0:
				_clear_at = _t
			if _t > 2.5:
				_check("clears on the field, not at once", _clear_at > 0.8 and _clear_at < 1.6, "after %.2f s" % _clear_at)
				var p: Vector4 = CaveHill.to_local(CaveHill.node_in(_room), _player().global_position)
				_check("home in the mouth", _hill.tunnel_into(p) < 3.0, "%.1f m in" % _hill.tunnel_into(p))
				print("CAVE FADE: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
				quit()
				return true
	if _f > 20000:
		print("CAVE FADE: TIMED OUT at step %d" % _step)
		quit()
		return true
	return false
