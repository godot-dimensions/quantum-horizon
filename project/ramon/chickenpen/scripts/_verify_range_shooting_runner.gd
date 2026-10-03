extends SceneTree

const BoothScript := preload("res://ramon/chickenpen/scripts/pen_range_booth_4d.gd")

## The range booth's boards (pen_range_shooting_4d.gd): the counter is found, a shot at a
## board's middle is a bull's-eye and tips it over backwards, a board that is down cannot be
## hit, a board on another slice cannot be hit from this one, the board stands up again,
## and walking off puts everything away. Shots are aimed through shoot() rather than the
## mouse, which headless has no way to capture.
##
## Windowed, it also saves res://smoke_test_output/range_shoot_<n>.png from the counter: the
## boards standing, one going over, and it back up.
##
## Waits are in seconds (the boards move on the clock) and steps in drawn frames.

const Booth := preload("res://ramon/chickenpen/scripts/pen_range_booth_4d.gd")

var _room: Node
var _shooter: Node
var _booth: Node4D
var _f := 0
var _step := 0
var _t := 0.0
var _failed := 0
var _eye_cam: Camera4D
var _sign_shot := 0
var _windowed := false


func _initialize() -> void:
	# Never takes the keyboard: typing elsewhere while this window is up must not reach
	# the pen (C opens the theatre, E and Q step through W).
	root.unfocusable = true
	_windowed = DisplayServer.get_name() != "headless"
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _player() -> CharacterBody4D:
	return _room.get_node("Player") as CharacterBody4D


## A point in the booth's frame, in the world.
func _in_booth(local: Vector4) -> Vector4:
	return _booth.global_position + _booth.global_basis * local


func _board(i: int) -> Node4D:
	return (_booth.get("board_nodes") as Array)[i]


## The middle of board [param i]'s face, standing, in the world.
func _face_of(i: int) -> Vector4:
	return _board(i).global_position + Booth.FACE[0]


func _hold(at: Vector4) -> void:
	_player().global_position = at
	_player().linear_velocity = Vector4.ZERO


func _eye() -> Vector4:
	return _in_booth(Vector4(-1.0, 1.6, 0.0, 0.0))


func _look_down_range() -> void:
	var rig := _player().get_node("CameraRig") as Node4D
	var d: Vector4 = _face_of(0) - _player().global_position
	rig.set("yaw", atan2(-d.x, -d.z))
	rig.set("pitch", deg_to_rad(-2.0))
	rig.call("_apply")


func _save(n: int) -> void:
	if _windowed:
		root.get_texture().get_image().save_png("res://smoke_test_output/range_shoot_%d.png" % n)
		print("   saved range_shoot_%d.png" % n)


