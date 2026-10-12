extends SceneTree

## Case study 4: the oak's skeleton. The carried generator's oak (its trunk bent over, its crown
## thin) against the paper's own space colonization (botany/colonize_4d.gd) in a few settings,
## lofted with the room's form and the GPU leaves. Prints each one's numbers: nodes, steps, points
## left, time, the trunk's lean (degrees from upright, measured from the root to where the trunk is
## 3 m up) and the crown's balance (how far the tips' middle sits off the trunk, against the crown's
## half width). Windowed; frames in smoke_test_output/arboretum/oak/.
##
## Args after --: seeds to try for the chosen settings (default: the variants on seed 11).

const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const RoomScript := preload("res://ramon/Arboretum/carried/LabKit/lab_room_4d.gd")
const KitStyle := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")
const Sun := preload("res://ramon/Arboretum/carried/kit/kit_sun_4d.gd")

const OUT := "res://smoke_test_output/arboretum/oak/"

var _scene: Node4D
var _cam: Camera4D
var _wind: Node
var _trees: Array = []
var _leaves: Array = []
var _f: int = 0
var _deadline: int = 0
var _ready_n: int = -1


func _initialize() -> void:
	root.unfocusable = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_deadline = Time.get_ticks_msec() + 400000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _build()).call_deferred()


## The trunk's lean (degrees) and the crown's balance (0 centred, 1 a half width off).
static func measure(sk: Resource) -> Dictionary:
	var pos: PackedVector4Array = sk.get("positions")
	var br: Array = sk.get("branches")
	var trunk: PackedInt32Array = (br[0] as Dictionary)["nodes"]
	var top: Vector4 = pos[trunk[trunk.size() - 1]]
	for n in trunk:
		if pos[n].y >= 3.0:
			top = pos[n]
			break
	var off: float = Vector3(top.x, top.z, top.w).length()
	var lean: float = rad_to_deg(atan2(off, maxf(top.y, 0.01)))
	var tips: PackedInt32Array = sk.call("tips")
	var c := Vector4.ZERO
	for n in tips:
		c += pos[n]
	c /= maxf(float(tips.size()), 1.0)
	var b: Dictionary = sk.call("bounds")
	var half: float = maxf(((b["max"] as Vector4).x - (b["min"] as Vector4).x) * 0.5, 0.1)
	var summ: Dictionary = sk.call("summary")
	return {"lean_deg": snappedf(lean, 0.1), "balance": snappedf(Vector3(c.x, c.z, c.w).length() / half, 0.01),
		"h": snappedf(float(summ["height"]), 0.01), "wide": snappedf(float(summ["width"]), 0.01), "tips": tips.size()}


func _variants() -> Array:
	var seeds: PackedStringArray = OS.get_cmdline_user_args()
	if not seeds.is_empty():
		var out: Array = []
		for s in seeds:
			out.append(["seed_%s" % s, int(s), {}, {}])
		return out
	# [name, seed, growth overrides, loft overrides]
	var g: Dictionary = {"sc": {"cone": 60.0, "tropism": Vector4(0.0, -0.1, 0.0, 0.0)}}
	var g50: Dictionary = {"sc": {"segment": 0.5, "kill": 1.0, "influence": 3.0, "cone": 60.0, "tropism": Vector4(0.0, -0.1, 0.0, 0.0), "max_nodes": 1500}}
	var r1: Dictionary = {"by_radius": [[0.15, 5, 10, 2], [0.07, 4, 8, 1], [0.035, 3, 5, 1], [0.0, 2, 4, 0]]}
	var r2: Dictionary = {"by_radius": [[0.18, 5, 10, 2], [0.09, 4, 7, 1], [0.045, 3, 5, 0], [0.0, 2, 3, 0]]}
	return [
		["leaf_now", 11, g, r2, {}],
		["leaf_b", 11, g, r2, {"leaf_w": 0.45, "leaf_size": 0.2}],
		["leaf_c", 11, g, r2, {"leaf_w": 0.6, "leaf_size": 0.22, "per_node": 44}],
		["leaf_d", 11, g, r2, {"leaf_w": 0.6, "leaf_size": 0.22, "per_node": 44, "spread": 0.6}],
		["leaf_e", 11, g, r2, {"leaf_w": 0.8, "leaf_size": 0.26, "per_node": 40, "spread": 0.55}],
	]


