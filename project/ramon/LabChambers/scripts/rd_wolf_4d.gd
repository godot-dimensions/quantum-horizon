@tool
extends Node4D

## The third exhibit for the goat room's pedestal: the wolf, from the lab's copy of the pen's wolf
## (LabKit/carried/Model/wolf.tscn; the pen's own is never touched). One loft rig of twenty balls in
## pen metres, its legs, tail and ears branches that the rig mirrors. Same interface and the same
## story as the goat and the chicken (kit_presentation.gd).
##
## OPTIMISED FOR THE ROOM (Ramon, 4 Oct: "add the wolf, but this one might need some optimization,
## you have to check"). Measured (_probe_wolf_cost_runner.gd): its own walker, as carried, cuts the
## hide into pieces but re-poses a band of skin round every joint vertex by vertex each frame, at a
## reduced roundness, for 0.25 ms of script a tick and four meshes rewritten every frame; the rigid
## walk the goat uses (goat_walk_4d.gd: pieces lofted once at full roundness, transforms only) costs
## 0.012 ms. So here:
##   no live loft   the rig is told to draw nothing and not to watch its balls before it enters
##                  the tree, so it does not loft itself on arrival (190 ms); its build stages and
##                  finished hide are baked once (beside the goat's) and only read afterwards
##   rigid walk     goat_walk_4d.gd on its "Hip" legs, its pieces baked as "wolf_walk_*"
##   its eyes       ride the walk's body piece while it walks
##
## THE BUILD, in six steps of its own balls: the trunk, the head, the forelegs, the hind legs, the
## tail, the ears (STAGES), each lofted with the balls so far.
##
## NO class_name (engine_gotchas.md).

const SOURCE := "res://ramon/LabKit/carried/Model/wolf.tscn"
const WALK := preload("res://ramon/LabChambers/scripts/goat_walk_4d.gd")
const Bench := preload("res://ramon/LabChambers/kit/kit_bench.gd")
const Presentation := preload("res://ramon/LabChambers/kit/kit_presentation.gd")
const BAKED := "res://ramon/LabKit/carried/chickenpen/theatre/baked/"
const CODE := "WF-03"
const GROW_SECONDS := 2.6
## The order the balls come in, and how many are in after each build step.
const ORDER: PackedStringArray = ["Rump", "Loin", "Barrel", "Chest", "Ruff", "Skull", "Muzzle", "Nose", "ForeHip", "ForeKnee", "ForeFoot",
	"HindHip", "HindKnee", "HindFoot", "TailBase", "TailMid", "TailEnd", "TailTip", "EarBase", "EarTip"]
const STAGES := [4, 8, 11, 14, 18, 20]

## How tall it stands on the plinth, metres, once grown (it arrives at its real height).
@export var stand_height: float = 3.0
@export var turn_speed: float = 5.0
var grow_in: bool = true