func _process(d: float) -> bool:
	_f += 1
	if _f == 15:
		_shooter = _room.get_node("Systems/RangeShooting")
		_booth = _room.get_node("World/RangeBooth") as Node4D
		if _windowed:
			for c in _room.get_node("UI").get_children():
				if c is CanvasItem:
					(c as CanvasItem).visible = false
	if _f < 20:
		return false
	_t += d
	match _step:
		0:
			_hold(_in_booth(Vector4(6.0, 0.0, 0.0, 0.0)))
			if _t > 0.2:
				_check("not at the counter out in the field", not bool(_shooter.call("at_firing_line")))
				_check("no range HUD out in the field", not (_shooter.get("_hud") as CanvasLayer).visible)
				_step = 1
				_t = 0.0
		1:
			_hold(_in_booth(Vector4(-1.0, 0.0, 0.0, 0.0)))
			_look_down_range()
			if _t > 0.3:
				_check("at the counter behind it", bool(_shooter.call("at_firing_line")))
				_check("the HUD comes up there", (_shooter.get("_hud") as CanvasLayer).visible)
				_check("the pickaxe is told to stand down", bool(_player().get_meta(&"at_firing_line", false)))
				_check("five boards, each its own node", (_booth.get("board_nodes") as Array).size() == 5)
				var lying: Node4D = _booth.get("counter_rifle")
				_check("a rifle lies on the counter", lying != null and lying.visible and not bool(_shooter.get("holding")))
				_check("and the first press picks it up", String((_shooter.get("_tally") as Label).text).contains("pick up the rifle"))
				_shooter.call("_pick_up", true)
				_step = 10
				_t = 0.0
		10:
			_hold(_in_booth(Vector4(-1.0, 0.0, 0.0, 0.0)))
			_look_down_range()
			if _t > 0.8:
				var lying: Node4D = _booth.get("counter_rifle")
				var held: Node4D = _player().get_node_or_null("Avatar/HeldRifle")
				_check("off the counter and into your hands", not lying.visible and held != null and held.visible)
				_check("the camera comes over the shoulder", float(_player().get_node("CameraRig").get("_aim_blend")) > 0.5)
				_save(0)
				var hit: int = int(_shooter.call("shoot", _eye(), _face_of(0) - _eye()))
				_check("a shot at the middle of board 0 hits it", hit == 0, "hit %d" % hit)
				_check("and it is a bull's-eye", int(_shooter.get("bulls")) == 1)
				_step = 2
				_t = 0.0
		2:
			_hold(_in_booth(Vector4(-1.0, 0.0, 0.0, 0.0)))
			_look_down_range()
			if _t > 0.5:
				var up: Vector4 = _board(0).global_basis * Vector4(0.0, 1.0, 0.0, 0.0)
				var local_up: Vector4 = _booth.global_basis.inverse() * up
				_check("it went over", up.y < 0.4, "up %v" % up)
				_check("backwards, away from the counter", local_up.x < -0.8, "up in booth frame %v" % local_up)
				_save(1)
				# The same shot again. With board 0 down it flies on - and board 4 stands
				# behind it, so it may well hit that instead. Either is right; board 0 is not.
				var again: int = int(_shooter.call("shoot", _eye(), _face_of(0) - _eye()))
				_check("a board that is down cannot be hit", again != 0, "hit %d, the one behind it" % again if again >= 0 else "a miss")
				var edge: Vector4 = _face_of(1) + Vector4(0.0, 0.35, 0.0, 0.0)
				var off: int = int(_shooter.call("shoot", _eye(), edge - _eye()))
				_check("a shot near the edge of board 1 hits it", off == 1, "hit %d" % off)
				_check("and is not a bull's-eye", int(_shooter.get("bulls")) == 1)
				# Board 2 stands at w = -1.1: its face reaches w -0.65 at most. Aimed at its
				# (x, y, z) but along the home slice, the shot passes beside it in W.
				var beside: Vector4 = _face_of(2)
				beside.w = 0.0
				var slice: int = int(_shooter.call("shoot", _eye(), beside - _eye()))
				_check("a board on another slice cannot be hit from this one", slice == -1, "hit %d" % slice)
				_check("the tally", int(_shooter.get("shots")) == 4 and int(_shooter.get("hits")) == 2 + int(again >= 0),
					"shots %d hits %d" % [int(_shooter.get("shots")), int(_shooter.get("hits"))])
				_step = 3
				_t = 0.0
		3:
			_hold(_in_booth(Vector4(-1.0, 0.0, 0.0, 0.0)))
			_look_down_range()
			var wait: float = float(_shooter.get("down_seconds")) + 1.2
			if _t > wait:
				var up: Vector4 = _board(0).global_basis * Vector4(0.0, 1.0, 0.0, 0.0)
				_check("it stands up again", up.y > 0.999, "up %v" % up)
				_save(2)
				var back: int = int(_shooter.call("shoot", _eye(), _face_of(0) - _eye()))
				_check("and can be hit again", back == 0, "hit %d" % back)
				_step = 4
				_t = 0.0
		4:
			_hold(_in_booth(Vector4(6.0, 0.0, 0.0, 0.0)))
			if _t > 0.3:
				_check("walking off puts the HUD away", not (_shooter.get("_hud") as CanvasLayer).visible)
				_check("and gives the pickaxe back", not bool(_player().get_meta(&"at_firing_line", false)))
				_check("and the camera back", float(_player().get_node("CameraRig").get("_aim_blend")) < 0.5)
				_check("and the rifle back on the counter", (_booth.get("counter_rifle") as Node4D).visible and not bool(_shooter.get("holding")))
				# The signs through W: a letter on one side of every board's rings, a glyph on
				# the other, and the letters, read across the range from the left, are AZOTH.
				var order: Array = []
				for i in 5:
					order.append([float(BoothScript.BOARDS[i].y), String(BoothScript.LETTERS[i])])
				order.sort_custom(func(a, b): return a[0] > b[0])
				var word := ""
				for o in order:
					word += String(o[1])
				_check("the boards spell it, left to right", word == "AZOTH", word)
				_check("every board carries its signs", int(_booth.call("sign_boxes", 0).size()) > 10)
				_step = 5
				_t = 0.0
		5:
			# A close look at board 3 (the A), from in front, at three depths through it.
			if _eye_cam == null:
				_eye_cam = Camera4D.new()
				_eye_cam.set("rendering_engine_name", "Cross-section")
				_booth.add_child(_eye_cam)
				_eye_cam.current = true
			var b: Vector4 = _board(3).position
			var depth: float = [0.0, BoothScript.SIGN_W, -BoothScript.SIGN_W][mini(_sign_shot, 2)]
			_eye_cam.position = Vector4(b.x + 2.2, b.y + 0.45, b.z, b.w + depth)
			_eye_cam.basis = Projection(Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 0, 1))
			if _t > 0.6:
				_save(3 + _sign_shot)
				_sign_shot += 1
				_t = 0.0
				if _sign_shot >= 3:
					print("RANGE SHOOTING: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
					quit()
					return true
	if _f > 20000:
		print("RANGE SHOOTING: TIMED OUT at step %d" % _step)
		quit()
		return true
	return false
