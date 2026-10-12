@tool
extends Node4D

## A town wall for layout B (PenLayout/PLAN_B.md steps 19-22; Ramon, 6 Oct: "city walls should become
## twice the height. and also the should be straight. they are wonkey now. and they shyould use the
## fence system ... the only way through from bottom to top is through the gate").
##
## THE FENCE TECH AS A WALL. A straight run from [member from] to [member to] (in this node's frame, on
## the ground), cut by [member gaps], each run one fence-tech face (FenceGenerator4D) whose beams cover
## it top to bottom: a solid wall [member height] tall, pillars standing out [member pillar_rise] above
## it every [member pillar_every] metres and at the ends. Twice the old ruin's height (its panels
## stood 1.6 to 2.15 m, its pillars 2.25 to 2.75).
##
## AS DEEP IN W AS THE WALKABLE WORLD. The field is a sphere in x, z and W (pen_bounds_4d.gd), so a wall
## only [member w_half] either side of the farm's slice could be stepped round in W. The default
## reaches past the sphere's edge everywhere: from any W, the gate is the way through.
##
## A GATE is a gap with two taller posts and a lintel over it (gaps, by their middle along the run and
## their width). Solid: one box a run, the posts, the lintel.

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var from: Vector2 = Vector2(-10.0, 0.0): set = _set_from
@export var to: Vector2 = Vector2(10.0, 0.0): set = _set_to
## [middle along the run, metres from `from`; width] for each opening; a gate if `gate_posts`.
@export var gaps: Array[Vector2] = []: set = _set_gaps
@export var gate_posts: bool = true: set = _set_gate_posts
## 4.0 since 7 Oct (Ramon: "make the town exntance a little wider. and the height a tiny less high"); 4.4
## before, twice the ruined wall's.
@export_range(1.0, 10.0, 0.1, "suffix:m") var height: float = 4.0: set = _set_height
@export_range(0.0, 3.0, 0.05, "suffix:m") var pillar_rise: float = 0.6: set = _set_rise
@export_range(2.0, 20.0, 0.5, "suffix:m") var pillar_every: float = 6.0: set = _set_every
@export_range(0.2, 2.0, 0.05, "suffix:m") var thickness: float = 0.6: set = _set_thickness
@export_range(1.0, 80.0, 0.5, "suffix:m") var w_half: float = 60.0: set = _set_w_half
@export var stone: Color = Color(0.60, 0.62, 0.64): set = _set_stone
@export var pillar_stone: Color = Color(0.50, 0.52, 0.55): set = _set_stone

const OWN := &"_town_wall_part"

var _pending: bool = false


func _set_from(v: Vector2) -> void: from = v; _later()
func _set_to(v: Vector2) -> void: to = v; _later()
func _set_gaps(v: Array[Vector2]) -> void: gaps = v; _later()
func _set_gate_posts(v: bool) -> void: gate_posts = v; _later()
func _set_height(v: float) -> void: height = v; _later()
func _set_rise(v: float) -> void: pillar_rise = v; _later()
func _set_every(v: float) -> void: pillar_every = v; _later()
func _set_thickness(v: float) -> void: thickness = v; _later()
func _set_w_half(v: float) -> void: w_half = v; _later()
func _set_stone(_v: Color) -> void: _later()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


