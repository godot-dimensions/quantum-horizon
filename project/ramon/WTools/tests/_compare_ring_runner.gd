extends SceneTree

## RING OR STAY PUT, AS PICTURES (Ramon, 7 Oct: "i'm not sure how the ring look will look like"): the
## Watchstone in the pen, the art look, two ways side by side.
##   stay put  what is in now: one copy where the Watchstone is on the flat slice through the camera.
##   ring      the mountains' way: copies of it (deepened, as now) every 4 degrees round the pen's middle in
##             the plane of (the way to it, W), out to 60 either side; in the slice only the copy the slice
##             passes nearest is drawn (all of them doubled the scaffold), in the volume view all of them.
## Shots: from the start facing it (flat, turned 30 and 50 along the view), from the meadow where it stands
## off to one side (turned 30 and 50), and the volume view from the start and from the meadow pulled back.
## Frames: res://smoke_test_output/wtools/ring/<mode>_<shot>.png, and ring_vs_stay.png side by side.
##
## With "lab" after "--": the optimiser lab instead (nothing in the way), the Watchstone 45 m ahead of its
## middle: straight ahead (flat, 30, 50), off to the side (the player 25 m over, facing down the lab: it
## stands 30 degrees to the left; 30, 50), and the volume view. Frames lab_<mode>_<shot>.png.
##
##   PEN_LOOK=art lab_run.sh windowed wt_ring res://ramon/WTools/tests/_compare_ring_runner.gd [lab]

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://smoke_test_output/wtools/ring/"
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const OPT := preload("res://ramon/WTools/optimiser/w_optimiser_4d.gd")
var CENTRE := Vector2(0.0, 6.0)
const LAB := "res://ramon/WTools/tests/optimiser_lab.tscn"
## The lab: [name, at, yaw (degrees), turn along -z (zw), engine, camera distance, pitch]
const LAB_SHOTS := [
	["ahead_flat", Vector4(0.0, 1.0, 0.0, 0), 0.0, 0.0, "Cross-section", 6.0, 0.06],
	["ahead_30", Vector4(0.0, 1.0, 0.0, 0), 0.0, 30.0, "Cross-section", 6.0, 0.06],
	["ahead_50", Vector4(0.0, 1.0, 0.0, 0), 0.0, 50.0, "Cross-section", 6.0, 0.06],
	["side_flat", Vector4(25.0, 1.0, 0.0, 0), 0.0, 0.0, "Cross-section", 6.0, 0.06],
	["side_30", Vector4(25.0, 1.0, 0.0, 0), 0.0, 30.0, "Cross-section", 6.0, 0.06],
	["side_50", Vector4(25.0, 1.0, 0.0, 0), 0.0, 50.0, "Cross-section", 6.0, 0.06],
	["across_30", Vector4(25.0, 1.0, 0.0, 0), 0.0, 30.0, "Cross-section", 6.0, 0.06, "xw"],
	["across_50", Vector4(25.0, 1.0, 0.0, 0), 0.0, 50.0, "Cross-section", 6.0, 0.06, "xw"],
	["volume", Vector4(0.0, 1.0, 0.0, 0), 0.0, 0.0, "Projected", 6.0, 0.06],
	["volume_wide", Vector4(0.0, 1.0, 30.0, 0), 0.0, 0.0, "Projected", 30.0, -0.3],
]
const STEP := 4.0
const ARC := 60.0
## [name, at, facing (null: the Watchstone), turn along the view, engine, camera distance, pitch]
const SHOTS := [
	["start_flat", Vector4(24.9, 1.2, 19.1, 0), null, 0.0, "Cross-section", 6.0, -0.05],
	["start_30", Vector4(24.9, 1.2, 19.1, 0), null, 30.0, "Cross-section", 6.0, -0.05],
	["start_50", Vector4(24.9, 1.2, 19.1, 0), null, 50.0, "Cross-section", 6.0, -0.05],
	["meadow_flat", Vector4(5.0, 1.2, 10.0, 0), 74.0, 0.0, "Cross-section", 6.0, -0.07],
	["meadow_30", Vector4(5.0, 1.2, 10.0, 0), 74.0, 30.0, "Cross-section", 6.0, -0.07],
	["meadow_50", Vector4(5.0, 1.2, 10.0, 0), 74.0, 50.0, "Cross-section", 6.0, -0.07],
	["volume_start", Vector4(24.9, 1.2, 19.1, 0), null, 0.0, "Projected", 6.0, -0.05],
	["volume_wide", Vector4(30.0, 1.2, 40.0, 0), null, 0.0, "Projected", 30.0, -0.35],
]

