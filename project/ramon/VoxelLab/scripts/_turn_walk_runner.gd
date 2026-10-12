extends SceneTree
## Voxel Lab, 8 Oct: the turn and the walk, after the pen's walker, camera and floor-only turns were
## carried over. Diagonal drags on Build it (the column until round 4) and the block (as a hand drags: across with
## some up and down in it, many times) must leave UP exactly up, so nothing leans; then the player walks
## on real key presses and must face the way it goes, upright. Frames to
## smoke_test_output/voxel_lab/turn/ to look at.
##   VoxelLab/run.sh windowed turn res://ramon/VoxelLab/scripts/_turn_walk_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/turn/"

var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0
var _start: Vector4


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("TURN %s %s" % ["PASS" if ok else "FAIL", what])


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


## A hand's diagonal drag, in the room's own units (the room passes mouse pixels x 0.006).
func _drag(st: Node, frames: int, across: float, ahead: float) -> void:
	for i in frames:
		st.call("turn_by", across * 0.006, ahead * 0.006)


## How far UP has left up, in degrees, for a node's global frame.
func _lean(n: Node4D) -> float:
	var up: Vector4 = (n.global_basis * Vector4(0, 1, 0, 0)).normalized()
	return rad_to_deg(acos(clampf(up.dot(Vector4(0, 1, 0, 0)), -1.0, 1.0)))


func _process(delta: float) -> bool:
	_total += delta
	if _total > 240.0:
		print("TURN FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _scene.get("player") == null:
		return false
	_t += delta
	var build: Node = _scene.get_node("Build")
	var hero: Node = _scene.get_node("Hero")
	match _step:
		0:
			_scene.get("player").set("input_enabled", false)
			var ex: Node = build.get("exhibit")
			if ex != null and bool(ex.call("is_ready")) and bool(hero.get("exhibit").call("is_ready")) and _t > 2.0 and not bool(current_scene.get("loading")):
				_scene.call("go_to", Vector4(-4.1, 0.05, 8.8, 0.0), deg_to_rad(90.0))
				_next()
		1:
			if _t > 1.0:
				build.call("_finish")
				_save("01_build_straight")
				# Across with a little up and down in it, forty times: about 80 degrees across and 17 down.
				_drag(build, 40, 5.8, 1.2)
				_next()
		2:
			if _t > 0.6:
				var sp: Node4D = build.get("exhibit").get("specimen")
				_check(_lean(sp) < 0.01, "Build it after diagonal drags: up stays up (%.3f degrees)" % _lean(sp))
				_save("02_build_turned_diagonal")
				_drag(build, 30, -2.0, 6.0)
				_next()
		3:
			if _t > 0.6:
				var sp: Node4D = build.get("exhibit").get("specimen")
				_check(_lean(sp) < 0.01, "and after up and down drags: up stays up (%.3f degrees)" % _lean(sp))
				_save("03_build_turned_ahead")
				build.set("turn", Vector2.ZERO)
				build.set("turn_basis", Projection.IDENTITY)
				# (The tree went on 9 Oct: Ramon, "I don't think we should reintroduce that idea".)
				_scene.call("go_to", Vector4(0.0, 0.05, 4.8, 0.0), 0.0)
				_step = 6
				_t = 0.0
		6:
			if _t > 1.2:
				hero.call("_finish")
				_drag(hero, 35, 6.0, -2.5)
				_next()
		7:
			if _t > 0.8:
				var sp: Node4D = hero.get("exhibit").get("specimen")
				_check(_lean(sp) < 0.01, "the block after diagonal drags: up stays up (%.3f degrees)" % _lean(sp))
				_save("05_block_turned_diagonal")
				# The walk: real key presses, the walker's own input.
				var player: Node4D = _scene.get("player")
				player.set("input_enabled", true)
				_start = player.global_position
				_key(KEY_D, true)
				_next()
		8:
			if _t > 1.2:
				_key(KEY_D, false)
				_next()
		9:
			if _t > 0.8:
				var player: Node4D = _scene.get("player")
				var moved: Vector4 = player.global_position - _start
				var avatar: Node4D = player.get_node("Avatar")
				var fwd: Vector4 = (avatar.global_basis * Vector4(0, 0, 1, 0))
				var flat := Vector4(moved.x, 0, moved.z, moved.w)
				_check(flat.length() > 0.8, "D walks the player (%.2f m)" % flat.length())
				_check(flat.length() > 0.01 and fwd.normalized().dot(flat.normalized()) > 0.95, "and it faces the way it went (%.2f)" % fwd.normalized().dot(flat.normalized()))
				_check(_lean(avatar) < 0.5, "upright (%.2f degrees)" % _lean(avatar))
				_check(absf(player.global_position.w) < 0.01, "and stays in its slice (W %.3f)" % player.global_position.w)
				_save("06_walked")
				player.set("input_enabled", false)
				print("TURN done, %d failed" % _fails)
				return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("TURN saved %s" % name)
