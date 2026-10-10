extends SceneTree

## THE PROBE BEFORE ANY LEVEL (PLAN.md step 50): does a morph box render as its true slice, and does
## its stepped collider agree with the picture?
##
## A corridor ends in a door that opens ana (its leaves part between W 0.3 and 1.4); beyond it a room
## with a wall that rises out of the floor between W 0.4 and 1.0. The player (the real controller, driven
## through its input actions) walks at the closed door, shifts ana, walks through, then tries to shift
## back while standing in the doorway.
##
## Frames in smoke_test_output/maze_remake_2/probe/: the door at W 0, 0.5, 0.85, 1.2, 1.7 and the
## rising wall at 0.4, 0.7, 1.0, 1.4.
##   run.sh windowed probe res://ramon/MazeRemake2/scripts/_probe_morph_runner.gd

const Build := preload("res://ramon/MazeRemake2/world/mr2_build.gd")
const Morph := preload("res://ramon/MazeRemake2/world/mr2_morph.gd")
const Light := preload("res://ramon/MazeRemake2/world/mr2_light_4d.gd")
const Player := preload("res://ramon/MazeRemake2/player/mr2_player_4d.gd")
const OUT := "res://smoke_test_output/maze_remake_2/probe/"

var _t0: int = 0
var _root: Node4D
var _player: CharacterBody4D
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("PROBE FAIL: gave up after 90 s")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _check(ok: bool, what: String) -> void:
	print("PROBE %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("PROBE frame ", name)


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	var t: int = Time.get_ticks_msec()
	for i in 2000:
		if Time.get_ticks_msec() - t >= int(seconds * 1000.0):
			break
		await physics_frame
	Input.action_release(action)
	await _frames(6)


func _run() -> void:
	_root = Node4D.new()
	_root.name = "Probe"
	root.add_child(_root)
	var light: Node4D = Light.new()
	light.name = "Light"
	light.set("dark", false)
	_root.add_child(light)
	var level := Node4D.new()
	level.name = "Level"
	_root.add_child(level)
	var b = Build.new(level)
	b.tint = {"stops": PackedFloat32Array([-2.0, 0.0, 2.0]), "colors": PackedColorArray([Build.KATA, Build.HOME, Build.ANA])}
	b.floor_rect(-6, -20, 6, 4, -4, 4)
	b.wall_z(-10, 3, -1.3, -4, 4)
	b.wall_z(-10, 3, 1.3, -4, 4)
	b.wall_x(-3.0, -0.9, -10.0, -4, 4)
	b.wall_x(0.9, 3.0, -10.0, -4, 4)
	b.wall_x(-1.3, 1.3, 3.0, -4, 4)
	b.door({"name": "D1", "at": Vector2(0, -10), "along": "x", "closed_w": 0.3, "open_w": 1.4, "color": Build.ANA, "w_lo": -4, "w_hi": 4})
	# The room beyond, and a wall in it that rises out of the floor from W 0.4 to 1.0.
	b.wall_z(-18, -10.2, -4, -4, 4)
	b.wall_z(-18, -10.2, 4, -4, 4)
	b.wall_x(-4, 4, -18, -4, 4)
	b.add(Morph.standing(Vector3(-2, 0, -14.2), Vector3(2, 2.6, -13.8), 1.0, 3.0, 0.6), "blue", true)
	b.ceiling_rect(-1.5, -10, 1.5, 3, 3.6, -4, 4)
	b.finish()
	print("PROBE colliders: ", b.collider_count(), "  meshes: ", b.meshes.size())
	_player = Player.new()
	_player.name = "Player"
	_root.add_child(_player)
	light.call("attach_torch", _player.get("camera"))
	_player.call("place", Vector4(0, 0, 1.5, 0), 0.0)
	await _frames(10)

	# The door at five W, from 7 m back.
	_player.call("place", Vector4(0, 0, -3, 0), 0.0)
	for w in [0.0, 0.5, 0.85, 1.2, 1.7]:
		_player.call("place", Vector4(0, 0, -3, w), 0.0)
		await _frames(3)
		await _shot("door_w%s" % str(w).replace(".", "_"))

	# Walk at the closed door.
	_player.call("place", Vector4(0, 0, -6, 0), 0.0)
	await _frames(4)
	await _hold(&"move_forward", 2.5)
	var z1: float = _player.global_position.z
	_check(z1 > -10.0 + 0.25 and z1 < -8.5, "a closed door stops you (stood at z %.2f)" % z1)

	# Shift ana until it is open.
	await _hold(&"move_ana", 1.4)
	var w1: float = _player.global_position.w
	_check(w1 > 1.6, "E moved you ana (W %.2f)" % w1)
	await _shot("open_from_close")
	await _hold(&"move_forward", 2.0)
	var z2: float = _player.global_position.z
	_check(z2 < -11.0, "walked through the open door (z %.2f)" % z2)

	# Stand in the doorway and try to shift back: the leaves close on you, so W must stop.
	_player.call("place", Vector4(0, 0, -10, 1.8), 0.0)
	await _frames(6)
	await _hold(&"move_kata", 1.5)
	var w2: float = _player.global_position.w
	# The leaves' edges reach your capsule (0.25 m from the middle) at about W 0.6, plus its W half-width.
	_check(w2 > 0.55, "the leaves stop a shift back while you stand in the doorway (W %.2f)" % w2)

	# The rising wall at four W, from inside the room.
	for w in [0.4, 0.7, 1.0, 1.4]:
		_player.call("place", Vector4(0, 0, -11, w), 0.0)
		await _frames(3)
		await _shot("rise_w%s" % str(w).replace(".", "_"))

	# DARK: the door half open and the room, with the torch.
	light.call("set_dark", true, false)
	_player.call("place", Vector4(0, 0, -3, 0.85), 0.0)
	await _frames(3)
	await _shot("dark_door_w0_85")
	_player.call("place", Vector4(0, 0, -11, 0.7), 0.0)
	await _frames(3)
	await _shot("dark_rise_w0_7")
	light.call("set_dark", false, false)

	# V: align from 0.9 to the door's align W.
	_player.call("place", Vector4(0, 0, -6, 0.9), 0.0)
	await _frames(4)
	_player.call("align_w", 1.7, 0.4)
	await _frames(40)
	_check(absf(_player.global_position.w - 1.7) < 0.001, "align_w lands exactly (W %.4f)" % _player.global_position.w)

	print("PROBE DONE fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
