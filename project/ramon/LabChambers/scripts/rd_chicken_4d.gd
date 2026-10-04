@tool
extends Node4D

## The second exhibit for the goat room's pedestal: the pen's chicken, the playable world's own,
## from the lab's copy (LabKit/carried/chickenpen/chicken.tscn; Ramon, 4 Oct: "the one from
## playable world is the best ... I don't think you need to alter the chicken"; "never adjust
## anything from the playable world ... just copy stuff over"). The scene is instanced as it is;
## only this instance leaves out its pen wandering (Agent) and swaps its walker for the lab's
## on-the-spot one (exhibit_chicken_walker_4d.gd, which extends the pen's without editing it).
## Same interface as rd_goat_4d.gd, so the showcase, the research panel, the slice view and the
## data panel read it the same way.
##
## IT GROWS IN: it arrives at a real chicken's size and grows on the turning pedestal to nearly the
## goat's ("start much smaller, hinting at actual size, and then grow to the size of the goat").
##
## ITS PRESENTATION, from its five loft rigs (Body, NeckHead with its wattle, LegL, LegR, Wing):
##   THE BALLS  the rigs come in one at a time, the newest with its balls ringed in gold
##   THE SKIN   all of it, turning
##   THE SLICE  through W, as the goat
##   THE WALK   the pen's own walk: rigid leg halves hinged at the ankle, the body rocking over the
##              planted foot, the head held still against it, and its peck about the base of the
##              neck; here on the spot, with a flutter hop now and then (Ramon: "make it walk, and
##              pick, and maybe fly up too ... centered to the pedestal")
##   THE RIG    the x-ray: the skin gone, the balls as gold rings with gold bones, still walking
##
## NO class_name (engine_gotchas.md).

const SOURCE := "res://ramon/LabKit/carried/chickenpen/chicken.tscn"
const WALKER := preload("res://ramon/LabChambers/scripts/exhibit_chicken_walker_4d.gd")
const Mats := preload("res://ramon/LabKit/lab_materials.gd")
## The order the rigs come in during the build.
const ORDER: PackedStringArray = ["Body", "LegL", "LegR", "Wing", "NeckHead"]
## A real chicken's height, metres: where it starts growing from.
const REAL_HEIGHT := 0.5
const GROW_SECONDS := 2.6

## How tall the chicken stands on the plinth, in metres, once grown.
@export var stand_height: float = 3.1
## The turntable, in degrees a second, outside the sequence.
@export var turn_speed: float = 5.0
## Whether it arrives small and grows (the showcase sets this when it swaps exhibits).
var grow_in: bool = true

var _stand: Node4D
var _model: Node4D
var _walker: Node
var _rigs: Array = []          # MeshInstance4D, in ORDER
var _sub_rigs: Array = []      # rigs hanging inside them (the wattle)
var _meshes: Dictionary = {}   # instance id -> the mesh a rig gave up for the x-ray
var _yaw: float = 0.6
var _step: int = -1
var _shown_step: int = -1
var _gold: WireMaterial4D
var _walking: bool = false
var _xray: bool = false
var _xray_parts: Array = []
var _leg_bones: Array = []     # [rig, upper ball, lower ball, bone mesh], laid each frame
var _grow: float = 1.0
var _small: float = 0.2


