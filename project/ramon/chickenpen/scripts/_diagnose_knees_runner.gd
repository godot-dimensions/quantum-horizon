extends SceneTree

## How bent are the knees, actually, through a whole walking cycle?
##
## Reports the geometry that decides it - leg length against standing height - and then
## the knee angle frame by frame while the character walks, because "bent knees" is a
## claim about the extreme of that curve, not its average.

var _root: Node
var _f: int = 0
var _t0: int = 0
var _player: Node4D
var _gait: Node
var _avatar: Node
var _knees: Array = []
var _hips: Array = []
var _phases: Array = []
var _started := false


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _player == null:
		_player = _root.get_node("Player")
		_gait = _root.get_node("Player/Gait")
		_avatar = _root.get_node("Player/Avatar")
		_report_geometry()
		# Walk forward.
		_key(&"move_forward", true)
		_t0 = Time.get_ticks_msec()
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	if elapsed < 1.0:
		return false
	if elapsed < 5.0:
		_knees.append(_angle("knee_left"))
		_hips.append(_angle("hip_left"))
		_phases.append(float((_gait.get("_gait") as Object).get("phase_progress")))
		return false

	_key(&"move_forward", false)
	print("\nleft knee over 4 s of walking (0 = straight, larger = more bent):")
	print("   straightest %.3f rad (%.0f deg)" % [_knees.min(), rad_to_deg(_knees.min())])
	print("   most bent   %.3f rad (%.0f deg)" % [_knees.max(), rad_to_deg(_knees.max())])
	print("   average     %.3f rad (%.0f deg)" % [_avg(_knees), rad_to_deg(_avg(_knees))])
	print("   hip swing   %.3f to %.3f rad" % [_hips.min(), _hips.max()])
	print("\nfor reference: a person's knee is within about 5 deg of straight at mid-stance")
	print("and bends 60-70 deg at the top of the swing.")
	return true


func _report_geometry() -> void:
	var thigh: float = float(_gait.get("_thigh"))
	var shin: float = float(_gait.get("_shin"))
	var hip: float = float(_gait.get("_hip_height"))
	var sole: float = float(_gait.get("_sole"))
	var reach: float = thigh + shin
	var stand: float = hip - sole
	print("thigh %.3f + shin %.3f = leg %.3f" % [thigh, shin, reach])
	print("hip %.3f - sole %.3f = stands %.3f" % [hip, sole, stand])
	print("standing at %.1f%% of full leg extension" % (stand / reach * 100.0))
	print("   a straight-legged stance is ~97%%; the knee angle that implies is %.0f deg" % [
		rad_to_deg(2.0 * acos(clampf(stand / reach, -1.0, 1.0)))])
	print("stride %.2f, sweep available %.2f" % [
		_gait.get("stride_length"), sqrt(maxf(reach * reach - stand * stand, 0.0))])


func _angle(joint: String) -> float:
	var node: Node4D = _avatar.get(joint) as Node4D
	if node == null:
		return 0.0
	return absf(atan2(node.basis.y.z, node.basis.y.y))


func _avg(values: Array) -> float:
	var total: float = 0.0
	for v in values:
		total += v
	return 0.0 if values.is_empty() else total / float(values.size())


func _key(action: StringName, down: bool) -> void:
	for event in InputMap.action_get_events(action):
		var copy: InputEvent = event.duplicate()
		if copy is InputEventKey:
			(copy as InputEventKey).pressed = down
			Input.parse_input_event(copy)
			return
