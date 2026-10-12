extends SceneTree
## Voxel Lab, round 3 (9 Oct): the spots Ramon's walkthrough named, photographed before and after. From
## the player's own camera (where you stand and look) and from a free camera (the ceilings and walls
## where the rooms meet, looked at up close, and from above with the ceilings hidden). Frames to
## smoke_test_output/voxel_lab/audit/<tag>_<name>.png; run with tag=before or tag=after.
##   VoxelLab/run.sh windowed audit res://ramon/VoxelLab/scripts/_capture_audit_runner.gd -- tag=before

const OUT := "res://smoke_test_output/voxel_lab/audit/"

## [name, "walk", Vector2(x, z), facing degrees] or [name, "free", Vector3 eye, Vector2(yaw, pitch) degrees]
## or [name, "top", Vector3 eye] (straight down, the ceilings hidden).
const SHOTS := [
	["01_spawn", "walk", Vector2(0, 17.5), 0.0],
	["02_corridor", "walk", Vector2(0, 16.0), 0.0],
	["03_back_to_corridor", "walk", Vector2(0, 6.0), 180.0],
	["04_entrance_top", "free", Vector3(0, 2.2, 6.0), Vector2(180, 24)],
	["05_left_corner", "walk", Vector2(-1.0, 10.0), 50.0],
	["06_shelf", "walk", Vector2(6.2, 5.4), -90.0],
	["07_shelf_wall", "free", Vector3(4.6, 2.4, 5.4), Vector2(-90, 12)],
	["08_hero_ring", "walk", Vector2(0, 3.0), 0.0],
	["09_hero_far", "walk", Vector2(0, 8.0), 0.0],
	["10_builder", "walk", Vector2(-5.1, 8.7), 90.0],
	["11_builder_top", "top", Vector3(-7.0, 30.0, 8.0)],
	["12_hall_back", "walk", Vector2(0, -9.0), 0.0],
	["13_hall_back_top", "free", Vector3(0, 2.2, -6.0), Vector2(0, 26)],
	["14_gallery_back", "walk", Vector2(0, -20.0), 180.0],
	["15_gallery_front_top", "free", Vector3(0, 2.2, -22.0), Vector2(180, 26)],
	["16_terrain", "walk", Vector2(0, -24.5), 90.0],
	["17_field_door", "walk", Vector2(0, -27.5), 0.0],
	["18_field_door_close", "free", Vector3(0, 1.7, -29.6), Vector2(0, 4)],
	["19_top_seam", "top", Vector3(0, 30.0, -15.0)],
	["20_top_entrance", "top", Vector3(0, 30.0, 12.0)],
	["21_passage", "free", Vector3(0, 1.7, -12.6), Vector2(0, 6)],
	["22_passage_back", "free", Vector3(0, 1.7, -18.4), Vector2(180, 6)],
	# Round 5: Specimen 01's panel beside its ring, the far walkway past the field door.
	["23_hero_panel_top", "top", Vector3(-1.0, 30.0, 2.0)],
	["24_hero_panel", "walk", Vector2(0, 7.5), 0.0],
	["25_far_walk_top", "top", Vector3(0, 30.0, -33.0)],
]

var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _i: int = -1
var _tag: String = "before"
var _cam: Camera4D
var _hidden: Array = []
var _board_seen: bool = false


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "tag":
			_tag = kv[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _ready_all() -> bool:
	for s in _scene.get("stations"):
		var ex: Node = s.get("exhibit")
		if ex == null or not bool(ex.call("is_ready")):
			return false
	return true


func _process(delta: float) -> bool:
	_total += delta
	if _total > 240.0:
		print("AUDIT FAIL: timed out at shot %d" % _i)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	if bool(_scene.get("loading")):
		_board_seen = true
	_t += delta
	if _i < 0:
		if _ready_all() and _t > 2.0 and not bool(_scene.get("loading")):
			print("AUDIT the lab's own loading board on the first spawn: %s" % ("shown" if _board_seen else "not shown"))
			_next()
		elif _t > 120.0:
			print("AUDIT FAIL: not ready")
			return true
		return false
	if _t > 1.5:
		_save(String(SHOTS[_i][0]))
		_next()
		if _i >= SHOTS.size():
			print("AUDIT done")
			return true
	return false


func _next() -> void:
	_i += 1
	_t = 0.0
	for m in _hidden:
		(m as MeshInstance4D).visible = true
	_hidden = []
	if _i >= SHOTS.size():
		return
	var s: Array = SHOTS[_i]
	match String(s[1]):
		"walk":
			var at: Vector2 = s[2]
			_scene.call("go_to", Vector4(at.x, 0.05, at.y, 0.0), deg_to_rad(float(s[3])))
			var pc: Camera4D = _scene.get("player").get_node("CameraRig/Pitch/Camera4D")
			pc.make_current()
		"free", "top":
			if _cam == null:
				_cam = Camera4D.new()
				_cam.rendering_engine_name = "Cross-section"
				_scene.add_child(_cam)
			var e: Vector3 = s[2]
			_cam.global_position = Vector4(e.x, e.y, e.z, 0.0)
			if String(s[1]) == "top":
				_cam.global_basis = Basis4D.from_yz(-PI * 0.5)
				_cam.set("field_of_view_4d", 1.2)
				for m in _scene.find_children("*", "MeshInstance4D", true, false):
					var mi: MeshInstance4D = m
					if mi.visible and mi.global_position.y > 7.0 and not String(mi.get_path()).contains("Lights"):
						mi.visible = false
						_hidden.append(mi)
			else:
				var yp: Vector2 = s[3]
				_cam.global_basis = Basis4D.from_zx(deg_to_rad(yp.x)) * Basis4D.from_yz(deg_to_rad(yp.y))
				_cam.set("field_of_view_4d", 1.35)
			_cam.make_current()


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + _tag + "_" + name + ".png"))
	print("AUDIT saved %s" % name)
