extends SceneTree

## The way through W out of the cave's chamber (cave_rock_4d.gd, W_DOOR): pictures with a
## free camera looking straight along W - from beside the plinth at the glowing sheet, from
## a little to one side, from the tunnel back at the sheet, down the tunnel to the far room,
## into the far room, and from its far side back - then a walk along +w from the chamber,
## which has to come out in the far room. Windowed.
## Writes res://smoke_test_output/wdoor_<n>.png.

const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")
var _room: Node
var _cave: Node4D
var _eye: Camera4D
var _f := 0
var _walk_t := 0.0
var _walking := false
func _initialize() -> void:
	# Never takes the keyboard: typing elsewhere while this window is up must not reach
	# the pen (C opens the theatre, E and Q step through W).
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room); current_scene = _room
func _player() -> CharacterBody4D:
	return _room.get_node("Player") as CharacterBody4D
## Looking along +w (sign 1) or -w (sign -1), with z across the screen: the view a player
## gets with the slice turned a quarter and facing the way through.
func _look(at: Vector4, sign_: float) -> void:
	_eye.global_position = _cave.global_position + at
	_eye.global_basis = Projection(Vector4(0, 0, sign_, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, -sign_), Vector4(-1, 0, 0, 0))
func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave": _cave = c
		for c in _room.get_node("UI").get_children():
			if c is CanvasItem: (c as CanvasItem).visible = false
		if "solo=1" in OS.get_cmdline_user_args():
			for lamp in _cave.get_node("Lamps").get_children():
				if not String(lamp.name).begins_with("Far"):
					lamp.set("light_energy", 0.0)
		_eye = Camera4D.new(); _eye.set("rendering_engine_name", "Cross-section")
		_cave.add_child(_eye); _eye.current = true
		# Off w = 0, so the far room streams in (cave_far_stream_4d.gd).
		_player().global_position = _cave.global_position + Vector4(0, 0.05, -31, 3.0)
	if _f < 20:
		return false
	if _f < 400 and not bool(_cave.get_node("FarStream").call("is_loaded")):
		_f = 19
		return false
	var shots := [[Vector4(0, 1.8, -36, 3.6), 1.0], [Vector4(1.2, 1.7, -34.5, 3.0), 1.0], [Vector4(0, 1.8, -36, 17.2), -1.0],
		[Vector4(0, 1.8, -36, 12.0), 1.0], [Vector4(0, 2.2, -36, 25.0), 1.0], [Vector4(0, 2.5, -36, 45.0), -1.0]]
	var n: int = (_f - 20) / 30
	if n < shots.size():
		_look(shots[n][0], shots[n][1])
		if (_f - 20) % 30 == 25:
			root.get_texture().get_image().save_png("res://smoke_test_output/wdoor_%d.png" % n)
			print("saved wdoor_", n)
		return false
	if not _walking:
		_walking = true
		(_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).current = true
		_player().global_position = _cave.global_position + Vector4(0, 0.05, -36, 6.5)
		var recipe = CaveRock.new()
		var lo := INF
		for i in 81:
			var w: float = lerpf(6.5, 46.0, i / 80.0)
			lo = minf(lo, recipe.air_density(Vector4(0, 1.0, -36, w)))
		print("air along the way at chest height: lowest %.2f" % lo)
	_walk_t += d
	_player().linear_velocity = Vector4(0, _player().linear_velocity.y, 0, 3.0)
	if _walk_t > 10.0:
		var local: Vector4 = _player().global_position - _cave.global_position
		print("after 10 s walking +w from w 6.5: at %s  (%s)" % [local, "in the far room" if local.w > 27.0 else "NOT in the far room"])
		quit()
		return true
	return false
