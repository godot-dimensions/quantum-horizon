extends SceneTree
## Voxel Lab, rounds 3 to 5 (9 Oct): the gallery's world. From above and four sides (round 5, #43: turned half
## round, its slope toward you as you come in), with the hologram's gradient over it (#44); then from its ring:
## turned through W a long way in many small drags (no limit, no stop), slid through W, put back with R
## (reset_view), the half turn still there, and each look of the land (its own ground: rebuilt). Frames to
## smoke_test_output/voxel_lab/terrain/, checks printed as PASS or FAIL.
##   VoxelLab/run.sh windowed terrain res://ramon/VoxelLab/scripts/_probe_terrain_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/terrain/"

var _scene: Node
var _st: Node4D
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0
var _cam: Camera4D
var _resets0: int = 0


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
	print("TERRAIN %s %s" % ["PASS" if ok else "FAIL", what])


func _ex() -> Node:
	return _st.get("exhibit")


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("TERRAIN saved %s" % name)


## A free camera `dist` metres out from the terrain toward `yaw_deg` (0: +x, the ring's side), looking at it.
func _side(yaw_deg: float, dist: float = 8.5) -> void:
	var c: Vector4 = _st.global_position
	var a: float = deg_to_rad(yaw_deg)
	var dir := Vector2(cos(a), -sin(a))
	_cam.global_position = Vector4(c.x + dir.x * dist, 4.2, c.z + dir.y * dist, 0.0)
	_cam.global_basis = Basis4D.from_zx(atan2(dir.x, dir.y)) * Basis4D.from_yz(deg_to_rad(-24.0))
	_cam.make_current()


func _process(delta: float) -> bool:
	_total += delta
	if _total > 240.0:
		print("TERRAIN FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	_t += delta
	match _step:
		0:
			_st = _scene.get_node("Terrain")
			var ex: Node = _ex()
			if ex != null and bool(ex.call("is_ready")) and _t > 2.0 and not bool(_scene.get("loading")):
				var yaw: float = float(ex.get("face_yaw"))
				_check(absf(absf(rad_to_deg(yaw)) - 180.0) < 0.5, "turned half round (%.0f degrees)" % rad_to_deg(yaw))
				var holo: Node = _st.get_node_or_null("Hologram")
				_check(holo != null and (holo as Node4D).is_visible_in_tree(), "the hologram's gradient stands over it")
				_cam = Camera4D.new()
				_cam.rendering_engine_name = "Cross-section"
				_scene.add_child(_cam)
				var c: Vector4 = _st.global_position
				_cam.global_position = Vector4(c.x, 9.0, c.z, 0.0)
				_cam.global_basis = Basis4D.from_yz(-PI * 0.5)
				_cam.make_current()
				_next()
		1:
			if _t > 1.2:
				_save("top")
				_side(0.0)
				_next()
		2, 3, 4, 5:
			if _t > 1.2:
				_save("side_%d" % ((_step - 2) * 90))
				if _step < 5:
					_side(float(_step - 1) * 90.0)
				else:
					# As you come in from the hall's door, then from its ring.
					_scene.call("go_to", Vector4(0.0, 0.05, -18.0, 0.0), 0.0)
					(_scene.get("player").get_node("CameraRig/Pitch/Camera4D") as Camera4D).make_current()
				_next()
		6:
			if _t > 1.5:
				_save("from_the_door")
				_scene.call("go_to", Vector4(0.0, 0.05, _st.global_position.z, 0.0), deg_to_rad(90.0))
				_next()
		7:
			if _t > 1.5:
				_save("ring_0_start")
				# A long turn in small drags, as a hand turns it: 0.02 rad a step, 150 steps, about 170 degrees.
				for k in 150:
					_st.call("turn_by", 0.02, 0.0)
				_next()
		8:
			if _t > 1.2:
				var tilt: float = rad_to_deg(acos(clampf((_st.get("turn_basis") as Projection).w.w, -1.0, 1.0)))
				_check(tilt > 120.0, "turned through W without a stop (%.0f degrees)" % tilt)
				_save("ring_1_turned")
				_st.call("step_slice", 3)
				_next()
		9:
			if _t > 1.2:
				_save("ring_2_slid")
				_st.call("reset_view")
				_next()
		10:
			if _t > 1.2:
				_check(int(_st.get("slice_index")) == 4 and (_st.get("turn") as Vector2) == Vector2.ZERO, "R puts it back as it stood")
				_check(absf(absf(rad_to_deg(float(_ex().get("face_yaw")))) - 180.0) < 0.5, "still turned half round after R")
				_save("ring_3_reset")
				_resets0 = int(_ex().get("_resets"))
				_check(String(_ex().call("next_biome")) == "Desert", "the next land: the desert")
				_next()
		11, 12:
			# Built again with its own ground, then the next.
			var ex: Node = _ex()
			if ex.get("_rebuilding") == null and int(ex.get("_resets")) > _resets0 and _t > 2.0:
				_save("land_%s" % String(ex.call("biome_name")).to_lower())
				_resets0 = int(ex.get("_resets"))
				if _step == 11:
					ex.call("next_biome")
				_next()
			elif _t > 40.0:
				_check(false, "the land was never built again")
				return true
		13:
			_check(true, "every land built with its own ground")
			print("TERRAIN done, %d failed" % _fails)
			return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _next_to(step: int) -> void:
	_step = step
	_t = 0.0
