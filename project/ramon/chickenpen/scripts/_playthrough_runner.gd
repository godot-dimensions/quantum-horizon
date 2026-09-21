extends SceneTree

## A real playthrough, captured frame by frame, so the prototype can be LOOKED at rather
## than only measured (items 85-89).
##
## It uses the actual controls - the catch key, the throw key, the ana key - rather than
## calling the functions behind them, so anything that is wired up wrongly fails here the
## same way it would fail for a player. The player is teleported between beats only to skip
## the walking; every verb in between is performed for real.

const OUT := "res://smoke_test_output/play_%02d_%s.png"

var _root: Node
var _f: int = 0
var _beat: int = 0
var _wait: int = 0
var _player: CharacterBody4D
var _catcher: Node
var _mgr: Node
var _fence: Node
var _bird: Node
var _log: Array = []
var _holding: bool = false
var _held: int = 0
var _pending: String = ""


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 40:
		return false
	if _player == null:
		_player = _root.get_node("Player")
		_catcher = _root.get_node("Player/Catcher")
		_mgr = _root.get_node("Chickens")
		_fence = _root.get_node("Pen/Fence")
		for a in (_mgr.get("agents") as Array):
			if int(a.get("chicken_id")) == 7:
				_bird = a
	if _wait > 0:
		_wait -= 1
		return false
	# Capture AFTER the move has settled. Moving the camera and saving the image in the
	# same frame photographs where the camera used to be - the same stale-transform trap
	# that made the locator look broken earlier in this project.
	if _pending != "":
		root.get_texture().get_image().save_png(OUT % [_beat - 1, _pending])
		_pending = ""
		return false

	var bird_body: Node4D = _bird.get_parent() as Node4D
	match _beat:
		0:
			_note("start: standing outside the pen, facing the gate")
			_view(0.0, 1.5, 0.0, Vector4(0.0, 0.8, -8.0, 0.0), -8.0, 5.0)
			_shoot("start")
		1:
			_note("the pen and coop, from above")
			_view(0.0, 1.0, 0.0, Vector4(0.0, 0.0, -11.0, 0.0), -46.0, 26.0)
			_shoot("pen")
		2:
			# Stand next to chicken 7, which lives at w 0.9 - still on slice zero, so it
			# should NOT be visible here.
			_note("beside chicken 7 at w 0.00 - it lives at w %.2f, so it should be absent" % bird_body.global_position.w)
			_stand_near(bird_body, 0.0)
			_shoot("offslice")
		3:
			# Hold it until the locator says we have arrived, exactly as a player would,
			# rather than for a fixed count that assumes a speed.
			if not _holding:
				_note("holding the ana key, as the locator tells you to")
				_key(&"move_ana", true)
				_holding = true
				_held = 0
			_held += 1
			var readout: String = (_root.get_node("UI/Locator") as Label).text
			if not readout.contains("LOCKED") and _held < 600:
				return false
			_note("locked after %d frames of holding it" % _held)
			_beat += 1
			return false
		4:
			_key(&"move_ana", false)
			_note("now at w %.2f - the same spot, the chicken present" % _player.global_position.w)
			_shoot("inslice")
		5:
			_note("catch prompt: '%s'" % (_root.get_node("UI/CatchPrompt") as Label).text)
			_shoot("prompt")
		6:
			_key(&"catch_target", true)
			_key(&"catch_target", false)
			_wait = 20
			_beat += 1
			return false
		7:
			_note("after pressing catch: carrying %s" % [
				"nothing" if _catcher.get("carried") == null
				else "chicken %d" % _catcher.get("carried").get("chicken_id")])
			_note("prompt now reads: '%s'" % (_root.get_node("UI/CatchPrompt") as Label).text)
			_shoot("carrying")
		8:
			# Carry it to the pen and throw it in, facing the gate.
			var gate: Vector4 = (_fence as Node4D).global_position + Vector4(0.0, 1.3, 7.5, 0.0)
			_player.global_position = gate
			_player.global_basis = Projection.IDENTITY
			_aim(0.0, -10.0, 4.0)
			_player.linear_velocity = Vector4.ZERO
			_wait = 20
			_beat += 1
			return false
		9:
			_note("at the gate, still holding it through the move: carried %s" % [
				_catcher.get("carried") != null])
			_shoot("atgate")
		10:
			_key(&"catch_target", true)
			_key(&"catch_target", false)
			_wait = 90
			_beat += 1
			return false
		11:
			_note("after the throw: returned %d/12, chicken 7 w %.2f" % [
				_mgr.call("returned_count"), bird_body.global_position.w])
			_shoot("thrown")
		12:
			_wait = 120
			_beat += 1
			return false
		13:
			_note("a couple of seconds later: chicken 7 w %.2f (settling onto the pen slice)" % bird_body.global_position.w)
			_view(0.0, -3.0, 0.0, Vector4(0.0, 0.0, -12.0, 0.0), -24.0, 12.0)
			_shoot("settled")
		14:
			print("\n--- playthrough ---")
			for line in _log:
				print("   %s" % line)
			print("\n   locator: %s" % (_root.get_node("UI/Locator") as Label).text)
			print("   progress: %s" % (_root.get_node("UI/Progress") as Label).text)
			return true
	return false


func _note(line: String) -> void:
	_log.append(line)


func _shoot(tag: String) -> void:
	_pending = tag
	_beat += 1
	_wait = 10


## Stand the character on the ground at a spot and aim the CAMERA RIG at something.
##
## Not by tilting the player. The camera hangs off a rig with its own yaw, pitch and
## distance, and rotating the body instead pitched the whole character over and left it
## falling - every shot after the first was taken from a body in mid-air, looking down at
## nothing in particular. The rig is what a player turns; turn that.
func _view(x: float, z: float, w: float, at: Vector4, pitch_degrees: float, distance: float) -> void:
	_player.global_position = Vector4(x, 1.3, z, w)
	_player.global_basis = Projection.IDENTITY
	_player.linear_velocity = Vector4.ZERO
	var to: Vector4 = at - Vector4(x, 1.3, z, w)
	_aim(atan2(-to.x, -to.z), pitch_degrees, distance)


func _aim(yaw: float, pitch_degrees: float, distance: float) -> void:
	var rig: Node4D = _root.get_node("Player/CameraRig") as Node4D
	rig.set("yaw", yaw)
	rig.set("pitch", deg_to_rad(pitch_degrees))
	rig.set("distance", distance)
	rig.set("_zoom_target", distance)
	rig.call("_apply")
	var avatar: Node4D = _root.get_node_or_null("Player/Avatar") as Node4D
	if avatar != null:
		avatar.basis = Basis4D.from_zx(yaw)


## Stand a short way from a chicken, on the given slice, looking at it.
func _stand_near(body: Node4D, w: float) -> void:
	var here: Vector4 = body.global_position
	# Inside catch_distance (1.6), or the catch prompt never appears and the playthrough
	# reports a broken catch that is really a badly placed camera.
	_view(here.x, here.z + 1.2, w, Vector4(here.x, 0.5, here.z, w), -12.0, 3.2)


func _key(action: StringName, down: bool) -> void:
	for event in InputMap.action_get_events(action):
		var copy: InputEvent = event.duplicate()
		if copy is InputEventKey:
			(copy as InputEventKey).pressed = down
		elif copy is InputEventMouseButton:
			(copy as InputEventMouseButton).pressed = down
		else:
			continue
		Input.parse_input_event(copy)
		return
