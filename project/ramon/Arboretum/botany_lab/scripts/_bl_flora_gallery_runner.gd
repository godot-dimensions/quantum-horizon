extends SceneTree

## BOTANY LAB, round 3 (section 9, steps 9, 13): the flowers and butterflies on their own, windowed and
## unfocusable, in a plain lit room built here: every species close up side on, from above, and turned
## 45 and 90 degrees through W (xw); every butterfly open, closed and mid-beat. Frames in
## smoke_test_output/botany_lab/flora/.
##
## Args after --: the sets ("flowers", "flies"; default both); "only=<key>" for one species.

const Flower := preload("res://ramon/Arboretum/botany_lab/flora/flower_4d.gd")
const Species := preload("res://ramon/Arboretum/botany_lab/flora/flora_species.gd")
const Fly := preload("res://ramon/Arboretum/botany_lab/flora/butterfly_4d.gd")
const Kit := preload("res://ramon/Arboretum/botany_lab/flora/flora_kit.gd")
const Air := preload("res://ramon/Arboretum/botany_lab/flora/flora_air_4d.gd")
const RoomScript := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_room_4d.gd")
const WindScript := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")
const Mats := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_materials.gd")
const OUT := "res://smoke_test_output/botany_lab/flora/"

var _root: Node4D
var _cam: Camera4D
var _deadline: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_deadline = Time.get_ticks_msec() + 240000
	(func() -> void: _run()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("GALLERY TIMEOUT")
		quit(2)
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _look(eye: Vector4, at: Vector4) -> void:
	var d: Vector4 = at - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001))
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sets: Array = []
	var only: String = ""
	for a in args:
		if a.begins_with("only="):
			only = a.substr(5)
		else:
			sets.append(a)
	if sets.is_empty():
		sets = ["flowers", "flies"]
	_root = Node4D.new()
	_root.name = "Gallery"
	root.add_child(_root)
	var room := Node4D.new()
	room.name = "Room"
	room.set_script(RoomScript)
	room.set("start_mood", "bright")
	_root.add_child(room)
	var wind := Node.new()
	wind.name = "Wind"
	wind.set_script(WindScript)
	wind.set("speed", 1.5)
	wind.set("gust_every", 0.0)
	_root.add_child(wind)
	var air := Node.new()
	air.set_script(Air)
	air.set("wind", wind)
	_root.add_child(air)
	var light: Dictionary = Style.ROOM_LIGHT.duplicate(true)
	light["bright"] = {"sky_top": Color(0.42, 0.5, 0.6), "sky_horizon": Color(0.62, 0.64, 0.66), "sky_bottom": Color(0.4, 0.4, 0.4),
		"ambient": Color(0.5, 0.52, 0.56), "ambient_sky": 0.2, "tonemap": 2, "exposure": 1.1, "white": 4.0,
		"key_color": Color(1.0, 0.94, 0.84), "key_energy": 1.0, "key_elevation": 50.0, "key_azimuth": 30.0,
		"fill_color": Color(0.75, 0.82, 1.0), "fill_energy": 0.3, "fill_elevation": 20.0, "fill_azimuth": -140.0}
	await _frames(2)
	room.set("mood_overrides", light)
	room.call("set_mood", "bright", true, false)
	var floor_m := MeshInstance4D.new()
	floor_m.mesh = Mats.box_mesh(Vector4(40, 0.1, 40, 4))
	floor_m.position = Vector4(0, -0.05, 0, 0)
	floor_m.material_override = Kit.flat(Color(0.32, 0.33, 0.34))
	_root.add_child(floor_m)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_root.add_child(_cam)
	_cam.make_current()
	if "flowers" in sets:
		await _flowers(only)
	if "flies" in sets:
		await _flies()
	print("GALLERY done")
	quit(0)


func _flowers(only: String) -> void:
	var mat: TetraMaterial4D = Flower.material()
	for key in Species.KEYS:
		if not only.is_empty() and key != only:
			continue
		var sp: Dictionary = Species.by_key(key)
		var t0: int = Time.get_ticks_usec()
		var m: ArrayTetraMesh4D = Flower.build(key, 0)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		if m == null:
			print("GALLERY %s: nothing" % key)
			continue
		var mi := MeshInstance4D.new()
		mi.mesh = m
		mi.material_override = mat
		_root.add_child(mi)
		var h: float = maxf(float(m.get_meta("height", 0.4)), 0.12)
		var bloom: Vector4 = m.get_meta("bloom", Vector4(0, h, 0, 0))
		var mid := Vector4(0.0, h * 0.55, 0.0, 0.0)
		var dist: float = maxf(h * 1.5, 0.35)
		print("GALLERY %-13s %5.0f ms  %6d tets  height %.2f" % [key, ms, m.get_simplex_cell_vertex_indices().size() / 4, h])
		for view in [["side", 0.0], ["xw45", 45.0], ["xw90", 90.0]]:
			mi.basis = Basis4D.from_xw(deg_to_rad(float(view[1])))
			_look(Vector4(0.0, h * 0.62, dist, 0.0), mid)
			await _shot("%s_%s" % [key, view[0]])
		mi.basis = Projection.IDENTITY
		# The bloom close and from above.
		_look(bloom + Vector4(0.0, 0.22, 0.16, 0.0), bloom)
		await _shot("%s_bloom" % key)
		mi.basis = Basis4D.from_xw(deg_to_rad(90.0))
		await _shot("%s_bloom_xw90" % key)
		mi.queue_free()
		await _frames(1)


func _flies() -> void:
	var mat: TetraMaterial4D = Fly.material()
	for key in Fly.KEYS:
		var ms: Array = Fly.meshes(key)
		var nodes: Array = []
		for k in 3:
			var mi := MeshInstance4D.new()
			mi.mesh = ms[k]
			mi.material_override = mat
			_root.add_child(mi)
			nodes.append(mi)
		var s: float = 4.0
		var at := Vector4(0.0, 0.5, 0.0, 0.0)
		for pose in [["open", 0.15], ["mid", 0.8], ["closed", 1.35]]:
			var b := Projection(Vector4(s, 0, 0, 0), Vector4(0, s, 0, 0), Vector4(0, 0, s, 0), Vector4(0, 0, 0, s))
			for k in 3:
				(nodes[k] as Node4D).position = at
			(nodes[0] as Node4D).basis = b
			(nodes[1] as Node4D).basis = b * Kit.rot_z(float(pose[1]))
			(nodes[2] as Node4D).basis = b * Kit.rot_z(-float(pose[1]))
			_look(at + Vector4(0.0, 0.62, 0.12, 0.0), at)
			await _shot("fly_%s_%s_top" % [key, pose[0]])
			_look(at + Vector4(0.45, 0.2, 0.25, 0.0), at)
			await _shot("fly_%s_%s_side" % [key, pose[0]])
		for n in nodes:
			(n as Node).queue_free()
		await _frames(1)