var _stand: Node4D
var _model: Node4D
var _rig: MeshInstance4D
var _walker: Node4D
var _balls: Array = []          # the rig's balls, in ORDER
var _stages: Array = []         # ArrayTetraMesh4D per build step; the last is the finished hide
var _shown: int = -1
var _yaw: float = 0.6
var _step: int = -1
var _grow: float = 1.0
var _small: float = 0.3
var _gold: WireMaterial4D
var _eyes: Array = []           # the eyes' copies on the walk's body piece
var _bench: Dictionary = {}
var _cost_ms: float = -1.0
var _samples: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_stand = Node4D.new()
	_stand.name = "Stand"
	add_child(_stand)
	_stand.basis = Basis4D.from_zx(_yaw)
	if Engine.is_editor_hint():
		return
	var wolf: Node = (load(SOURCE) as PackedScene).instantiate()
	var own_walker: Node = wolf.get_node_or_null("Walker")
	if own_walker != null:
		wolf.remove_child(own_walker)
		own_walker.free()
	_rig = wolf.get_node_or_null("Hide") as MeshInstance4D
	if _rig == null:
		wolf.free()
		return
	# No loft on arrival: it draws nothing and does not watch its balls until it is given a mesh.
	_rig.set("live_rebuild", false)
	_rig.set("edit_balls_only", true)
	_model = wolf as Node4D
	_stand.add_child(_model)
	_rig.set("edit_balls_only", false)
	for nm in ORDER:
		var b: Node = _find_ball(_rig, nm)
		if b != null:
			_balls.append(b)
	_gold = WireMaterial4D.new()
	_gold.albedo_color = Color(1.0, 0.74, 0.12)
	_gold.set("line_thickness", 4.0)
	if not _load_baked():
		_bake()
	_show(-1)
	_fit()
	_grow = 0.0 if grow_in else 1.0
	# The walk: rigid pieces on its "Hip" legs, a wolf's quicker step.
	_walker = Node4D.new()
	_walker.name = "Walk"
	_walker.set_script(WALK)
	_walker.set("leg_tops", PackedStringArray(["Hip"]))
	_walker.set("bake_tag", "wolf_walk")
	_walker.set("period", 1.0)
	_walker.set("stride", 0.3)
	_walker.set("lift", 0.12)
	_walker.set("bob", 0.025)
	_walker.set("roll", 0.02)
	_model.add_child(_walker)
	if bool(_walker.call("attach", _rig)):
		var body: Node4D = _walker.get("_body")
		var pivot: Vector4 = _walker.get("_pivot")
		for nm in ["EyeL", "EyeR"]:
			var e: MeshInstance4D = _rig.get_node_or_null(nm) as MeshInstance4D
			if e != null and body != null:
				var copy := e.duplicate() as MeshInstance4D
				copy.position = e.position - pivot
				body.add_child(copy)
				_eyes.append(copy)
	else:
		_walker.queue_free()
		_walker = null
	data()
	w_profile()
	shape()
	wire()
	_turn(_yaw)
	_bench = Bench.read(CODE)
	if not _bench.has("build_ms") or int(_bench.get("tetra", -1)) != _tetra():
		get_tree().create_timer(2.5).timeout.connect(_measure)


func _find_ball(n: Node, nm: String) -> Node:
	for c in n.get_children():
		if c.has_method("get_loft_section"):
			if String(c.name) == nm:
				return c
			var deeper: Node = _find_ball(c, nm)
			if deeper != null:
				return deeper
	return null


func _tetra() -> int:
	var m: ArrayTetraMesh4D = _stages.back() if not _stages.is_empty() else null
	return m.get_simplex_cell_vertex_indices().size() / 4 if m != null else 0


# -- the baked build -----------------------------------------------------------------------------------

func _load_baked() -> bool:
	if not FileAccess.file_exists(BAKED + "wolf.cfg"):
		return false
	var cfg := ConfigFile.new()
	if cfg.load(BAKED + "wolf.cfg") != OK or int(cfg.get_value("wolf", "stages", 0)) != STAGES.size():
		return false
	var out: Array = []
	for i in STAGES.size():
		var m := load(BAKED + "wolf_stage_%02d.res" % i) as ArrayTetraMesh4D if ResourceLoader.exists(BAKED + "wolf_stage_%02d.res" % i) else null
		if m == null:
			return false
		out.append(m)
	_stages = out
	return true


## Lofts each build step with only its balls attached (the rest taken off, last first, and put back
## where they were), and saves them. Once; afterwards they are read.
func _bake() -> void:
	var t0: int = Time.get_ticks_usec()
	var all: Array = []
	_collect(_rig, all)
	_stages.clear()
	for s in STAGES.size():
		var keep: Dictionary = {}
		for i in mini(int(STAGES[s]), ORDER.size()):
			keep[ORDER[i]] = true
		var parked: Array = []
		for i in range(all.size() - 1, -1, -1):
			var b: Node = all[i]
			var parent: Node = b.get_parent()
			if keep.has(String(b.name)) or parent == null:
				continue
			if parent == _rig or keep.has(String(parent.name)):
				parked.append([b, parent, b.get_index()])
				parent.remove_child(b)
		_rig.call("build", false)
		var m: ArrayTetraMesh4D = _rig.mesh as ArrayTetraMesh4D
		_stages.append(m.duplicate(true) if m != null else ArrayTetraMesh4D.new())
		for j in range(parked.size() - 1, -1, -1):
			var rec: Array = parked[j]
			(rec[1] as Node).add_child(rec[0])
			(rec[1] as Node).move_child(rec[0], int(rec[2]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKED))
	for i in _stages.size():
		ResourceSaver.save(_stages[i], BAKED + "wolf_stage_%02d.res" % i)
	var cfg := ConfigFile.new()
	cfg.set_value("wolf", "stages", _stages.size())
	cfg.set_value("wolf", "balls_at_stage", STAGES)
	cfg.save(BAKED + "wolf.cfg")
	print("[wolf] baked %d build steps in %.0f ms" % [_stages.size(), Bench.ms_since(t0)])


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c.has_method("get_loft_section"):
			out.append(c)
			_collect(c, out)


