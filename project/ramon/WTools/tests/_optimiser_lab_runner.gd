extends SceneTree

## THE OPTIMISER LAB (WTools/PLAN.md steps 77-80), optimiser_lab.tscn: the Watchstone 45 m ahead (Skyline),
## the camp front left and the range front right (Landmark).
##   1. The reports.
##   2. Frames from the start, the optimisers off and on: the slice turned straight ahead (zw) 0, 20, 40, 60
##      and across (xw) 30; flat at W 4; the volume view (projected, combined) on.
##   3. Collisions: rays at W 0, 3 and 5 into a thin solid box of the camp and of the range hit it exactly
##      where its depth says, without the optimiser (its own, under 3 m) and with it (6 m); a box body walked
##      into the camp at W 4 is stopped with the optimiser and not without; a ray down through the middle of
##      a wrap copy of the Watchstone finds the floor, not the stone; one through the Watchstone finds it.
##   4. Cost: build time, the wrap's cull time over the sweep, the GPU flat and turned 30 (zw), off and on.
##   5. Editing: a copy of the Watchstone's own scene with a rock chunk and an authored part moved 3 m, put in
##      its place: the change shows in the landmark and in every wrap copy, and nothing else moves.
## Frames: res://smoke_test_output/wtools/optimiser/.
##
##   lab_run.sh windowed wt_optlab res://ramon/WTools/tests/_optimiser_lab_runner.gd

const LAB := "res://ramon/WTools/tests/optimiser_lab.tscn"
const UNIT := "res://ramon/chickenpen/units/watchstone/watchstone.tscn"
const OUT := "res://smoke_test_output/wtools/optimiser/"
const EDITED := "res://smoke_test_output/wtools/optimiser/watchstone_edited.tscn"
## The parts moved in the edit (each built and merged into AllStones as the Watchstone starts).
const MOVED := ["Chunks/Chunk75", "Stones/Inner/Stone000"]
const SHOTS := [["zw", 0.0], ["zw", 20.0], ["zw", 40.0], ["zw", 60.0], ["xw", 30.0]]