func _ready() -> void:
	_stand = Node4D.new()
	_stand.name = "Stand"
	add_child(_stand)
	_stand.basis = Basis4D.from_zx(_yaw)
	if Engine.is_editor_hint():
		return
	var bird: Node = (load(SOURCE) as PackedScene).instantiate()
	# Only the animal: its pen wandering stays in the pen, and its walker is the lab's.
	var agent: Node = bird.get_node_or_null("Agent")
	if agent != null:
		bird.remove_child(agent)
		agent.free()
	# Nor its red wing mark (Ramon, 4 Oct: "just remove the red wing mark, its useless").
	var mark: Node = bird.get_node_or_null("Wing/RightWingMark")
	if mark != null:
		mark.get_parent().remove_child(mark)
		mark.free()
	_walker = bird.get_node_or_null("Walker")
	if _walker != null:
		_walker.set_script(WALKER)
		_walker.set("peck_interval_min", 2.0)
		_walker.set("peck_interval_max", 3.5)
	_model = bird as Node4D
	_model.position = Vector4.ZERO
	_stand.add_child(_model)
	# Standing still until THE WALK (a node with _physics_process turns it on when it is ready).
	if _walker != null:
		_walker.set_physics_process(false)
	for nm in ORDER:
		var r: Node = _model.get_node_or_null(nm)
		if r != null and r is MeshInstance4D:
			_rigs.append(r)
			_sub_rigs.append_array(_rigs_inside(r))
	_fit()
	_small = clampf(REAL_HEIGHT / maxf(stand_height, 0.01), 0.02, 1.0)
	_grow = 0.0 if grow_in else 1.0
	_gold = WireMaterial4D.new()
	_gold.albedo_color = Color(1.0, 0.74, 0.12)
	_gold.set("line_thickness", 4.0)
	_build_bones()
	_show(-1)
	# What the room reads, worked out now, while the legs are still whole (the walker cuts each in
	# two on its first step).
	data()
	w_profile()
	shape()
	wire()
	_turn(_yaw)


## Scaled to the stage, stood on its floor and centred over the plinth's middle (so it turns on
## the spot), from the balls' own extent.
func _fit() -> void:
	var lo := Vector4(INF, INF, INF, 0.0)
	var hi := Vector4(-INF, -INF, -INF, 0.0)
	for b in _all_balls():
		var p: Vector4 = _in_model(b)
		var r: float = float(b.get("radius"))
		lo = Vector4(minf(lo.x, p.x - r), minf(lo.y, p.y - r), minf(lo.z, p.z - r), 0.0)
		hi = Vector4(maxf(hi.x, p.x + r), maxf(hi.y, p.y + r), maxf(hi.z, p.z + r), 0.0)
	if not is_finite(lo.y) or hi.y <= lo.y:
		return
	var k: float = stand_height / (hi.y - lo.y)
	_model.basis = Projection(Vector4(k, 0, 0, 0), Vector4(0, k, 0, 0), Vector4(0, 0, k, 0), Vector4(0, 0, 0, k))
	_model.position = Vector4(-(lo.x + hi.x) * 0.5 * k, -lo.y * k, -(lo.z + hi.z) * 0.5 * k, 0.0)


## The stand's turn, with the grow-in's scale.
func _turn(yaw: float) -> void:
	var g: float = lerpf(_small, 1.0, ease(_grow, -2.2))
	_stand.basis = Basis4D.from_zx(yaw) * Projection(Vector4(g, 0, 0, 0), Vector4(0, g, 0, 0), Vector4(0, 0, g, 0), Vector4(0, 0, 0, g))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _model == null:
		return
	if _grow < 1.0:
		_grow = minf(_grow + delta / GROW_SECONDS, 1.0)
	if _xray:
		_lay_leg_bones()


## Whether the grow-in is over (the showcase waits for it before measuring).
func grown() -> bool:
	return _grow >= 1.0


func _balls_of(r: Node) -> Array:
	var out: Array = []
	for c in r.get_children():
		if c.has_method("get_loft_section"):
			out.append(c)
			out.append_array(_balls_of(c))
	return out