## Lofts the wolf whole and one leg pair without showing either; the times go in the bench book.
func _measure() -> void:
	if _rig == null or not is_inside_tree():
		return
	var chains: Array = _rig.call("_collect_chains")
	var t0: int = Time.get_ticks_usec()
	for i in chains.size():
		_rig.call("_build_chain", chains[i], false, i > 0, false)
	var build_ms: float = Bench.ms_since(t0)
	var limb_ms: float = -1.0
	for ch in chains:
		var chain: Array = ch
		if chain.size() >= 4 and String((chain[1] as Node).name).ends_with("Hip"):
			var t1: int = Time.get_ticks_usec()
			_rig.call("_build_chain", chain, false, true, false)
			limb_ms = Bench.ms_since(t1) * 0.5   # a leg chain lofts its mirrored twin too
			break
	_bench = {"name": "Wolf", "icon": "wolf", "balls": _balls.size(), "tetra": _tetra(), "build_ms": build_ms, "limb_ms": limb_ms,
		"limbs": 4, "pieces": 9, "measured": Time.get_date_string_from_system()}
	Bench.write(CODE, _bench)


# -- standing, growing, turning ------------------------------------------------------------------------

## Scaled to the stage, stood on its floor and centred over the plinth, from its balls (and their
## mirrored twins); it arrives at its own height, which is real: it is modelled in metres.
func _fit() -> void:
	var lo := Vector4(INF, INF, INF, 0.0)
	var hi := Vector4(-INF, -INF, -INF, 0.0)
	for b in _balls:
		var p: Vector4 = _rig.call("_position_in_rig", b)
		var r: float = float(b.get("radius"))
		for sx in [1.0, -1.0]:
			lo = Vector4(minf(lo.x, p.x * sx - r), minf(lo.y, p.y - r), minf(lo.z, p.z - r), 0.0)
			hi = Vector4(maxf(hi.x, p.x * sx + r), maxf(hi.y, p.y + r), maxf(hi.z, p.z + r), 0.0)
	if not is_finite(lo.y) or hi.y <= lo.y:
		return
	var h: float = hi.y - lo.y
	var k: float = stand_height / h
	_model.basis = Projection(Vector4(k, 0, 0, 0), Vector4(0, k, 0, 0), Vector4(0, 0, k, 0), Vector4(0, 0, 0, k))
	_model.position = Vector4(-(lo.x + hi.x) * 0.5 * k, -lo.y * k, -(lo.z + hi.z) * 0.5 * k, 0.0)
	_small = clampf(h / stand_height, 0.02, 1.0)


func _turn(yaw: float) -> void:
	var g: float = lerpf(_small, 1.0, ease(_grow, -2.2))
	_stand.basis = Basis4D.from_zx(yaw) * Projection(Vector4(g, 0, 0, 0), Vector4(0, g, 0, 0), Vector4(0, 0, g, 0), Vector4(0, 0, 0, g))


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and _grow < 1.0:
		_grow = minf(_grow + delta / GROW_SECONDS, 1.0)


func grown() -> bool:
	return _grow >= 1.0


## A build step (its balls ringed in gold), or -1 for the finished hide.
func _show(step: int) -> void:
	if _rig == null or _stages.is_empty():
		return
	_shown = step
	_rig.mesh = _stages[clampi(step, 0, _stages.size() - 1)] if step >= 0 else _stages.back()
	var lit: int = int(STAGES[step]) if step >= 0 else 0
	for i in _balls.size():
		var b: MeshInstance4D = _balls[i] as MeshInstance4D
		if b == null:
			continue
		b.visible = i < lit
		if i < lit:
			b.material_override = _gold


func _walking(on: bool, xray: bool) -> void:
	if _walker == null:
		return
	_walker.call("set_walking", on)
	_walker.call("set_xray", on and xray)
	for e in _eyes:
		(e as Node4D).visible = not xray