## The runs between the gaps: [[start, end], ...] in metres along the wall.
func runs() -> Array:
	var length: float = from.distance_to(to)
	var cuts: Array = []
	for g in gaps:
		cuts.append([clampf(g.x - g.y * 0.5, 0.0, length), clampf(g.x + g.y * 0.5, 0.0, length)])
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	var at: float = 0.0
	for c in cuts:
		if float(c[0]) > at + 0.05:
			out.append([at, float(c[0])])
		at = maxf(at, float(c[1]))
	if length > at + 0.05:
		out.append([at, length])
	return out


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	var length: float = from.distance_to(to)
	if length < 0.1:
		return
	var dir: Vector2 = (to - from) / length
	var wall_mat := TetraMaterial4D.new()
	wall_mat.albedo_color = stone
	var pillar_mat := TetraMaterial4D.new()
	pillar_mat.albedo_color = pillar_stone
	var body := StaticBody4D.new()
	body.name = "Solid"
	_own(body)
	var at2 := func(d: float) -> Vector2:
		return from + dir * d
	for r in runs():
		var a: float = r[0]
		var b: float = r[1]
		# The seed: one face per stretch between pillars, from kata to ana across the whole W depth.
		var seed := ArrayPolyMesh4D.new()
		var cuts: int = maxi(1, ceili((b - a) / pillar_every))
		var lo: Array = []
		var hi: Array = []
		for k in cuts + 1:
			var p: Vector2 = at2.call(lerpf(a, b, float(k) / float(cuts)))
			lo.append(seed.append_vertex(Vector4(p.x, 0.0, p.y, -w_half)))
			hi.append(seed.append_vertex(Vector4(p.x, 0.0, p.y, w_half)))
		for k in cuts:
			var e0: int = seed.append_edge_indices(lo[k], lo[k + 1])
			var e1: int = seed.append_edge_indices(lo[k + 1], hi[k + 1])
			var e2: int = seed.append_edge_indices(hi[k + 1], hi[k])
			var e3: int = seed.append_edge_indices(hi[k], lo[k])
			seed.append_poly_cell(2, PackedInt32Array([e0, e1, e2, e3]))
		var f := FenceGenerator4D.new()
		f.name = "Run%d" % int(a)
		f.update_automatically = false
		f.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
		f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
		f.seed_mesh_4d = seed
		var post_h: float = height + pillar_rise
		f.post_height_meters = post_h
		f.post_thickness_meters = thickness * 1.6
		f.rib_height_ratio = 0.999
		f.rib_thickness_ratio = 0.95
		# One beam a face, covering it from the ground to the wall's top: a solid wall.
		f.beam_count = 1
		f.beam_max_height_ratio = height / post_h
		f.beam_coverage = 1.0
		f.beam_thickness_ratio = thickness / (thickness * 1.6 * 0.95)
		f.desired_spacing_meters = 0.0
		f.post_material = pillar_mat
		f.rib_material = pillar_mat
		f.beam_material = wall_mat
		_own(f)
		f.update_fence_mesh_now()
		var m: Vector2 = at2.call((a + b) * 0.5)
		var shape := BoxShape4D.new()
		shape.size = _aligned(dir, b - a, height, thickness)
		var holder := CollisionShape4D.new()
		holder.shape = shape
		holder.position = Vector4(m.x, height * 0.5, m.y, 0.0)
		body.add_child(holder)
	if gate_posts:
		for g in gaps:
			_gate(g, dir, at2, pillar_mat, body)


## Two posts a little taller than the pillars either side of the gap, and a lintel across over head
## height, all as deep in W as the wall.
func _gate(g: Vector2, dir: Vector2, at2: Callable, mat: TetraMaterial4D, body: StaticBody4D) -> void:
	var post_w: float = thickness * 1.9
	var post_h: float = height + pillar_rise + 0.6
	var mesh := ArrayTetraMesh4D.new()
	for s in [-1.0, 1.0]:
		var p: Vector2 = at2.call(g.x + s * (g.y * 0.5 + post_w * 0.5))
		var box := BoxTetraMesh4D.new()
		box.size = Vector4(post_w, post_h, post_w, w_half * 2.0)
		mesh.merge_with(box.to_array_tetra_mesh(), Vector4(p.x, post_h * 0.5, p.y, 0.0), Projection.IDENTITY)
		var shape := BoxShape4D.new()
		shape.size = Vector4(post_w, post_h, post_w, w_half * 2.0)
		var holder := CollisionShape4D.new()
		holder.shape = shape
		holder.position = Vector4(p.x, post_h * 0.5, p.y, 0.0)
		body.add_child(holder)
	var mid: Vector2 = at2.call(g.x)
	var lintel := BoxTetraMesh4D.new()
	var span: float = g.y + post_w * 2.0
	lintel.size = _aligned(dir, span, 0.55, thickness * 1.3, w_half * 2.0)
	mesh.merge_with(lintel.to_array_tetra_mesh(), Vector4(mid.x, post_h - 0.3, mid.y, 0.0), Projection.IDENTITY)
	var mi := MeshInstance4D.new()
	mi.name = "Gate%d" % int(g.x)
	mi.mesh = mesh
	mi.material_override = mat
	_own(mi)


## A box's size along a run that lies on x or z (the walls are straight and square to the field).
func _aligned(dir: Vector2, along: float, tall: float, across: float, deep: float = -1.0) -> Vector4:
	var d: float = w_half * 2.0 if deep < 0.0 else deep
	if absf(dir.x) >= absf(dir.y):
		return Vector4(along, tall, across, d)
	return Vector4(across, tall, along, d)


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)