func _rigs_inside(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is MeshInstance4D and c.has_method("build"):
			out.append(c)
		out.append_array(_rigs_inside(c))
	return out


func _all_balls() -> Array:
	var out: Array = []
	for r in _rigs:
		out.append_array(_balls_of(r))
	return out


## A ball's place in the model's own space.
func _in_model(b: Node) -> Vector4:
	var rig: Node = b
	while rig != null and not (rig is MeshInstance4D and rig.has_method("build")):
		rig = rig.get_parent()
	if rig == null:
		return (b as Node4D).position
	return (rig as Node4D).position + rig.call("_position_in_rig", b)


func _is_leg(r: Node) -> bool:
	return String(r.name).begins_with("Leg")


# -- the build ---------------------------------------------------------------------------------------

## Shows the build up to `step` (-1: all of it): the rigs come in in ORDER, the newest with its
## balls ringed; in the x-ray every ball is ringed.
func _show(step: int) -> void:
	_shown_step = step
	for i in _rigs.size():
		var r: MeshInstance4D = _rigs[i]
		r.visible = step < 0 or i <= step
		for b in _balls_of(r):
			var on: bool = (step >= 0 and i == step) or _xray
			(b as Node4D).visible = on
			if on and b is MeshInstance4D:
				(b as MeshInstance4D).material_override = _gold


func sequences() -> Array:
	return [
		{"title": "THE BALLS", "line": "A designer places its balls, rig by rig. Each one is a cross-section of the body.", "length": 6.5,
			"eye": Vector4(-3.0, 2.4, 5.0, 0.0), "look": Vector4(0.0, 1.0, 0.0, 0.0), "fov": 0.85},
		{"title": "THE SKIN", "line": "The tool lofts a skin between them. Nothing is modelled by hand.", "length": 5.5,
			"eye": Vector4(-4.0, 2.2, 3.6, 0.0), "look": Vector4(0.0, 1.1, 0.0, 0.0), "fov": 0.85},
		{"title": "THE SLICE", "line": "It is four-dimensional. Move the slice through W and the shape changes.", "length": 7.5,
			"eye": Vector4(-1.0, 2.4, 6.4, 0.0), "look": Vector4(0.4, 1.0, -0.6, 0.0), "fov": 0.95},
		{"title": "THE WALK", "line": "It walks, pecks and flutters on rigid pieces, without lofting again.", "length": 10.0,
			"eye": Vector4(-3.5, 2.0, 4.5, 0.0), "look": Vector4(0.0, 1.0, 0.0, 0.0), "fov": 0.9},
		{"title": "THE RIG", "line": "Under the skin: the balls are the joints, and they walk.", "length": 6.0,
			"eye": Vector4(-3.5, 2.0, 4.5, 0.0), "look": Vector4(0.0, 1.0, 0.0, 0.0), "fov": 0.9},
	]


func play(i: int, t: float) -> Dictionary:
	if _model == null:
		return {}
	_set_walking(i == 3 or i == 4)
	_set_xray(i == 4)
	match i:
		0:
			_turn(0.55)
			var step: int = clampi(int(floor((t - 0.3) / 1.1)), 0, _rigs.size() - 1)
			if step != _shown_step:
				_show(step)
		1:
			if _shown_step != -1:
				_show(-1)
			_turn(0.55 + t * 0.12)
		2:
			if _shown_step != -1:
				_show(-1)
			_turn(0.2)
			return {"slice": sin(clampf(t / 7.0, 0.0, 1.0) * TAU) * 0.55}
		3, 4:
			if _shown_step != -1:
				_show(-1)
			# Side on, turning a little, so the legs read.
			_turn(1.25 + (t + (10.0 if i == 4 else 0.0)) * 0.03)
	return {}


func end_cinematic() -> void:
	_set_walking(false)
	_set_xray(false)
	_step = -1
	_show(-1)
	_turn(_yaw)


func action_label() -> String:
	return "Add a rig"


## E: the next rig of the build; after the last, the whole bird; then it starts again.
func action() -> String:
	if _model == null:
		return ""
	_set_walking(false)
	_set_xray(false)
	_step = -1 if _step >= _rigs.size() - 1 else _step + 1
	_show(_step)
	if _step < 0:
		return "%d balls. The skin is lofted between them." % _all_balls().size()
	return "%s: %d balls" % [String((_rigs[_step] as Node).name), _balls_of(_rigs[_step]).size()]


func idle(delta: float) -> void:
	if _stand == null:
		return
	_yaw += deg_to_rad(turn_speed) * delta
	_turn(_yaw)


## The stand's turn (about the vertical), so the slice can be turned in the bird's own frame.
func stand_basis() -> Projection:
	return _stand.basis if _stand != null else Projection.IDENTITY


# -- the walk and the x-ray --------------------------------------------------------------------------

func _set_walking(on: bool) -> void:
	if on == _walking or _walker == null:
		return
	_walking = on
	_walker.set_physics_process(on)
	if not on and _walker.has_method("settle"):
		_walker.call("settle")


## The x-ray: every rig gives up its skin (the legs' two halves and the feet too), every ball shows
## as a gold ring, gold bones join them; the leg bones are laid afresh each frame, as the walker
## moves the leg balls.
func _set_xray(on: bool) -> void:
	if on == _xray:
		return
	_xray = on
	var skins: Array = []
	var bones: Array = _xray_parts.duplicate()
	for lb in _leg_bones:
		bones.append(lb[3])
	for r in _rigs:
		skins.append(r)
		# Whatever else hangs on a rig goes too: the legs' thigh, shank and foot, the wing's mark.
		for c in (r as Node).get_children():
			if c is MeshInstance4D and not c.has_method("get_loft_section") and not c.has_method("build") and not bones.has(c):
				(c as MeshInstance4D).visible = not on
	skins.append_array(_sub_rigs)
	for s in skins:
		var rig: MeshInstance4D = s
		if on:
			if rig.mesh != null:
				_meshes[rig.get_instance_id()] = rig.mesh
				rig.mesh = null
		elif _meshes.has(rig.get_instance_id()):
			rig.mesh = _meshes[rig.get_instance_id()]
			_meshes.erase(rig.get_instance_id())
	for x in _xray_parts:
		(x as Node4D).visible = on
	for lb in _leg_bones:
		(lb[3] as Node4D).visible = on
	_show(_shown_step)
	if on:
		_lay_leg_bones()


func _build_bones() -> void:
	for r in _rigs:
		var bl: Array = _balls_of(r)
		if _is_leg(r):
			# Hip to knee, knee to foot: the walker moves these balls, so the bones follow each frame.
			bl.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node4D).position.y > (b as Node4D).position.y)
			for i in range(mini(bl.size(), 3) - 1):
				var m: MeshInstance4D = _bone_mesh()
				(r as Node4D).add_child(m)
				_leg_bones.append([r, bl[i], bl[i + 1], m])
			continue
		for i in range(bl.size() - 1):
			var a: Vector4 = (r as Node4D).call("_position_in_rig", bl[i])
			var b: Vector4 = (r as Node4D).call("_position_in_rig", bl[i + 1])
			if a.distance_to(b) < 0.6:
				var m: MeshInstance4D = _bone_mesh()
				_lay_bone(m, a, b)
				(r as Node4D).add_child(m)
				_xray_parts.append(m)


