extends SceneTree
## Voxel Lab: the room played and photographed. The way in, the block's story (part by part), the
## bench (sit down, a cut with each tool, a saw channel, a slide through W, the grid and volume
## views, whole again), and the black palette. Frames to smoke_test_output/voxel_lab/room/, with
## checks printed as PASS or FAIL.
##
## The player's input is off and the mouse is never moved: the bench is aimed at screen points
## through its aim_at_screen() (the cursor is the user's).
##   VoxelLab/run.sh windowed room res://ramon/VoxelLab/scripts/_capture_room_runner.gd
##   ... -- part=bench     only the bench part (skips the story)

const OUT := "res://smoke_test_output/voxel_lab/room/"

var _scene: Node
var _room: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _part: String = "all"
var _fails: int = 0
var _hero: Node
var _bench: Node


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "part":
			_part = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_room = _scene
	_hero = _scene.get_node("Hero")
	_bench = _scene.get_node("HeroBench")


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ROOM PASS %s" % what)
	else:
		_fails += 1
		print("ROOM FAIL %s" % what)


func _player() -> Node:
	return _room.get("player")


func _place(x: float, z: float, yaw: float) -> void:
	_room.call("go_to", Vector4(x, 0.05, z, 0.0), yaw)


func _exhibit() -> Node:
	return _hero.get("exhibit")


func _process(delta: float) -> bool:
	_total += delta
	if _total > 200.0:
		print("ROOM FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _player() == null:
		return false
	_player().set("input_enabled", false)
	_t += delta
	match _step:
		0:
			var ex: Node = _exhibit()
			if ex != null and bool(ex.call("is_ready")) and _t > 2.0:
				_check(true, "the block is built: %s" % str(ex.call("numbers")))
				_place(0.0, 21.0, 0.0)
				_next()
			elif _t > 60.0:
				_check(false, "the block never got ready")
				return true
		1:
			if _t > 1.5:
				_save("01_entrance")
				if _part == "bench":
					_step = 10
					_t = 0.0
					return false
				_place(0.0, 6.0, 0.0)
				_next()
		2:
			# Near enough: the story starts by itself.
			if _t > 3.2:
				_check(int(_hero.get("seq_index")) >= 0, "the story starts as you come near (part %d)" % int(_hero.get("seq_index")))
				_save("02_story_specimen")
				_hero.call("skip")
				_next()
		3:
			if _t > 3.0:
				_save("03_story_voxels")
				_hero.call("skip")
				_next()
		4:
			if _t > 3.4:
				_save("04_story_two_cuts")
				_next()
		5:
			if _t > 3.6:
				_save("05_story_two_cuts_slid")
				_hero.call("skip")
				_next()
		6:
			if _t > 3.0:
				_save("06_story_tunnel")
				_hero.call("skip")
				_next()
		7:
			if _t > 5.6:
				_save("07_story_hidden_ana")
				_next()
		8:
			if _t > 5.4:
				_save("08_story_hidden_back")
				_hero.call("skip")
				_next()
		9:
			if _t > 3.0:
				_save("09_story_your_turn")
				var cuts: int = int(_exhibit().call("cut_count"))
				_check(cuts == 0, "your turn: the block is whole again (%d cuts on it)" % cuts)
				_step = 10
				_t = 0.0
		10:
			_place(0.0, 4.0, 0.0)
			_next()
		11:
			if _t > 0.6:
				_room.call("sit", _bench)
				_next()
		12:
			if _t > 1.4:
				_check(_room.get("bench") == _bench, "sitting at the bench")
				var bc: Camera4D = _bench.call("camera")
				_check(bc != null and bool(bc.get("current")), "the bench's camera is the one in use")
				_save("10_bench")
				_next()
		13:
			# Not in the frame of a save: reading the screen back stalls that frame, and the first cut
			# was charged 126 ms for it (6 Oct).
			if _t > 0.4:
				_bench.set("tool", "ball")
				_bench.set("size_index", 1)
				_cut_at(Vector2(560, 330))
				_next()
		14:
			if _t > 0.5:
				_bench.set("tool", "block")
				_cut_at(Vector2(730, 320))
				_next()
		15:
			if _t > 0.5:
				_bench.set("tool", "drill")
				_cut_at(Vector2(640, 400))
				_next()
		16:
			if _t > 0.5:
				_bench.set("tool", "saw")
				_bench.set("size_index", 1)
				var a: Dictionary = _bench.call("aim_at_screen", Vector2(545, 440))
				_bench.set("_drag_from", a.duplicate())
				_bench.call("aim_at_screen", Vector2(740, 440))
				var rec: Dictionary = _bench.call("cut_here")
				_check(not rec.is_empty(), "a saw channel, dragged across the face")
				_bench.set("_drag_from", {})
				_next()
		17:
			if _t > 1.2:
				_bench.set("aim_override", Vector2(640, 340))
				_save("11_bench_cuts")
				var recs: Array = _bench.get("records")
				_check(recs.size() >= 4, "%d cuts recorded on the cost screen" % recs.size())
				for r in recs:
					print("ROOM cut %-10s voxels %4d  chunks %2d  on screen after %6.1f ms  worst frame %5.1f ms  (count %.1f, call %.1f, chips and sound %.1f, frames %d, worker %.0f ms)" % [
						String(r["label"]), int(r["voxels"]), int(r["chunks"]), float(r["latency_ms"]), float(r["worst_ms"]), float(r.get("count_ms", 0)),
						float(r.get("call_ms", 0)), float(r.get("fx_ms", 0)), int(r.get("frames", 0)), float(r.get("worker_ms", 0))])
				_hero.call("step_slice", 2)
				_next()
		18:
			if _t > 1.2:
				_save("12_bench_slid_ana")
				_hero.call("step_slice", -2)
				_room.call("toggle_grid_view")
				_next()
		19:
			if _t > 1.2:
				_save("13_bench_grid")
				_room.call("toggle_grid_view")
				_room.call("toggle_volume_view")
				_next()
		20:
			if _t > 1.2:
				_save("14_bench_volume")
				_room.call("toggle_volume_view")
				_exhibit().call("reset")
				_next()
		21:
			if _t > 1.0:
				_save("15_bench_whole_again")
				_check(int(_exhibit().call("cut_count")) == 0, "R: whole again at once")
				_bench.call("undock")
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_room.call("toggle_palette")
				_place(-3.0, 9.0, deg_to_rad(-15.0))
				_next()
		22:
			if _t > 2.0:
				_save("16_black")
				_room.call("toggle_palette")
				_place(9.0, -2.0, deg_to_rad(60.0))
				_next()
		23:
			if _t > 2.0:
				_save("17_side_view")
				print("ROOM done, %d failed" % _fails)
				return true
	return false


func _cut_at(px: Vector2) -> void:
	var h: Dictionary = _bench.call("aim_at_screen", px)
	if h.is_empty():
		_check(false, "%s: the aim at %s found the block" % [String(_bench.get("tool")), str(px)])
		return
	var rec: Dictionary = _bench.call("cut_here")
	_check(not rec.is_empty(), "%s cut at %s (%s)" % [String(_bench.get("tool")), str(px), str(h.get("material", -1))])


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("ROOM saved %s" % name)