func _build() -> void:
	_scene = Node4D.new()
	root.add_child(_scene)
	var room := Node4D.new()
	room.set_script(RoomScript)
	room.set("ground_size", Vector4(90, 0.5, 40, 30))
	room.set("mood_overrides", KitStyle.ROOM_LIGHT.duplicate(true))
	_scene.add_child(room)
	room.call("set_mood", "bright", true, false)
	var sun := Node4D.new()
	sun.set_script(Sun)
	sun.set("target", Vector3(0, 0, 0))
	_scene.add_child(sun)
	sun.position = Vector4(4.0, 16.0, 10.0, 0.0)
	_wind = Node.new()
	_wind.set_script(Wind)
	_wind.set("enabled", false)
	_scene.add_child(_wind)
	var cands: Array = _variants()
	var gap: float = 12.0
	for i in cands.size():
		var c: Array = cands[i]
		var sk: Resource = Species.grow("oak", int(c[1]), c[2])
		var st: Dictionary = sk.get("stats")
		var lo: Dictionary = {"sides": [[5, 10], [4, 8], [3, 6], [3, 5], [2, 4]], "root_sink": 0.5, "min_r": 0.014}
		if c.size() > 3:
			lo.merge(c[3], true)
		var w: Dictionary = LoftTree.build(sk, Species.loft_opts(lo))
		print("OAK %s: %s  grow %.0f ms  steps %s  left %s/%s  loft %d tets in %.0f ms  %s" % [c[0], str(measure(sk)), float(st.get("grow_ms", 0.0)),
			str(st.get("steps", "-")), str(st.get("points_left", "-")), str(st.get("points", "-")), w["tets"], w["ms"], str(sk.call("summary"))])
		var t := Node4D.new()
		t.name = String(c[0])
		_scene.add_child(t)
		t.position = Vector4((float(i) - float(cands.size() - 1) * 0.5) * gap, 0, 0, 0)
		var mi := MeshInstance4D.new()
		mi.mesh = w["mesh"]
		var summ: Dictionary = sk.call("summary")
		var mat: TetraMaterial4D = Style.tree_material(sk, float(summ["height"]), true)
		mi.material_override = mat
		t.add_child(mi)
		_wind.call("register", Style.shader_of(mat), t)
		var lf := Node4D.new()
		lf.set_script(Leaves)
		lf.set("per_node", int(Species.form()["per_node"]))
		lf.set("leaf_w", float(Species.form()["leaf_w"]))
		if c.size() > 4:
			for key in (c[4] as Dictionary):
				lf.set(key, c[4][key])
		t.add_child(lf)
		lf.call("grow_leaves", sk, 5)
		print("OAK %s leaves %d" % [c[0], int(lf.get("count"))])
		_trees.append(t)
		_leaves.append(lf)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_scene.add_child(_cam)
	var span: float = float(cands.size()) * gap
	var eye := Vector4(0.0, 4.5, span * 0.62 + 6.0, 0.0)
	var at := Vector4(0.0, 3.8, 0.0, 0.0)
	var d: Vector4 = at - eye
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))
	_cam.set("field_of_view_4d", 1.0)
	_cam.current = true
	_ready_n = _f
	_aim(-1)


## The camera on tree `i` (13 m off, a little above), or on all of them (-1).
func _aim(i: int) -> void:
	var at := Vector4(0.0, 3.8, 0.0, 0.0)
	var eye := Vector4(0.0, 4.5, float(_trees.size()) * 12.0 * 0.62 + 6.0, 0.0)
	if i >= 0:
		at = (_trees[i] as Node4D).position + Vector4(0.0, 3.6, 0.0, 0.0)
		eye = at + Vector4(-3.0, 0.6, 12.5, 0.0)
	var d: Vector4 = at - eye
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))


func _process(_d: float) -> bool:
	_f += 1
	if Time.get_ticks_msec() > _deadline:
		quit(2)
		return true
	if _ready_n < 0:
		return false
	# Per tree: leaves, wood, turned a quarter through W (with leaves): set on frame 2 of each 15,
	# shot on frame 14.
	var k: int = (_f - _ready_n) / 15
	var r: int = (_f - _ready_n) % 15
	var i: int = k / 3
	var part: int = k % 3
	if i >= _trees.size():
		quit()
		return true
	var t: Node4D = _trees[i]
	var lf: Node = _leaves[i]
	if r == 2:
		match part:
			0:
				_aim(i)
				t.basis = Projection.IDENTITY
				lf.set("enabled", true)
			1:
				lf.set("enabled", false)
			2:
				lf.set("enabled", true)
				t.basis = Basis4D.from_xw(PI * 0.5)
	elif r == 14:
		_shot("%s_%d" % [t.name, part])
	return false


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("OAK shot ", name)