func _lay_leg_bones() -> void:
	for lb in _leg_bones:
		_lay_bone(lb[3], (lb[1] as Node4D).position, (lb[2] as Node4D).position)


func _bone_mesh() -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.mesh = Mats.box_mesh(Vector4(0.025, 1.0, 0.025, 0.2))
	m.material_override = Mats.glow(Color(1.0, 0.80, 0.35), 1.2)
	m.visible = false
	return m


## A unit-long bone box stretched and turned to run from a to b.
func _lay_bone(m: MeshInstance4D, a: Vector4, b: Vector4) -> void:
	var d: Vector4 = b - a
	var len: float = d.length()
	if len < 0.01:
		return
	var y3 := Vector3(d.x, d.y, d.z).normalized()
	var ref := Vector3(0, 0, 1) if absf(y3.z) < 0.9 else Vector3(1, 0, 0)
	var x3: Vector3 = y3.cross(ref).normalized()
	var z3: Vector3 = x3.cross(y3)
	m.position = (a + b) * 0.5
	m.basis = Projection(Vector4(x3.x, x3.y, x3.z, 0.0), Vector4(y3.x, y3.y, y3.z, 0.0) * len, Vector4(z3.x, z3.y, z3.z, 0.0), Vector4(0, 0, 0, 1))


# -- what the room reads -----------------------------------------------------------------------------

## Every rig's mesh with its vertices in the model's space, merged: [vertices, cells].
func _merged() -> Array:
	var verts := PackedVector4Array()
	var cells := PackedInt32Array()
	for r in _rigs:
		var rig: MeshInstance4D = r
		var m: Mesh4D = rig.mesh if rig.mesh != null else _meshes.get(rig.get_instance_id())
		if not (m is ArrayTetraMesh4D):
			continue
		var base: int = verts.size()
		for v in (m as ArrayTetraMesh4D).get_vertex_positions():
			verts.append(v + rig.position)
		for c in (m as ArrayTetraMesh4D).get_simplex_cell_vertex_indices():
			cells.append(c + base)
	return [verts, cells]