var _room: Node
var _ring: Array[Node4D] = []
var _ring_mid := PackedVector4Array()
var _land: Array = []
var _land_mid := Vector4.ZERO
var _ring_on: bool = false
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 500000:
		print("RING: gave up")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var lab: bool = OS.get_cmdline_user_args().has("lab")
	if lab:
		CENTRE = Vector2.ZERO
		_room = (load(LAB) as PackedScene).instantiate()
		_room.set("readout", false)
		root.add_child(_room)
		current_scene = _room
		# Nobody's mouse or keys reach the frames (Ramon, 7 Oct: "sometimes i accidently move the camera because
		# the screen pops up"; PenLayout/scripts/input_guard.gd).
		var guard := Node.new()
		guard.set_script(load("res://ramon/PenLayout/scripts/input_guard.gd"))
		root.add_child(guard)
		await _frames(60)
		await _lab(_room)
		quit(0)
		return
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
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.process_mode = Node.PROCESS_MODE_DISABLED
	var opt: Node = _room.get_node("World/WatchstoneW")
	for mode in ["stay", "ring"]:
		if mode == "ring":
			# The Optimiser deepens as now but does not wrap; the ring is made here.
			opt.set("wrap", false)
			opt.call("apply")
			_make_ring(opt, _room.get_node("World"))
			_ring_on = true
			RenderingServer4D.pre_render.connect(_ring_pick)
		for shot in SHOTS:
			_view(player, rig, shot)
			await _frames(4)
			_engine(cam, String(shot[4]))
			await _frames(25)
			_hud_off()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [mode, shot[0]]))
			_engine(cam, "Cross-section")
			await _frames(2)
		print("RING %s: %d frames%s" % [mode, SHOTS.size(), (", %d copies every %.0f deg to %.0f" % [_ring.size(), STEP, ARC]) if mode == "ring" else ""])
	print("RING DONE")
	quit(0)


func _lab(lab: Node) -> void:
	var player := lab.get("player") as CharacterBody4D
	player.set("input_enabled", false)
	var rig := lab.get("rig") as Node4D
	var cam := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	var opt: Node = lab.get_node("WatchstoneW")
	# The rig eases its distance and pitch into place: settled before the first frame.
	player.global_position = LAB_SHOTS[0][1]
	rig.set("pitch", float(LAB_SHOTS[0][6]))
	rig.set("distance", float(LAB_SHOTS[0][5]))
	rig.set("_zoom_target", float(LAB_SHOTS[0][5]))
	rig.call("_apply")
	await _frames(150)
	for mode in ["stay", "ring"]:
		if mode == "ring":
			opt.set("wrap", false)
			opt.call("apply")
			_make_ring(opt, lab.get_node("Watchstone").get_parent())
			_ring_on = true
			RenderingServer4D.pre_render.connect(_ring_pick)
		for shot in LAB_SHOTS:
			player.global_position = shot[1]
			player.linear_velocity = Vector4.ZERO
			rig.set("pitch", float(shot[6]))
			if "distance" in rig:
				rig.set("distance", float(shot[5]))
				rig.set("_zoom_target", float(shot[5]))
			# Along the view (zw) unless the shot says across it (xw).
			var across: bool = shot.size() > 7 and String(shot[7]) == "xw"
			rig.set("_slice_xw", deg_to_rad(float(shot[3])) if across else 0.0)
			rig.set("_slice_zw", 0.0 if across else deg_to_rad(float(shot[3])))
			rig.set("yaw", deg_to_rad(float(shot[2])))
			rig.call("_apply")
			await _frames(40)
			_engine(cam, String(shot[4]))
			await _frames(20)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "lab_%s_%s.png" % [mode, shot[0]]))
			_engine(cam, "Cross-section")
			await _frames(2)
		print("RING lab %s: %d frames" % [mode, LAB_SHOTS.size()])
	print("RING DONE")


