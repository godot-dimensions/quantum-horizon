extends SceneTree

## The menu film of the AQUATIC LAB (WaterLab/water_lab.tscn, then its sea, WaterLab/seascape/seascape.tscn):
## five shots of about three seconds, hard cuts, no HUD. Run through the kit's lock-gated script:
##
##   bash Menu/films/film_run.sh aquatic_lab res://ramon/Menu/films/aquatic_lab_film_runner.gd
##
##   1. CINEMATIC  the whole tank: a slow push in from the hall, light shafts down through the water.
##   2. CINEMATIC  along the glass at the fishes' height, koi coming to the glass as the camera passes.
##   3. GAMEPLAY   the player on the blue square, the tank's contents turning through W (the rocks and
##                 arches re-cut, fish from beside the slice coming in).
##   4. GAMEPLAY   out of the tunnel and down the pier to the platform, gulls lifting off the rails.
##   5. CINEMATIC  low over the sea: the platform, the pole, a boat at anchor, gulls, to the horizon.
##
## The cinematic shots use a camera of the runner's own; the gameplay shots the player's own camera
## (its lens a little longer than play's, for the small pane). Nothing is saved: settings are changed
## on the running scenes only. The player's input is off except for the walk, which is pressed by code
## (the window is unfocusable and the mouse free, so no real key or look reaches it).

const Kit := preload("res://ramon/Menu/films/film_kit.gd")
const GullScript := preload("res://ramon/WaterLab/gull/gull_4d.gd")
const LAB := "res://ramon/WaterLab/water_lab.tscn"
const SEA := "res://ramon/WaterLab/seascape/seascape.tscn"
const GUARD_MS := 420000

var _kit: RefCounted
var _t0: int = 0
var _cam: Camera4D
var _lab: Node4D
var _sea: Node4D


func _initialize() -> void:
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("out="):
			out = String(a).substr(4)
	_t0 = Time.get_ticks_msec()
	_kit = Kit.new(self, out)
	_kit.calm_window()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > GUARD_MS:
		print("FILM aquatic_lab: gave up after %d s (%d frames)" % [GUARD_MS / 1000, int(_kit.get("count"))])
		return true
	return false


# -- cameras -----------------------------------------------------------------------------------------------

func _own_camera(fov_deg: float) -> void:
	if _cam == null:
		_cam = Camera4D.new()
		_cam.name = "FilmCamera"
		_cam.set("rendering_engine_name", "Cross-section")
		root.add_child(_cam)
	_cam.set("field_of_view_4d", deg_to_rad(fov_deg))
	_cam.make_current()


## Points the film camera from `eye` at `look`, the slice level.
func _aim(eye: Vector4, look: Vector4) -> void:
	var d: Vector4 = look - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001))
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)


func _rig(scene: Node) -> Node4D:
	var p: Node = scene.get("player")
	return p.get_node_or_null("CameraRig") as Node4D if p != null else null


func _rig_camera(scene: Node, fov_deg: float) -> void:
	var r: Node4D = _rig(scene)
	var c: Camera4D = r.get_node_or_null("Pitch/Camera4D") as Camera4D
	c.set("field_of_view_4d", deg_to_rad(fov_deg))
	c.make_current()


func _rig_set(scene: Node, dist: float, pivot: float, pitch_deg: float) -> void:
	var r: Node4D = _rig(scene)
	r.set("zoom_speed", 0.0)
	r.set("max_distance", maxf(float(r.get("max_distance")), dist))
	r.set("distance", dist)
	r.set("_zoom_target", dist)
	r.set("_rest_distance", dist)
	r.set("pivot_height", pivot)
	r.set("_home_pivot", pivot)
	r.set("pitch", deg_to_rad(pitch_deg))
	r.call("_apply")


## Nobody's mouse or keys reach the scene's player, its rig or its own key handlers.
func _quiet(scene: Node) -> void:
	scene.set_process_input(false)
	scene.set_process_unhandled_key_input(false)
	var p: Node = scene.get("player")
	if p != null:
		p.set("input_enabled", false)
	var r: Node4D = _rig(scene)
	if r != null:
		r.call("lock_look", true)
		r.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# -- the film ----------------------------------------------------------------------------------------------

