extends SceneTree

## A short film of the grass, for judging the wind: a slow drift low over the field, a higher
## look across it with the waves rolling through, then walking through it (the player pushing
## it aside), then a step ana through W (the grass shrinking away, the next growing in).
## Recorded by the movie writer at a fixed 30 fps.
##
##   godot... --path project --resolution 1920x1080 --write-movie <out>.avi --fixed-fps 30
##       --script res://ramon/chickenpen/grass/_film_grass_runner.gd

const SHOTS := [[7.0, "low"], [7.0, "across"], [6.0, "walk"], [5.0, "ana"]]

var _room: Node
var _cam: Camera4D
var _t: float = 0.0
var _shot: int = -1
var _shot_t: float = 0.0
var _started: bool = false
var _shots: Array = SHOTS


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_grassfilm_test.cfg")
	# After "--": shots=across:30 films only that shot for that long; key=value sets a Grass knob
	# before it is ready (start_preset=3, say).
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "shots":
			var parts: PackedStringArray = kv[1].split(":")
			_shots = [[float(parts[1]), parts[0]]]
		else:
			_room.get_node("World/Grass").set(kv[0], float(kv[1]))
	root.add_child(_room)
	current_scene = _room


func _look(eye: Vector4, at: Vector4) -> void:
	if _cam == null:
		_cam = Camera4D.new()
		_cam.set("rendering_engine_name", "Cross-section")
		_cam.set("field_of_view_4d", 1.05)
		_room.add_child(_cam)
		_cam.make_current()
	_cam.global_position = eye
	var d: Vector4 = at - eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))


func _process(d: float) -> bool:
	_t += d
	if not _started:
		if _t > 90.0:
			print("GRASS FILM FAIL: no grass after 90 s")
			return true
		var grass: Node = _room.get_node("World/Grass")
		if not bool(grass.get("mask_ready")) or _t < 4.0:
			return false
		for child in _room.get_node("UI").get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		for f in ["approached", "met_wren"]:
			_room.get_node("Systems/Lookout").get("journal").call("set_flag", f, true)
		_started = true
	_shot_t += d
	if _shot < 0 or _shot_t >= float(_shots[_shot][0]):
		_shot += 1
		_shot_t = 0.0
		if _shot >= _shots.size():
			print("GRASS FILM DONE")
			return true
	var k: float = _shot_t / float(_shots[_shot][0])
	match String(_shots[_shot][1]):
		"low":
			_look(Vector4(6.0 - 6.0 * k, 0.95, 9.0, 0.0), Vector4(-8.0 - 6.0 * k, 0.45, -6.0, 0.0))
		"across":
			_look(Vector4(10.0, 2.6, 14.0 - 4.0 * k, 0.0), Vector4(-10.0, 0.0, -6.0 - 4.0 * k, 0.0))
		"walk":
			# The player walking through it, seen from beside and behind.
			var player := _room.get_node("Player") as Node4D
			var at := Vector4(4.0 - 6.0 * k, 0.05, 6.0 - 3.0 * k, 0.0)
			player.global_position = at
			_look(at + Vector4(2.2, 1.2, 2.6, 0.0), at + Vector4(0.0, 0.2, 0.0, 0.0))
		"ana":
			# The camera stepping ana through W, the view held: the grass shrinks away and the
			# next grass, at the next w, grows in.
			var w: float = smoothstep(0.1, 0.9, k) * 0.9
			_look(Vector4(1.5, 0.8, 4.0, w), Vector4(-2.0, 0.15, 0.0, w))
	return false
