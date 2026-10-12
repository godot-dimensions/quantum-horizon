extends SceneTree

## Does T lock onto a chicken - and do nothing else?
##
## The claim is narrow on purpose: the heading swings onto the nearest loose bird and stays
## there, while the slice and your w are left exactly where you had them. A lock that also
## rotated the slice would show a chicken you still could not reach, which is the one
## misunderstanding this level exists to undo.

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const SCENE := "res://ramon/chickenpen/playable_world.tscn"

var _room: Node
var _rig: Node4D
var _player: Node4D
var _f: int = 0
var _fails: int = 0
var _bird: Node4D
var _before: Array = []
var _start_gap: float = 0.0


func _initialize() -> void:
	_room = load(SCENE).instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("   %s %-50s %s" % ["PASS" if ok else "FAIL", what, detail])


## T as a player presses it, through the whole pen (7 Oct: the slice assist owns T and drives the rig's
## lock, set_locked; the rig's own key is off in the pen, so calling the rig's handler tested nothing).
func _press_t() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_T
		ev.physical_keycode = KEY_T
		ev.pressed = down
		Input.parse_input_event(ev)
	Input.flush_buffered_events()


## How far off dead-ahead the bird is, in degrees, measured in the horizontal plane.
func _off_ahead() -> float:
	var ahead: Vector4 = -_rig.global_basis.z
	var to_bird: Vector4 = _bird.global_position - _rig.global_position
	var a := Vector2(ahead.x, ahead.z).normalized()
	var b := Vector2(to_bird.x, to_bird.z).normalized()
	return rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))


func _process(_d: float) -> bool:
	_f += 1
	if _f == 40:
		_rig = _room.get_node("Player/CameraRig") as Node4D
		_player = _room.get_node("Player") as Node4D
		var locator: Node = _room.get_node("Systems/Locator")
		var agent: Node = locator.get("target")
		_check("the locator has a bird to offer", agent != null, "")
		if agent == null:
			return _done()
		_bird = agent.get_parent() as Node4D
		var was: Vector3 = SliceAngles.angles(_rig.basis)
		_before = [was.x, was.y, _player.global_position.w]
		_start_gap = _off_ahead()
		_press_t()
		_check("T locks on", bool(_rig.call("is_locked_on")), "%.0f deg off dead ahead when pressed" % _start_gap)
		var readout: Label = _room.get_node("UI/Locator") as Label
		_check("and the readout says so", readout != null, "")
	elif _f == 40 + 120:
		var off: float = _off_ahead()
		_check("the bird is brought dead ahead", off < 8.0, "%.1f deg off, from %.0f" % [off, _start_gap])
		var now: Vector3 = SliceAngles.angles(_rig.basis)
		_check("the slice is left where it was",
			absf(now.x - float(_before[0])) < 0.0001 and absf(now.y - float(_before[1])) < 0.0001,
			"xw and zw unchanged - it turns the view, never the cut")
		_check("and so is your w", is_equal_approx(_player.global_position.w, float(_before[2])),
			"w %.3f - reaching the bird is still your job" % _player.global_position.w)
		var readout: Label = _room.get_node("UI/Locator") as Label
		_check("the readout shows the lock", readout.text.contains("LOCKED") or readout.text.begins_with("[T] tracking"), readout.text.left(40))
		_press_t()
		_check("a second T lets go", not bool(_rig.call("is_locked_on")), "")
		return _done()
	return false


func _done() -> bool:
	print("\n%d FAIL(s)" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
