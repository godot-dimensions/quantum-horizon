extends SceneTree

## The chair, the sit, and the camera it hands over.
##
## THE THINGS WORTH ASSERTING ARE THE ONES THAT WOULD BE SILENT IF THEY BROKE. A camera
## that never takes over just looks like a camera; a camera that takes over and never
## gives back looks like the game has frozen; and a shot that drifts through W would
## change the shape of every exhibit with nothing on screen to say the viewer had moved
## rather than the object. None of those three announce themselves.
##
## It also checks that Trym is already walking when the room appears, because "he went
## through the door first" is a claim about one frame - the first one - and by the second
## act it is unobservable either way.

var _root: Node
var _f := 0
var _fails: Array = []
var _player: CharacterBody4D
var _seat: Node
var _camera: Node
var _show: Node
var _stage: Node4D
var _their: Camera4D
var _start: Vector4 = Vector4.ZERO
var _stood_at: Vector4 = Vector4.ZERO
var _presenter_at: Vector4 = Vector4.ZERO
var _w_drift: float = 0.0
var _took: bool = false
var _gave_back: bool = false
var _shots: Array = []
var _stage_at := 0
var _settled_at := 0
var _walked: float = 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		_player = _root.get_node("Player") as CharacterBody4D
		_seat = _root.get_node("UI/Seat")
		_camera = _root.get_node("ShotCamera")
		_show = _root.get_node("Show")
		_stage = _root.get_node("Stage") as Node4D
		_their = _root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D
		# HIS HEAD START, read on the first frame there is one. The room is instanced the
		# instant you step through the door, so this IS your moment of arrival.
		_presenter_at = (_root.get_node("Presenter") as Node4D).global_position
		return false

	if _f == 2:
		print("\n--- he went first ---")
		var wings: Vector4 = _show.get("wings")
		var foot: Vector4 = _stage.get("aisle_from")
		var whole: float = Vector2(wings.x - foot.x, wings.z - foot.z).length()
		var gone: float = Vector2(wings.x - _presenter_at.x,
			wings.z - _presenter_at.z).length()
		_check("Trym is already walking when you arrive", gone / maxf(whole, 0.01) > 0.15,
			"%.0f%% of the way down before the room has drawn a frame"
				% (100.0 * gone / maxf(whole, 0.01)))
		_check("and he has not reached his mark either", gone / maxf(whole, 0.01) < 0.9,
			"so there is still a man to follow rather than one already in place")

		# Down the rake, where sitting is a thing somebody would think of.
		_player.set_physics_process(false)
		var top: Vector4 = _stage.get("aisle_to")
		_start = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18,
			lerpf(top.z, foot.z, 0.5), 0.0)
		_player.global_position = _start
		return false

	if _f == 3:
		print("\n--- the chair ---")
		var chair: Node4D = _stage.get_node_or_null("House/YourSeat") as Node4D
		_check("there is one chair built as a chair", chair != null
			and chair.get_child_count() >= 7,
			"%d parts - pan, edge, back, headrest and two arms with caps"
				% (chair.get_child_count() if chair != null else -1))
		# It has to be a chair a person fits on, not a 0.46 block with a name.
		var pan: MeshInstance4D = chair.get_node_or_null("Pan") as MeshInstance4D \
			if chair != null else null
		var wide: float = (pan.mesh as BoxTetraMesh4D).size.x if pan != null else 0.0
		_check("and it is sized to the avatar, not to the row", wide > 0.6,
			"%.2f across, against %.2f for a row seat" % [wide, 0.46])
		_check("no row seat is standing inside it", _clashes(chair) == 0,
			"%d of the ninety overlap the good one" % _clashes(chair))
		_check("it offers itself once you are down the rake",
			bool(_seat.call("is_offering")),
			"half way down, %.1f from the chair"
				% (chair.global_position - _player.global_position).length()
					if chair != null else "no chair")
		_seat.call("sit")
		return false

	# Sitting takes a couple of seconds of real time, and the W drift is sampled the whole
	# way through it rather than at the end - a shot that wandered off the slice and came
	# back would pass an end-state check.
	if bool(_camera.call("is_holding")):
		_took = true
		var shot: Camera4D = _camera.call("live_camera") as Camera4D
		if shot != null:
			_w_drift = maxf(_w_drift, absf(shot.global_position.w
				- _player.global_position.w))
		var name: String = String(_camera.call("shot_name"))
		if name != "" and (_shots.is_empty() or _shots[-1] != name):
			_shots.append(name)

	# WAITED ON THE STATE, NOT ON A FRAME COUNT. The first version sampled at frame 40 and
	# caught him half way into the chair with his legs a third folded, which it reported as
	# two failures of the sit rather than as one failure of the test.
	if _stage_at == 0 and bool(_seat.call("is_settled")):
		_stage_at = 1
		print("\n--- sat down, and the camera left ---")
		var chair: Node4D = _stage.get_node_or_null("House/YourSeat") as Node4D
		var gap: float = (_player.global_position - chair.global_position).length()
		_check("he ends up in the chair", gap < 0.6,
			"%.2f from the middle of the seat" % gap)
		var hip: Node4D = _root.get_node_or_null("Player/Avatar").get("hip_left") as Node4D
		var fold: float = 0.0
		if hip != null:
			# from_yz writes the rotation into the basis; the y column tipping off vertical
			# is the thigh having swung forward.
			fold = absf(hip.basis.y.z)
		_check("with his legs folded rather than standing in it", fold > 0.5,
			"thigh swung %.2f out of vertical" % fold)
		_check("the shot camera is the one rendering",
			(_camera.call("live_camera") as Camera4D).is_current() and not _their.is_current(),
			"and the player's own camera has stood down")
		_stood_at = _start
		_settled_at = _f
		return false

	if _stage_at == 1 and _f > _settled_at + 30:
		_stage_at = 2
		print("
--- and it gives back ---")
		_check("the shot never left your slice", _w_drift < 0.001,
			"worst W difference between camera and player: %.4f" % _w_drift)
		_check("it framed more than one thing", _shots.size() >= 1, "%s" % [_shots])
		# The escape hatch, pressed the way a trapped player would press it - and pressed
		# properly: a release first, because "just pressed" is an EDGE, and re-sending a
		# key that is already down is not one.
		_press(false)
		return false

	if _stage_at == 2 and _f == _settled_at + 32:
		_press(true)
		return false

	# Held for two frames and then let go. LETTING GO IS THE POINT: the first version
	# pressed forward and never released, then reported the resulting walk cycle as a sit
	# pose that had not been cleared. The thigh was oscillating between 0.37 and 0.50,
	# which is a stride - the test was holding W down and reading the answer as a fault.
	if _stage_at == 2 and _f == _settled_at + 34:
		_walked = (_player.global_position - _stood_at).length()
		_press(false)
		return false

	if _stage_at == 2 and _f > _settled_at + 70:
		_gave_back = _their.is_current() and not bool(_camera.call("is_holding"))
		_check("F takes the camera back", _gave_back,
			"the sit key again, no confirmation, no delay")
		_check("and leaves the presentation with you", bool(_root.get_node("Show").call("is_over")),
			"the talk ends where it was, rather than carrying on without you")
		_check("and puts him back where he was standing", _walked < 0.5,
			"%.2f from the spot he sat down from, on the frame he stood up" % _walked)
		var hip: Node4D = _root.get_node_or_null("Player/Avatar").get("hip_left") as Node4D
		_check("the sit pose is let go of", hip == null or absf(hip.basis.y.z) < 0.25,
			"thigh %.2f off vertical once the key is released, against %.2f while sat"
				% [absf(hip.basis.y.z) if hip != null else -1.0, absf(sin(-1.40))])
		# And the character is his own again, which is the thing the camera handover is
		# only half of: physics, input and the gait all back where they came from.
		_check("and he is his own again", _player.is_physics_processing()
			and bool(_player.get("input_enabled")) and not bool(_seat.call("is_seated")),
			"physics, input and the gait are the character's again")
		print("
%d FAIL(s)" % _fails.size())
		quit(1 if _fails.size() > 0 else 0)
		return true

	if _f > 600:
		print("   FAIL never got through the sit (took=%s)" % _took)
		quit(1)
		return true
	return false


## Row seats standing where the good chair stands. The stage is supposed to leave them out.
func _clashes(chair: Node4D) -> int:
	if chair == null:
		return -1
	var count := 0
	for child in _stage.get_node("House").get_children():
		if not String(child.name).begins_with("Seat"):
			continue
		if ((child as Node4D).global_position - chair.global_position).length() < 0.95:
			count += 1
	return count


## The real binding rather than a guessed key: the sit key, which is also the way out of
## the chair since 1 Oct (getting up is leaving the talk - the movement keys no longer do
## it). Bound by PHYSICAL keycode, and a printed key stops being true when it is rebound.
func _press(down: bool) -> void:
	for event in InputMap.action_get_events(&"catch_target"):
		if not (event is InputEventKey):
			continue
		var key := (event as InputEventKey).duplicate() as InputEventKey
		key.pressed = down
		Input.parse_input_event(key)
		return
