extends SceneTree

## Why did the probe's player walk through everything? A floor and one wall built two ways (one body
## with offset shapes, and one body per shape as the old Phase Maze did), the player dropped on it and
## walked at the wall. Headless.
##   run.sh headless dbgphys res://ramon/MazeRemake2/scripts/_debug_phys_runner.gd

const Build := preload("res://ramon/MazeRemake2/world/mr2_build.gd")
const Player := preload("res://ramon/MazeRemake2/player/mr2_player_4d.gd")

var _t0: int = 0


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 60000:
		print("DBG FAIL: timeout")
		quit(1)
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var r := Node4D.new()
	root.add_child(r)
	var mode: String = "offset"
	for a in OS.get_cmdline_user_args():
		mode = a
	if mode == "offset":
		var b = Build.new(r)
		b.floor_rect(-6, -10, 6, 4, -4, 4)
		b.wall_x(-3, 3, -5, -4, 4)
		b.finish()
		print("DBG offset: colliders ", b.collider_count())
		for c in b.body.get_children():
			var cs := c as CollisionShape4D
			print("DBG shape at ", cs.position, " size ", (cs.shape as BoxShape4D).size)
	else:
		for spec in [[Vector4(0, -0.25, -3, 0), Vector4(12, 0.5, 14, 8)], [Vector4(0, 1.8, -5, 0), Vector4(6, 3.6, 0.4, 8)]]:
			var body := StaticBody4D.new()
			body.position = spec[0]
			r.add_child(body)
			var cs := CollisionShape4D.new()
			var box := BoxShape4D.new()
			box.size = spec[1]
			cs.shape = box
			body.add_child(cs)
	var p: CharacterBody4D = Player.new()
	r.add_child(p)
	p.call("place", Vector4(0, 0.3, 0, 0), 0.0)
	await _frames(30)
	print("DBG after drop: pos ", p.global_position, " on_floor ", p.is_on_floor())
	Input.action_press(&"move_forward")
	await _frames(120)
	Input.action_release(&"move_forward")
	print("DBG after walk: pos ", p.global_position, " on_wall ", p.is_on_wall())
	print("DBG basis det ", p.global_basis.determinant())
	quit(0)
