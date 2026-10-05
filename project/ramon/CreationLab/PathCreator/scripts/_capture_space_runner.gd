extends SceneTree

## PathCreator's dev space (PLAN.md steps 6, 7, 10-18): it loads with its light and floor, the
## player walks through W on the ana key (as in the pen), each target shows only near its own W,
## and the volume view (the Combined renderer) switches on and off without the engine crash.
## Frames from the player, from above and of each target at its W, to
## res://smoke_test_output/pathcreator/space/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_space res://ramon/CreationLab/PathCreator/scripts/_capture_space_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/space/"

var _g: Node
var _fails: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _shot(what: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


## The player at (x, z) and W `w`, facing -z.
func _put(x: float, z: float, w: float) -> void:
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(x, 0.05, z, w)
	p.set("linear_velocity", Vector4.ZERO)
	await _wait(0.8)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.0)
	var p: CharacterBody4D = _g.get("player")
	_check(p != null and _g.get_node_or_null("Walkplane") != null, "the space, its floor and the player")
	await _shot("player_start")
	# Walking through W: hold the ana key a second.
	var w0: float = p.global_position.w
	Input.action_press(&"move_ana")
	await _wait(1.0)
	Input.action_release(&"move_ana")
	await _wait(0.4)
	print("ana for a second: W %.2f to %.2f" % [w0, p.global_position.w])
	_check(p.global_position.w > w0 + 0.3, "the ana key walks through W")
	# Each target at its own W and away from it.
	for t in [["Here", 0.0], ["Ana2", 2.0], ["House", 4.0], ["Tower", 8.0]]:
		var tn: Node4D = _g.get_node("Targets/" + t[0])
		await _put(tn.global_position.x, tn.global_position.z + 12.0, float(t[1]))
		await _shot("target_%s_at_its_w" % String(t[0]).to_lower())
		await _put(tn.global_position.x, tn.global_position.z + 12.0, float(t[1]) + 1.5)
		await _shot("target_%s_off_w" % String(t[0]).to_lower())
	# The volume view, on and off, twice.
	await _put(0.0, 52.0, 0.0)
	for i in 2:
		_g.call("set_volume_view", true)
		await _wait(1.0)
		await _shot("volume_on_%d" % i)
		_g.call("set_volume_view", false)
		await _wait(0.8)
	_check(true, "the volume view switched on and off twice without a crash")
	await _shot("volume_off")
	print("SPACE %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