func _run() -> void:
	_lab = (load(LAB) as PackedScene).instantiate()
	root.add_child(_lab)
	current_scene = _lab
	_quiet(_lab)
	_kit.hide_layers(_lab)
	var tank: Node4D = _lab.get("tank")
	await _kit.skip(90)

	# 1. CINEMATIC: the whole tank, a slow push in from the hall.
	_own_camera(56.0)
	var a0 := Vector4(-5.2, 2.7, 1.6, 0.0)
	var a1 := Vector4(-5.2, 3.1, -2.2, 0.0)
	var look1 := Vector4(-5.2, 4.5, -11.5, 0.0)
	_aim(a0, look1)
	await _kit.skip(2)
	print("FILM shot 1 (tank) from frame %d" % _kit.count)
	_kit.recording = true
	await _kit.glide(90, func(t: float) -> void: _aim(a0.lerp(a1, t), look1))
	_kit.recording = false

	# 2. CINEMATIC: along the glass at the fishes' height, right to left. The player (out of sight
	# behind the camera) is the koi's viewer: they come to the glass in front of it.
	var player: Node4D = _lab.get("player")
	var b0 := Vector4(1.6, 2.75, -8.0, 0.0)
	var b1 := Vector4(-3.0, 2.65, -8.0, 0.0)
	var glass := func(t: float) -> void:
		var e: Vector4 = b0.lerp(b1, t)
		_aim(e, Vector4(e.x - 1.6, 2.45, -11.8, 0.0))
		# Behind the camera's plane (out of sight), across from where it looks.
		player.global_position = Vector4(e.x - 1.3, 0.05, -6.9, 0.0)
		player.set("linear_velocity", Vector4.ZERO)
	_cam.set("field_of_view_4d", deg_to_rad(50.0))
	glass.call(0.0)
	await _kit.skip(10)
	_call_koi(tank, 3)
	await _kit.skip(110)
	glass.call(0.0)
	print("FILM shot 2 (glass) from frame %d" % _kit.count)
	_kit.recording = true
	await _kit.glide(90, glass)
	_kit.recording = false

	# 3. GAMEPLAY: on the blue square, the tank's contents turned and slid through W.
	_lab.call("go_to", Vector4(-5.23, 0.05, -7.4, 0.0), 0.0)
	_quiet(_lab)
	_rig_set(_lab, 5.6, 2.45, -8.0)
	_rig_camera(_lab, 62.0)
	tank.call("reset_contents")
	await _kit.skip(20)
	print("FILM shot 3 (turning square) from frame %d" % _kit.count)
	var lab_rig: Node4D = _rig(_lab)
	# There and back: the reef dissolves into the slice beside it and comes back (a one-way turn left
	# the tank nearly empty at the cut, the far ends of a 20 m tank leave the slice first).
	var turning := func(t: float) -> void:
		var k: float = sin(PI * t)
		tank.call("set_contents", deg_to_rad(20.0) * k, 0.6 * k)
		tank.call("set_turn2", deg_to_rad(10.0) * k)
		var d: float = lerpf(5.6, 5.0, t)
		lab_rig.set("distance", d)
		lab_rig.set("_zoom_target", d)
	_kit.recording = true
	await _kit.hold(6)
	await _kit.glide(78, turning)
	await _kit.hold(6)
	_kit.recording = false

	# The sea, in place of the lab.
	_lab.queue_free()
	_lab = null
	await _kit.skip(2)
	_sea = (load(SEA) as PackedScene).instantiate()
	root.add_child(_sea)
	current_scene = _sea
	_sea.set("doors_enabled", false)
	_quiet(_sea)
	_kit.hide_layers(_sea)
	_sea.set("harbour_gulls", 20)
	var deck: float = float(_sea.get("deck_height"))
	var pier_w: float = float(_sea.get("pier1_width"))
	var start_x: float = float(_sea.call("tunnel_length")) + 2.0
	_sea.call("go_to", Vector4(start_x, deck + 0.05, 0.0, 0.0), -PI * 0.5)
	_quiet(_sea)
	await _kit.skip(150)

	# 4. GAMEPLAY: out of the tunnel and down the pier to the platform; gulls on the rails lift off as
	# the player runs past.
	_sea.call("go_to", Vector4(start_x, deck + 0.05, 0.0, 0.0), -PI * 0.5)
	_quiet(_sea)
	_sea.set("camera_distance", 6.0)
	_sea.call("apply_camera")
	_rig_set(_sea, 6.0, 2.4, -9.0)
	_rig_camera(_sea, 62.0)
	_kit.hide_layers(_sea)
	var top: float = deck + float(_sea.get("railing_height")) * 0.97 + 0.0125
	var rail_end: float = float(_sea.get("pier1_length")) - 0.9
	_seat_gulls([[rail_end - 2.4, 1.0], [rail_end - 1.6, -1.0], [rail_end - 0.7, 1.0], [rail_end, -1.0]], top, pier_w)
	await _kit.skip(12)
	print("FILM shot 4 (pier walk) from frame %d" % _kit.count)
	var sp: Node4D = _sea.get("player")
	_kit.recording = true
	await _kit.hold(6)
	sp.set("input_enabled", true)
	Input.action_press(&"move_forward")
	await _kit.hold(84)
	Input.action_release(&"move_forward")
	sp.set("input_enabled", false)
	_kit.recording = false
	print("FILM walked to x %.1f" % sp.global_position.x)

	# 5. CINEMATIC: low over the sea, sliding past the platform toward the open water and a boat.
	var pc: Vector4 = _sea.call("platform_centre")
	_sea.call("go_to", Vector4(pc.x + 0.6, deck + 0.05, 0.0, 0.0), -PI * 0.5)
	_quiet(_sea)
	_own_camera(52.0)
	# Rising a little as it slides, so the platform's deck opens up; the pole kept just out of frame.
	var c0 := Vector4(pc.x - 10.5, 3.2, -10.0, 0.0)
	var c1 := Vector4(pc.x - 8.3, 4.4, -11.6, 0.0)
	var look5 := Vector4(pc.x + 16.9, 2.4, 20.0, 0.0)
	_aim(c0, look5)
	# No spray off the platform's rim for this one: from down here its drops read as bubbles hanging in
	# the air in front of the lens. The last ones fall before the shot starts.
	var spray: Node = _sea.find_child("Spray", true, false)
	if spray != null:
		spray.set("floor_h", 99.0)
	await _kit.skip(60)
	print("FILM shot 5 (sea) from frame %d" % _kit.count)
	_kit.recording = true
	await _kit.glide(90, func(t: float) -> void: _aim(c0.lerp(c1, t), look5))
	_kit.recording = false

	print("FILM aquatic_lab: %d frames, %.1f s" % [_kit.count, _kit.count / 30.0])
	quit()