## How far through W it reaches either side of its centre, in metres, once grown.
func w_extent() -> float:
	if _model == null:
		return 1.0
	var reach: float = 0.0
	for p in wire():
		reach = maxf(reach, absf(p.w))
	return maxf(0.2, reach * (_model.basis * Vector4(0, 0, 0, 1)).length())


var _data: Dictionary = {}


func data() -> Dictionary:
	if not _data.is_empty() or _model == null or _rigs.is_empty():
		return _data
	var bars: Array = []
	var total: int = 0
	var verts: int = 0
	for r in _rigs:
		var m: Mesh4D = (r as MeshInstance4D).mesh
		if m is ArrayTetraMesh4D:
			total += int((m as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4)
			verts += (m as ArrayTetraMesh4D).get_vertex_positions().size()
		bars.append(total)
	var balls: int = _all_balls().size()
	_data = {
		"name": "Chicken",
		"code": "CK-02",
		"title": "THE CHICKEN, MEASURED",
		"rows": [["Balls placed by hand", str(balls)], ["Tetrahedra", str(total)], ["Rigs, built in turn", str(_rigs.size())], ["Reach through W", "%.2f m" % w_extent()]],
		"bars": bars,
		"bar_label": "Tetrahedra as each rig comes in",
		"stats": {"balls": balls, "tetra": total, "stages": _rigs.size(), "reach": w_extent(), "verts": verts,
			"mb": (float(verts) * 32.0 + float(total) * 16.0) / 1048576.0},
	}
	return _data


func live() -> Array:
	return [["Showing", ("rig %d of %d" % [_shown_step + 1, _rigs.size()]) if _shown_step >= 0 else "the finished bird"], ["Balls in view", str(balls_in_view())]]


func balls_in_view() -> int:
	if _shown_step < 0:
		return _all_balls().size()
	var n: int = 0
	for i in mini(_shown_step + 1, _rigs.size()):
		n += _balls_of(_rigs[i]).size()
	return n


func stage_in_view() -> int:
	return _shown_step


var _profile: Dictionary = {}


func w_profile(count: int = 48) -> Dictionary:
	if not _profile.is_empty() or _model == null:
		return _profile
	var mm: Array = _merged()
	var verts: PackedVector4Array = mm[0]
	var cells: PackedInt32Array = mm[1]
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
	if not _shape.is_empty() or _model == null:
		return _shape
	var mm: Array = _merged()
	var verts: PackedVector4Array = mm[0]
	var cells: PackedInt32Array = mm[1]
	var pts := PackedVector2Array()
	for v in verts:
		pts.append(Vector2(v.z, v.y))
	for t in range(0, cells.size() - 3, 4):
		var c: Vector4 = (verts[cells[t]] + verts[cells[t + 1]] + verts[cells[t + 2]] + verts[cells[t + 3]]) * 0.25
		pts.append(Vector2(c.z, c.y))
	var out_balls: Array = []
	for b in _all_balls():
		var p: Vector4 = _in_model(b)
		out_balls.append([Vector2(p.z, p.y), float(b.get("radius")), String(b.name)])
	_shape = {"points": pts, "balls": out_balls, "bones": []}
	return _shape


func cloud() -> PackedVector4Array:
	return wire()


var _wire: PackedVector4Array = PackedVector4Array()


## Its mesh as a light wireframe (pairs of points), one edge kept per cell of a coarse grid.
func wire() -> PackedVector4Array:
	if not _wire.is_empty() or _model == null:
		return _wire
	var mm: Array = _merged()
	var verts: PackedVector4Array = mm[0]
	var cells: PackedInt32Array = mm[1]
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


## The slice in the model's space ([n, d]: a point p is at world W = n.dot(p) + d).
func slice_in_rig() -> Array:
	if _model == null or not _model.is_inside_tree():
		return []
	var gb: Projection = _model.global_basis
	return [Vector4(gb.x.w, gb.y.w, gb.z.w, gb.w.w), _model.global_position.w]