var _fails: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 600000:
		print("OPTLAB: gave up")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var want: PackedStringArray = OS.get_cmdline_user_args()
	var lab: Node = (load(LAB) as PackedScene).instantiate()
	lab.set("readout", false)
	root.add_child(lab)
	current_scene = lab
	await _frames(45)
	var player := lab.get("player") as CharacterBody4D
	player.set("input_enabled", false)
	var rig := lab.get("rig") as Node4D
	var cam := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	var opts: Array = lab.find_children("*W", "Node4D", false, false).filter(func(n: Node) -> bool: return n.has_method("apply"))
	# 1. The reports.
	for o in opts:
		print("OPTLAB %s\n%s" % [o.name, String(o.get("report"))])
		_check(bool(o.get("applied")), "%s applied as the scene started" % o.name)
	# 2. Frames, off then on (skipped with "noframes").
	if not want.has("noframes"):
		# The rig eases its distance and pivot into place: let it settle before the first frame.
		_view(player, rig, 0.0, "zw", 0.0)
		await _frames(90)
		for state in ["off", "on"]:
			for o in opts:
				o.call("clear" if state == "off" else "apply")
			await _frames(3)
			for s in SHOTS:
				_view(player, rig, s[1], s[0], 0.0)
				await _frames(4)
				await _shot("%s_%s%02d" % [state, s[0], int(s[1])])
			_view(player, rig, 0.0, "zw", 4.0)
			await _frames(4)
			await _shot("%s_w4" % state)
		_view(player, rig, 0.0, "zw", 0.0)
		for engine in ["Projected", "Combined"]:
			var other := Camera4D.new()
			lab.add_child(other)
			other.make_current()
			await _frames(2)
			cam.rendering_engine_name = engine
			cam.make_current()
			await _frames(20)
			await _shot("on_volume_%s" % engine.to_lower())
			other.queue_free()
		cam.rendering_engine_name = "Cross-section"
		var other2 := Camera4D.new()
		lab.add_child(other2)
		other2.make_current()
		await _frames(2)
		cam.make_current()
		other2.queue_free()
		await _frames(5)
	# 3. Collisions.
	for unit_name in ["Camp", "Range"]:
		await _collide(lab, unit_name)
	await _walk(lab)
	_wrap_rays(lab)
	# 4. Cost.
	var stone: Node = lab.get_node("WatchstoneW")
	var cull_max: int = 0
	var follow := PackedStringArray()
	var followed: bool = true
	var flat_seen := Vector3.ZERO
	var stone_mid: Vector4 = stone.get("_land_mid")
	# The rig eases its pitch and distance into place: settled before the flat view is taken.
	_view(player, rig, 0.0, "zw", 0.0)
	await _frames(60)
	for plane in ["zw", "xw"]:
		for turn in [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0]:
			_view(player, rig, turn, plane, 0.0)
			await _frames(3)
			cull_max = maxi(cull_max, int(stone.get("cull_usec")))
			# The wrap's copy: shown once the slice is turned, its middle in the slice, where the camera saw
			# the Watchstone itself on the flat slice (bearing and height within a degree).
			var b: Projection = cam.global_basis
			var e: Vector4 = cam.global_position
			var mid: Vector4 = stone.call("copy_middle_now") if int(stone.call("shown")) == 0 else stone_mid
			var rel: Vector4 = mid - e
			var seen := Vector3(rel.dot(Vector4(b.x).normalized()), rel.dot(Vector4(b.y).normalized()), rel.dot(Vector4(b.z).normalized()))
			if turn == 0.0:
				flat_seen = seen
			var off: float = absf(rel.dot(Vector4(b.w).normalized()))
			var turned_deg: float = rad_to_deg(seen.angle_to(flat_seen))
			var shown: int = int(stone.call("shown"))
			follow.append("%s %d: %s, %.3f m off, %.2f deg from the flat view" % [plane, int(turn), "copy" if shown == 0 else "itself", off, turned_deg])
			# Turned across the view (xw), the Watchstone straight ahead stays in the slice itself.
			followed = followed and (shown == (0 if turn > 0.0 and plane == "zw" else -1)) and off < 0.05 and turned_deg < 1.0
	_check(followed, "the Watchstone's wrap: in the slice at every turn, where it was on the flat slice", "; ".join(follow))
	for o in opts:
		print("OPTLAB COST %s: made in %d ms, %d parts and %d colliders deepened, %d wrap copies" % [o.name,
			int(o.get("build_msec")), int(o.get("parts_deepened")), int(o.get("colliders_deepened")), int(o.get("wrap_copies"))])
	print("OPTLAB COST the wrap's cull: at most %d us a frame" % cull_max)
	for state in ["off", "on"]:
		for o in opts:
			o.call("clear" if state == "off" else "apply")
		for turn in [0.0, 30.0]:
			_view(player, rig, turn, "zw", 0.0)
			await _frames(20)
			var gpu: Array = []
			for i in 90:
				await process_frame
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			gpu.sort()
			print("OPTLAB COST GPU %s %.2f ms at %d degrees" % [state, gpu[45], int(turn)])
	root.remove_child(lab)
	lab.free()
	await _frames(5)
	# 5. Editing.
	await _editing()
	print("OPTIMISER LAB: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)


func _view(player: CharacterBody4D, rig: Node4D, turn: float, plane: String, w: float) -> void:
	player.global_position = Vector4(0.0, 1.0, 0.0, w)
	player.linear_velocity = Vector4.ZERO
	rig.set("pitch", deg_to_rad(4.0))
	rig.set("_slice_xw", deg_to_rad(turn) if plane == "xw" else 0.0)
	rig.set("_slice_zw", deg_to_rad(turn) if plane == "zw" else 0.0)
	rig.set("yaw", 0.0)
	rig.call("_apply")


func _ray(from: Vector4, dir: Vector4, dist: float) -> Dictionary:
	var p := RaycastParameters4D.new()
	p.global_ray_origin = from
	p.global_ray_direction = dir.normalized()
	p.max_distance = dist
	return PhysicsServer4D.raycast_physics_objects(p)


## The unit's widest solid box collider shallower in W than [param under] either side (as it is now), alone in
## its body if there is one such (a ray then meets no other box of the same body: the range's W yard is one
## body of many boxes).
func _thin_box(unit: Node, under: float) -> CollisionShape4D:
	for alone in [true, false]:
		var cs: CollisionShape4D = _thin_box_of(unit, under, alone)
		if cs != null:
			return cs
	return null


func _thin_box_of(unit: Node, under: float, alone: bool) -> CollisionShape4D:
	var best: CollisionShape4D = null
	var best_area: float = 0.0
	for cs in unit.find_children("*", "CollisionShape4D", true, false):
		var box := (cs as CollisionShape4D).shape as BoxShape4D
		if box == null or not (cs.get_parent() is StaticBody4D):
			continue
		if alone and cs.get_parent().get_children().filter(func(n: Node) -> bool: return n is CollisionShape4D).size() != 1:
			continue
		var hw: float = box.size.w * 0.5 * Vector4((cs as Node4D).global_basis.w).length()
		var area: float = box.size.x * box.size.y
		if area > best_area and box.size.y > 0.6 and hw < under:
			best_area = area
			best = cs
	return best


## The box as it is now: [world middle, its z axis, half-size along it, half-depth in W].
func _box_now(cs: CollisionShape4D) -> Array:
	var box := cs.shape as BoxShape4D
	var b: Projection = cs.global_basis
	return [cs.global_position, Vector4(b.z).normalized(), box.size.z * 0.5 * Vector4(b.z).length(), box.size.w * 0.5 * Vector4(b.w).length()]


## A ray along W, from 10 m out, into the middle of a thin box of the unit: where it hits says how deep in W
## the collider is. Without the optimiser its own depth (under 3 m either side), with it 6 m.
func _collide(lab: Node, unit_name: String) -> void:
	var unit: Node = lab.get_node(unit_name)
	var opt: Node = lab.get_node(unit_name + "W")
	opt.call("clear")
	await physics_frame
	opt.call("analyse")
	if bool(opt.call("built_in_w")):
		# Built in W (the range): nothing of it may change.
		var was: Array = _layout(unit)
		opt.call("apply")
		await physics_frame
		var now: Array = _layout(unit)
		var same: int = 0
		for i in mini(was.size(), now.size()):
			same += 1 if was[i] == now[i] else 0
		_check(was.size() == now.size() and same == was.size() and int(opt.get("parts_deepened")) == 0 and int(opt.get("colliders_deepened")) == 0,
			"%s is built in W (%d colliders off its middle, %d walls across W): left exactly as it is" % [unit_name,
			int(opt.get("off_middle_colliders")), int(opt.get("w_walls"))], "%d of %d nodes unchanged" % [same, was.size()])
		return
	var cs: CollisionShape4D = _thin_box(unit, 2.9)
	if cs == null:
		print("  (%s: no solid box under 3 m deep in W: nothing for the optimiser to deepen there)" % unit_name)
		opt.call("apply")
		return
	for state in ["off", "on"]:
		opt.call("clear" if state == "off" else "apply")
		await physics_frame
		await physics_frame
		var box: Array = _box_now(cs)
		var found := PackedStringArray()
		var ok: bool = true
		for sgn in [1.0, -1.0]:
			var r: Dictionary = _ray(box[0] + Vector4(0.0, 0.0, 0.0, 10.0 * sgn), Vector4(0.0, 0.0, 0.0, -sgn), 12.0)
			var depth: float = 10.0 - float(r.get("distance", 10.0)) if bool(r.get("hit", false)) else 0.0
			found.append("%+.2f" % (depth * sgn))
			ok = ok and bool(r.get("hit", false)) and r.get("body") == cs.get_parent() and absf(depth - float(box[3])) < 0.05
		var want: float = 6.0 if state == "on" else float(box[3])
		_check(ok and absf(float(box[3]) - want) < 0.01, "%s %s: a ray along W finds %s's box %.1f m deep either side" % [unit_name, state,
			cs.get_parent().name, want], "faces at W %s" % " and ".join(found))
	opt.call("apply")
	await physics_frame


## Every mesh's and collider's place, turn and shape under [param unit], in tree order.
func _layout(unit: Node) -> Array:
	var out: Array = []
	for n in unit.find_children("*", "Node4D", true, false):
		if n is MeshInstance4D or n is CollisionShape4D:
			out.append([n.get_instance_id(), (n as Node4D).position, (n as Node4D).basis, n.get("shape") if n is CollisionShape4D else null])
	return out


## A box body walked into a thin wall of the camp at W 4: stopped with the optimiser, through without.
func _walk(lab: Node) -> void:
	var unit: Node = lab.get_node("Camp")
	var opt: Node = lab.get_node("CampW")
	opt.call("clear")
	await physics_frame
	var cs: CollisionShape4D = _thin_box(unit, 2.9)
	if cs == null:
		_check(false, "the camp has a thin wall to walk into")
		return
	var body := CharacterBody4D.new()
	var shape := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = Vector4(0.5, 1.2, 0.5, 0.5)
	shape.shape = bs
	body.add_child(shape)
	lab.add_child(body)
	for state in ["on", "off"]:
		opt.call("apply" if state == "on" else "clear")
		await physics_frame
		var box: Array = _box_now(cs)
		body.global_position = box[0] + Vector4(0.0, 0.0, 0.0, 4.0) + box[1] * (float(box[2]) + 1.5)
		await physics_frame
		var hit: KinematicCollision4D = body.move_and_collide(-box[1] * 3.0, true)
		var other: Object = hit.get_obstacle_body_node() if hit != null else null
		var stopped: bool = other != null and other is Node and unit.is_ancestor_of(other)
		_check(stopped == (state == "on"), "a body walked into the camp's %s at W 4, %s: %s" % [cs.get_parent().name, state,
			"stopped" if stopped else "through"])
	opt.call("apply")
	body.queue_free()
	await physics_frame


func _wrap_rays(lab: Node) -> void:
	var stone: Node4D = lab.get_node("Watchstone")
	var opt: Node = lab.get_node("WatchstoneW")
	var land_mid: Vector4 = opt.get("_land_mid")
	if int(opt.get("wrap_copies")) == 0:
		_check(false, "the Watchstone has its wrap copy")
		return
	var down := Vector4(0, -1, 0, 0)
	var r0: Dictionary = _ray(Vector4(land_mid.x, 40.0, land_mid.z, land_mid.w), down, 60.0)
	_check(bool(r0.get("hit", false)) and stone.is_ancestor_of(r0.get("body")), "a ray down through the Watchstone hits it")
	# Its copy as the slice turned 60 left it (the follow check runs after this one, so place it here).
	var b60: Projection = Basis4D.from_zw(deg_to_rad(60.0))
	opt.call("_place", Vector4(0.0, 1.7, 0.0, 0.0), opt.call("to_slice", b60), float(land_mid.w))
	var far: Vector4 = opt.call("copy_middle_now")
	var r1: Dictionary = _ray(Vector4(far.x, 40.0, far.z, far.w), down, 60.0)
	var on_stone: bool = bool(r1.get("hit", false)) and r1.get("body") != null and stone.is_ancestor_of(r1.get("body"))
	_check(not on_stone, "a ray down through a wrap copy (W %.0f) does not hit the stone" % far.w,
		"hit %s" % (r1.get("body").name if r1.get("hit", false) and r1.get("body") != null else "nothing"))


## The Watchstone's own scene edited (a copy of it): a rock chunk and a stone each moved 3 m in x, as if
## moved in units/watchstone. Everything else of it (the crag, railing, walkways) is built from those as it
## starts, and its stones and chunks are merged into one mesh (AllStones, watchstone_4d.gd): the move must
## show there (each of their vertices 3 m over), and the wrap's copy must draw the landmark's own meshes, so
## it shows in the copy too.
func _editing() -> void:
	var before: Dictionary = await _snapshot(false)
	var verts: int = int(before["moved_verts"])
	var src: Node4D = (load(UNIT) as PackedScene).instantiate()
	for path in MOVED:
		(src.get_node(path) as Node4D).position += Vector4(3.0, 0.0, 0.0, 0.0)
	var packed := PackedScene.new()
	packed.pack(src)
	ResourceSaver.save(packed, EDITED)
	src.free()
	var after: Dictionary = await _snapshot(true)
	var shift: float = float(after["stones_x"]) - float(before["stones_x"])
	_check(bool(after["has_stones"]) and absf(shift - 3.0 * verts) < 0.01 * verts, "the moved chunk and stone are 3 m over in the merged stones",
		"x moved %.1f over %d vertices" % [shift, verts])
	_check(int(after["copies"]) == 1, "the wrap is made again from the edited scene")
	_check(bool(after["copies_share"]), "and its copy draws the landmark's own meshes (the edit is in the copy)")


## The lab with the original Watchstone or the edited copy: {"stones_x": the merged stones' x summed,
## "has_stones", "copies": wrap copies, "copies_share": the copy's every part draws its landmark part's mesh}.
func _snapshot(edited: bool) -> Dictionary:
	var lab: Node = (load(LAB) as PackedScene).instantiate()
	lab.set("readout", false)
	if edited:
		var old := lab.get_node("Watchstone") as Node4D
		var fresh: Node4D = (load(EDITED) as PackedScene).instantiate()
		fresh.position = old.position
		fresh.basis = old.basis
		lab.remove_child(old)
		old.free()
		fresh.name = "Watchstone"
		lab.add_child(fresh)
	root.add_child(lab)
	await _frames(10)
	var stone: Node = lab.get_node("Watchstone")
	var opt: Node = lab.get_node("WatchstoneW")
	var land_parts: Array = opt.get("_land_meshes")
	var out: Dictionary = {"stones_x": 0.0, "has_stones": false, "copies": 0, "copies_share": true, "moved_verts": 0}
	for path in MOVED:
		var mi := stone.get_node_or_null(path) as MeshInstance4D
		if mi != null and mi.mesh is ArrayTetraMesh4D:
			out["moved_verts"] += (mi.mesh as ArrayTetraMesh4D).get_vertex_positions().size()
	var all := stone.get_node_or_null("AllStones") as MeshInstance4D
	if all != null and land_parts.has(all):
		out["has_stones"] = true
		for v in (all.mesh as ArrayTetraMesh4D).get_vertex_positions():
			out["stones_x"] += v.x
	var holder: Node = opt.get_node_or_null("WrapCopy")
	if holder != null:
		out["copies"] = 1
		var i: int = 0
		for m in holder.get_children():
			if (m as MeshInstance4D).mesh != (land_parts[i] as MeshInstance4D).mesh:
				out["copies_share"] = false
			i += 1
	root.remove_child(lab)
	lab.free()
	await _frames(3)
	return out