## The `n` koi nearest the viewer's x sent to the glass in front of it (the school's own begging,
## started now rather than by chance).
func _call_koi(tank: Node4D, n: int) -> void:
	var koi: Node = tank.get("koi")
	if koi == null:
		return
	var v: Vector4 = koi.get("viewer")
	var fish: Array = koi.get("fish")
	var order: Array = range(fish.size())
	order.sort_custom(func(a: int, b: int) -> bool: return absf((fish[a]["p"] as Vector4).x - v.x) < absf((fish[b]["p"] as Vector4).x - v.x))
	for k in mini(n, order.size()):
		var f: Dictionary = fish[order[k]]
		f["mode"] = "beg"
		f["mode_t"] = 14.0


## Gulls put on pier 1's rails ahead of the walk (x, side), facing out to sea, sitting.
func _seat_gulls(spots: Array, top: float, pier_w: float) -> void:
	var h: Node = _sea.get_node_or_null("Harbour")
	if h == null:
		return
	var pool: Array = []
	for g in h.get("gulls"):
		if String(g.get("state")) != "perched":
			pool.append(g)
	for g in h.get("gulls"):
		if not pool.has(g):
			pool.append(g)
	for i in mini(spots.size(), pool.size()):
		var g: Node = pool[i]
		var s: float = float(spots[i][1])
		var pr: Dictionary = h.call("add_perch", Vector4(float(spots[i][0]), top, s * pier_w * 0.5, 0.0))
		h.call("release", g)
		pr["taken"] = g
		g.set("perch", pr)
		g.set("state", "perched")
		g.set("p", (pr["pos"] as Vector4) + Vector4(0.0, GullScript.FOOT, 0.0, 0.0))
		g.set("_fold", 1.0)
		g.set("_legs", 1.0)
		g.set("_stay", 60.0)
		g.set("_state_t", 0.0)
		g.set("forward", Vector4(0.35, 0.0, s, 0.0).normalized())