## Drives part `key` of the presentation (kit_presentation.gd, the same story for every animal) at
## `t` of its `length` seconds. Returns {"slice": -1..1} when the part moves the slice.
func play_part(key: String, t: float, length: float) -> Dictionary:
	if _rig == null or _stages.is_empty():
		return {}
	_walking(key == "rig" or key == "walk", key == "rig")
	match key:
		"balls":
			_turn(0.55)
			var every: float = maxf((length - 1.2) / float(_stages.size()), 0.1)
			var step: int = clampi(int(floor((t - 0.3) / every)), 0, _stages.size() - 1)
			if step != _shown:
				_show(step)
		"skin":
			if _shown != -1:
				_show(-1)
			_turn(0.55 + t * 0.12)
		"slice":
			if _shown != -1:
				_show(-1)
			_turn(0.2)
			return {"slice": sin(clampf(t / maxf(length - 0.5, 0.1), 0.0, 1.0) * TAU) * 0.55}
		"rig", "walk":
			if _shown != -1:
				_show(-1)
			var tw: float = t + (Presentation.length_of("rig") if key == "walk" else 0.0)
			_turn(1.25 + tw * 0.03)
			if _walker != null:
				var t0: int = Time.get_ticks_usec()
				_walker.call("pose", tw)
				var ms: float = Bench.ms_since(t0)
				_cost_ms = ms if _cost_ms < 0.0 else lerpf(_cost_ms, ms, 0.05)
				_samples.append(ms)
				if _samples.size() > 180:
					_samples = _samples.slice(_samples.size() - 180)
	return {}


func end_cinematic() -> void:
	_walking(false, false)
	_step = -1
	_show(-1)
	_turn(_yaw)


func action_label() -> String:
	return "Add a ball"


func action() -> String:
	if _rig == null or _stages.is_empty():
		return ""
	_walking(false, false)
	_step = -1 if _step >= _stages.size() - 1 else _step + 1
	_show(_step)
	if _step < 0:
		return "%d balls. The skin is lofted between them." % _balls.size()
	return "%d balls placed" % int(STAGES[_step])


func idle(delta: float) -> void:
	if _stand == null:
		return
	_yaw += deg_to_rad(turn_speed) * delta
	_turn(_yaw)


func stand_basis() -> Projection:
	return _stand.basis if _stand != null else Projection.IDENTITY


# -- what the room reads ---------------------------------------------------------------------------

func _finished() -> ArrayTetraMesh4D:
	return _stages.back() if not _stages.is_empty() else null


func w_extent() -> float:
	var m: ArrayTetraMesh4D = _finished()
	if m == null:
		return 1.0
	var reach: float = 0.0
	for v in m.get_vertex_positions():
		reach = maxf(reach, absf(v.w))
	return maxf(0.2, reach * (_model.basis * Vector4(0, 0, 0, 1)).length())


var _data: Dictionary = {}


