extends SceneTree

## THE W TOOLS IN THE PEN (WTools/PLAN.md steps 87-94): playable_world.tscn with the W Exploder on World/Trees
## and the W Optimiser on the Watchstone and the range.
##   1. The planting: plants, copies, spots refused, the time to make them, the cull ready.
##   2. The Optimisers: the Watchstone deepened and wrapped, the range left as it is (built in W), reports.
##   3. The look: in DEV, each Optimiser's copy draws what its landmark draws (the blockouts); the look
##      switched to ART and back while the slice is turned (the copy showing, the landmark hidden) must end
##      exactly as switching it with the slice flat does: the same meshes drawn, the copy the same.
##   4. The wrap from the start: the slice turned toward the Watchstone, its copy shows; flat again, the
##      Watchstone itself, nothing left hidden.
## Frames (smoke_test_output/wtools/pen/): from the start toward the Watchstone, DEV and ART, flat and turned
## 30 and 50, and the volume view.
##
##   lab_run.sh windowed wt_pen res://ramon/WTools/tests/_verify_pen_wtools_runner.gd

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://smoke_test_output/wtools/pen/"
const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const START := Vector4(24.9, 1.2, 19.1, 0.0)

var _room: Node
var _fails: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 400000:
		print("PEN WTOOLS: gave up")
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
	_hud_off()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load(PEN) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	var guard := Node.new()
	guard.set_script(load("res://ramon/PenLayout/scripts/input_guard.gd"))
	root.add_child(guard)
	await _frames(240)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := _room.get_node("Player") as CharacterBody4D
	player.set("input_enabled", false)
	var rig := player.get_node("CameraRig") as Node4D
	var cam := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	var look: Node = Look.current
	var trees: Node = _room.get_node("World/Trees")
	var stone: Node = _room.get_node("World/WatchstoneW")
	var range_w: Node = _room.get_node("World/RangeW")
	# 1. The planting.
	print("PEN TREES: %d placed, %d copies, %d refused, made in %d ms, cull %d us" % [int(trees.get("placed")), int(trees.get("echo_count")),
		int(trees.get("refused")), int(trees.get("build_msec")), int(trees.get("cull_usec"))])
	_check(int(trees.get("placed")) > 90 and int(trees.get("echo_count")) > int(trees.get("placed")) and bool(trees.get("_cull_ready")),
		"the planting stands through W, its cull built")
	# The copies' trunks: in the physics only near the player's W. Walk to a far copy's W: its trunk is
	# solid there (a ray into it hits it); back at W 0 it is out again.
	var solid: Array = trees.get("_solid")
	var in_at_0: int = int(trees.get("solid_in"))
	_check(not solid.is_empty() and in_at_0 < solid.size(), "at W 0 only the copies near it are solid", "%d of %d" % [in_at_0, solid.size()])
	var far: Array = []
	for rec in solid:
		if float(rec[2]) > 12.0:
			far = rec
			break
	if far.is_empty():
		_check(false, "a copy beyond W 12 to walk to")
	else:
		var body := far[0] as StaticBody4D
		var at: Vector4 = (far[1] as Node4D).global_position
		var w: float = (float(far[2]) + float(far[3])) * 0.5
		var was_out: bool = not body.is_inside_tree()
		player.global_position = Vector4(at.x + 6.0, 1.2, at.z, w)
		await physics_frame
		await physics_frame
		var ray := RaycastParameters4D.new()
		ray.global_ray_origin = Vector4(at.x + 3.0, at.y + 1.0, at.z, w)
		ray.global_ray_direction = Vector4(-1.0, 0.0, 0.0, 0.0)
		ray.max_distance = 6.0
		var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(ray)
		_check(was_out and body.is_inside_tree() and bool(hit.get("hit", false)) and hit.get("body") == body,
			"walked to W %.1f: the copy %s there is solid (out of the physics at W 0)" % [w, (far[1] as Node).name],
			"hit %s" % (hit.get("body").name if hit.get("hit", false) and hit.get("body") != null else "nothing"))
		player.global_position = START
		await physics_frame
		await physics_frame
		_check(not body.is_inside_tree() and int(trees.get("solid_in")) == in_at_0, "and back at W 0 it is out again")
	# 2. The Optimisers.
	for o in [stone, range_w]:
		print("PEN %s\n%s" % [o.name, String(o.get("report"))])
	_check(bool(stone.get("applied")) and int(stone.get("parts_deepened")) > 0 and int(stone.get("wrap_copies")) == 1, "the Watchstone deepened and wrapped")
	_check(bool(range_w.get("applied")) and bool(range_w.call("built_in_w")) and int(range_w.get("parts_deepened")) == 0 and int(range_w.get("colliders_deepened")) == 0
		and int(range_w.get("wrap_copies")) == 1, "the range left as built, and wrapped")
	# 3. The look.
	_check(look != null and bool(look.get("_applied")), "the pen opened in DEV")
	_face(player, rig, 0.0)
	await _frames(30)
	var dev_flat: Array = [_drawn(stone), _drawn(range_w)]
	_check(_copy_matches(stone) and _copy_matches(range_w), "in DEV each copy draws what its landmark draws", _note(stone))
	await _shot("pen_dev_flat")
	look.call("set_dev", false)
	await _frames(8)
	var art_flat: Array = [_drawn(stone), _drawn(range_w)]
	_check(_copy_matches(stone) and _copy_matches(range_w) and art_flat[0] != dev_flat[0], "switched to ART (flat): the copies follow", _note(stone))
	await _shot("pen_art_flat")
	# Turned toward the Watchstone: its copy shows. Then the look switched both ways while turned.
	for turn in [30.0, 50.0]:
		_face(player, rig, turn)
		await _frames(6)
		_check(int(stone.call("shown")) == 0, "ART, turned %d: the Watchstone's copy shows" % int(turn), "at %.1f deg" % float(stone.get("wrap_angle")))
		await _shot("pen_art_zw%d" % int(turn))
	look.call("set_dev", true)
	await _frames(8)
	_check(_drawn(stone) == dev_flat[0] and _drawn(range_w) == dev_flat[1] and _copy_matches(stone) and _copy_matches(range_w),
		"switched to DEV while turned: drawn and copied as when switched flat", _note(stone))
	await _shot("pen_dev_zw50")
	look.call("set_dev", false)
	await _frames(8)
	_check(_drawn(stone) == art_flat[0] and _drawn(range_w) == art_flat[1] and _copy_matches(stone) and _copy_matches(range_w),
		"and back to ART while turned: the same as flat", _note(stone))
	# 4. Flat again: the Watchstone itself, nothing hidden.
	_face(player, rig, 0.0)
	await _frames(6)
	var hidden: int = 0
	for mi in stone.get("_land_meshes"):
		if not (mi as Node4D).visible or (mi as Node).has_meta(&"w_hidden"):
			hidden += 1
	_check(int(stone.call("shown")) == -1 and hidden == 0, "flat again: the Watchstone itself, nothing left hidden", "%d hidden" % hidden)
	# The volume view, ART.
	var other := Camera4D.new()
	_room.add_child(other)
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.process_mode = Node.PROCESS_MODE_DISABLED
	other.make_current()
	await _frames(2)
	cam.rendering_engine_name = "Projected"
	cam.make_current()
	await _frames(20)
	await _shot("pen_art_volume")
	look.call("set_dev", true)
	print("PEN WTOOLS: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)


## Every panel, card and note off for a frame (the grass and paths panels show themselves again each
## frame on the farm, so they are paused: _capture_pen_runner.gd).
func _hud_off() -> void:
	var ui: Node = _room.get_node_or_null("UI")
	if ui != null:
		for c in ui.get_children():
			if String(c.name) in ["GrassPanel", "PathsPanel"]:
				c.process_mode = Node.PROCESS_MODE_DISABLED
			if c is CanvasItem:
				(c as CanvasItem).visible = false
	for layer in _room.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


## The player at the start, facing the Watchstone, the slice turned [param turn] degrees straight ahead.
func _face(player: CharacterBody4D, rig: Node4D, turn: float) -> void:
	player.global_position = START
	player.linear_velocity = Vector4.ZERO
	var stone: Vector4 = (_room.get_node("World/LookoutSite") as Node4D).global_position
	var to := Vector2(stone.x - START.x, stone.z - START.z).normalized()
	# The rig's forward at yaw 0 is -z; try both senses of the turn and keep the one that faces it.
	var yaw: float = atan2(-to.x, -to.y)
	_tilt(rig, deg_to_rad(turn), yaw)
	var fwd: Vector4 = -(rig.get_node("Pitch/Camera4D") as Node4D).global_basis.z
	if Vector2(fwd.x, fwd.z).normalized().dot(to) < 0.5:
		_tilt(rig, deg_to_rad(turn), -yaw)


## A rig that keeps its own angles (and rebuilds its frame from them) is given them; any other is turned.
func _tilt(rig: Node4D, zw: float, yaw: float) -> void:
	if "_slice_zw" in rig:
		rig.set("_slice_xw", 0.0)
		rig.set("_slice_zw", zw)
		rig.set("yaw", yaw)
		rig.call("_apply")
	else:
		SliceAngles.tilt(rig, 0.0, zw, yaw)


## The landmark's drawn meshes (mesh resources), as the Optimiser read them.
func _drawn(o: Node) -> Array:
	return (o.get("_land_meshes") as Array).map(func(mi: Node) -> Variant: return (mi as MeshInstance4D).mesh)


## The copy's meshes, one for one, are the landmark's, each with the look's own mark.
func _copy_matches(o: Node) -> bool:
	var holder: Node = o.get_node_or_null("WrapCopy")
	var land: Array = o.get("_land_meshes")
	if holder == null or holder.get_child_count() != land.size() or land.is_empty():
		return false
	for i in land.size():
		var c := holder.get_child(i) as MeshInstance4D
		if c.mesh != (land[i] as MeshInstance4D).mesh or not c.has_meta(Look.OWN):
			return false
	return true


func _note(o: Node) -> String:
	var land: Array = o.get("_land_meshes")
	var blocks: int = land.filter(func(mi: Node) -> bool: return String(mi.name).begins_with("DevBlockout")).size()
	return "%d drawn, %d of them blockouts" % [land.size(), blocks]
