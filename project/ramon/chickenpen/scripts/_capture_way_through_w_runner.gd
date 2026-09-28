extends SceneTree

## The way through W out of the cave's chamber (cave_rock_4d.gd, W_DOOR): three pictures
## with a free camera looking straight along W - from beside the plinth at the glowing
## sheet, from a little to one side, and from the room at the end looking back - then a
## walk along +w from the chamber, which has to come out in the room. Windowed.
## Writes res://smoke_test_output/wdoor_<n>.png.

const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")
var _room: Node
var _cave: Node4D
var _eye: Camera4D
var _f := 0
var _walk_t := 0.0
var _walking := false
func _initialize() -> void:
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
		_eye = Camera4D.new(); _eye.set("rendering_engine_name", "Cross-section")
		_cave.add_child(_eye); _eye.current = true
	if _f < 20:
		return false
	var shots := [[Vector4(0, 1.8, -36, 3.6), 1.0], [Vector4(1.2, 1.7, -34.5, 3.0), 1.0], [Vector4(0, 1.8, -36, 17.2), -1.0]]
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
		for i in 41:
			var w: float = lerpf(6.5, 15.0, i / 40.0)
			lo = minf(lo, recipe.air_density(Vector4(0, 1.0, -36, w)))
		print("air along the way at chest height: lowest %.2f" % lo)
	_walk_t += d
	_player().linear_velocity = Vector4(0, _player().linear_velocity.y, 0, 3.0)
	if _walk_t > 3.0:
		var local: Vector4 = _player().global_position - _cave.global_position
		print("after 3 s walking +w from w 6.5: at %s" % local)
		quit()
		return true
	return false