func data() -> Dictionary:
	if not _data.is_empty() or _finished() == null:
		return _data
	var bars: Array = []
	for m in _stages:
		bars.append(int((m as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4))
	var verts: int = _finished().get_vertex_positions().size()
	var tetra: int = _tetra()
	_data = {
		"name": "Wolf",
		"icon": "wolf",
		"code": CODE,
		"title": "THE WOLF, MEASURED",
		"rows": [["Balls placed by hand", str(_balls.size())], ["Tetrahedra", str(tetra)], ["Build steps", str(_stages.size())], ["Reach through W", "%.2f m" % w_extent()]],
		"bars": bars,
		"bar_label": "Tetrahedra after each build step",
		"stats": {"balls": _balls.size(), "tetra": tetra, "stages": _stages.size(), "reach": w_extent(), "verts": verts,
			"mb": (float(verts) * 32.0 + float(tetra) * 16.0) / 1048576.0},
	}
	return _data


func live() -> Array:
	return [["Showing", ("build step %d of %d" % [_shown + 1, _stages.size()]) if _shown >= 0 else "the finished hide"], ["Balls in view", str(balls_in_view())]]


func balls_in_view() -> int:
	return int(STAGES[_shown]) if _shown >= 0 else _balls.size()


func stage_in_view() -> int:
	return _shown


func bench() -> Dictionary:
	var out: Dictionary = _bench.duplicate()
	out["anim_ms"] = _cost_ms
	out["samples"] = _samples
	out["walking"] = _walker != null and bool(_walker.call("is_walking"))
	return out


var _profile: Dictionary = {}


func w_profile(count: int = 48) -> Dictionary:
	if not _profile.is_empty() or _finished() == null:
		return _profile
	var verts: PackedVector4Array = _finished().get_vertex_positions()
	var cells: PackedInt32Array = _finished().get_simplex_cell_vertex_indices()
	var reach: float = 0.0
	for v in verts:
		reach = maxf(reach, absf(v.w))
	if reach <= 0.0:
		return {}
	var bins := PackedFloat32Array()
	bins.resize(count)
	bins.fill(0.0)
	for t in range(0, cells.size() - 3, 4):
		var a: float = INF
		var b: float = -INF
		for k in 4:
			var w: float = verts[cells[t + k]].w
			a = minf(a, w)
			b = maxf(b, w)
		for i in range(clampi(int(floor((a / reach * 0.5 + 0.5) * float(count - 1))), 0, count - 1), clampi(int(ceil((b / reach * 0.5 + 0.5) * float(count - 1))), 0, count - 1) + 1):
			bins[i] += 1.0
	var most: float = 0.0
	for x in bins:
		most = maxf(most, x)
	if most > 0.0:
		for i in count:
			bins[i] /= most
	_profile = {"bins": bins, "reach": w_extent()}
	return _profile


var _shape: Dictionary = {}


func shape() -> Dictionary:
	if not _shape.is_empty() or _finished() == null:
		return _shape
	var verts: PackedVector4Array = _finished().get_vertex_positions()
	var pts := PackedVector2Array()
	for v in verts:
		pts.append(Vector2(v.z, v.y))
	var out_balls: Array = []
	var bones: Array = []
	for i in _balls.size():
		var b: Node = _balls[i]
		var p: Vector4 = _rig.call("_position_in_rig", b)
		out_balls.append([Vector2(p.z, p.y), float(b.get("radius")), String(b.name)])
		var j: int = _balls.find(b.get_parent())
		if j >= 0:
			bones.append([j, i])
	# The spine, ball to ball.
	for i in range(7):
		if _balls.size() > i + 1 and (_balls[i + 1] as Node).get_parent() == _rig and (_balls[i] as Node).get_parent() == _rig:
			bones.append([i, i + 1])
	_shape = {"points": pts, "balls": out_balls, "bones": bones}
	return _shape


func cloud() -> PackedVector4Array:
	return wire()


var _wire: PackedVector4Array = PackedVector4Array()


func wire() -> PackedVector4Array:
	if not _wire.is_empty() or _finished() == null:
		return _wire
	var verts: PackedVector4Array = _finished().get_vertex_positions()
	var cells: PackedInt32Array = _finished().get_simplex_cell_vertex_indices()
	var lo := Vector4(INF, INF, INF, INF)
	var hi := Vector4(-INF, -INF, -INF, -INF)
	for v in verts:
		lo = Vector4(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z), minf(lo.w, v.w))
		hi = Vector4(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z), maxf(hi.w, v.w))
	var cell: float = maxf(maxf(hi.y - lo.y, hi.z - lo.z), 0.001) / 17.0
	var seen: Dictionary = {}
	var keep: Dictionary = {}
	for t in range(0, cells.size() - 3, 4):
		for e in [[0, 1], [0, 2], [0, 3], [1, 2], [1, 3], [2, 3]]:
			var i0: int = cells[t + e[0]]
			var i1: int = cells[t + e[1]]
			var key := Vector2i(mini(i0, i1), maxi(i0, i1))
			if seen.has(key):
				continue
			seen[key] = true
			if verts[i0].distance_to(verts[i1]) < cell * 0.45:
				continue
			var c: Vector4 = (verts[i0] + verts[i1]) * 0.5
			var ck := Vector4i(int(floor(c.x / cell)), int(floor(c.y / cell)), int(floor(c.z / cell)), int(floor(c.w / cell)))
			if not keep.has(ck):
				keep[ck] = key
	for key in keep.values():
		_wire.append(verts[key.x])
		_wire.append(verts[key.y])
	return _wire


func slice_in_rig() -> Array:
	if _model == null or not _model.is_inside_tree():
		return []
	var gb: Projection = _model.global_basis
	return [Vector4(gb.x.w, gb.y.w, gb.z.w, gb.w.w), _model.global_position.w]