## The rig at [param shot]'s place, facing the Watchstone (or the yaw given), turned along the view.
func _view(player: CharacterBody4D, rig: Node4D, shot: Array) -> void:
	var at: Vector4 = shot[1]
	player.global_position = at
	player.linear_velocity = Vector4.ZERO
	rig.set("pitch", float(shot[6]))
	if "distance" in rig:
		rig.set("distance", float(shot[5]))
		rig.set("_zoom_target", float(shot[5]))
	var yaw: float
	if shot[2] == null:
		var stone: Vector4 = (_room.get_node("World/LookoutSite") as Node4D).global_position
		var to := Vector2(stone.x - at.x, stone.z - at.z).normalized()
		yaw = atan2(-to.x, -to.y)
		SliceAngles.tilt(rig, 0.0, deg_to_rad(float(shot[3])), yaw)
		var fwd: Vector4 = -(rig.get_node("Pitch/Camera4D") as Node4D).global_basis.z
		if Vector2(fwd.x, fwd.z).normalized().dot(to) < 0.5:
			yaw = -yaw
	else:
		yaw = deg_to_rad(float(shot[2]))
	# Along the view: the slice turned in the plane of the way the rig faces and W.
	SliceAngles.tilt(rig, 0.0, deg_to_rad(float(shot[3])), yaw)


func _engine(cam: Camera4D, name: String) -> void:
	if cam.rendering_engine_name == name:
		return
	var other := Camera4D.new()
	_room.add_child(other)
	other.make_current()
	cam.rendering_engine_name = name
	cam.make_current()
	other.queue_free()


func _make_ring(opt: Node, parent: Node) -> void:
	_land = opt.get("_land_meshes")
	_land_mid = opt.get("_land_mid")
	var pivot := Vector4(CENTRE.x, 0.0, CENTRE.y, 0.0)
	var u := Vector4(_land_mid.x - CENTRE.x, 0.0, _land_mid.z - CENTRE.y, 0.0).normalized()
	var a: float = STEP
	while a <= ARC + 0.001:
		for sgn in [-1.0, 1.0]:
			var turn: Projection = _plane_turn(u, deg_to_rad(a * sgn))
			var copy := Node4D.new()
			copy.name = "Ring%+d" % int(a * sgn)
			parent.add_child(copy)
			for mi: MeshInstance4D in _land:
				var m := MeshInstance4D.new()
				m.mesh = mi.mesh
				m.material_override = mi.material_override
				m.set_meta(&"_look_own", true)
				copy.add_child(m)
				m.global_position = pivot + turn * (mi.global_position - pivot)
				m.global_basis = turn * mi.global_basis
			_ring.append(copy)
			_ring_mid.append(pivot + turn * (_land_mid - pivot))
		a += STEP


## In the slice, only the copy (or the Watchstone) whose middle the slice passes nearest; in the volume
## view, all of them.
func _ring_pick(camera: Camera4D, _viewport: Viewport, engine: RenderingEngine4D) -> void:
	if not _ring_on or camera == null:
		return
	var slice: bool = engine == null or engine.get_friendly_name() == "Cross-section"
	if not slice:
		for mi in _land:
			(mi as Node4D).visible = true
		for c in _ring:
			c.visible = true
		return
	var n: Vector4 = camera.global_basis.w.normalized()
	var e: Vector4 = camera.global_position
	var pick: int = -1
	var best: float = absf((_land_mid - e).dot(n))
	for i in _ring_mid.size():
		var s: float = absf((_ring_mid[i] - e).dot(n))
		if s < best:
			best = s
			pick = i
	for mi in _land:
		(mi as Node4D).visible = pick == -1
	for i in _ring.size():
		_ring[i].visible = i == pick


static func _plane_turn(u: Vector4, angle: float) -> Projection:
	var c: float = cos(angle)
	var s: float = sin(angle)
	var cols: Array[Vector4] = []
	for e in [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]:
		var a: float = e.dot(u)
		var b: float = e.w
		var rest: Vector4 = e - u * a - Vector4(0, 0, 0, b)
		cols.append(rest + u * (a * c - b * s) + Vector4(0, 0, 0, a * s + b * c))
	return Projection(cols[0], cols[1], cols[2], cols[3])


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
