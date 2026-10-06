@tool
extends Node4D

## The old wall across the field's west side, in ruins (6 Oct 2026, Ramon: "make the stonewall grey
## ruins instead. use the fence system and at the part where the path collides continue the path
## through an arch, but a pillar fell down in front of it. this you can rotate away. create a self
## talk that you should do this"; and with a reference of modular stone panels between pillars:
## "subtle gray hues throughout. and a few custom blocks placed to indicate seperate stones. but the
## mass is the fence").
##
## THE MASS IS THE FENCE. The wall is a row of modules, each one FenceGenerator4D box as long as the
## module, as thick as a panel and as deep in W as the hills it runs between: its posts are the
## pillars, its one beam filling the face (beam_coverage 1) is the panel, its ribs a little lower
## than the posts so the pillars stand proud. Each module its own height, so the line is broken as
## a ruin's is. Boxes add only what the generator cannot: caps on the pillars, a coping on each panel,
## a plinth, a few single stones set into the faces, and the arch.
##
## THROUGH W. The grid's spacing puts a layer at the farm's slice (an even number of layers across
## the wall's W depth), so the pillars stand there whole; between layers you see the ribs along W,
## thinner, and the caps go, and at the next layer the pillars are back. The single stones are thin
## in W and scattered through it, so the masonry changes as you step.
##
## A BARRIER, NOT A LESSON IN STEPPING. The wall is as deep in W as the hills at its two ends (the
## funnel), so the way through is the arch where the path crosses. And in front of the arch lies a
## fallen pillar, too thick to jump (a jump clears about a metre) and thin in W: turn your slice
## (hold the right mouse button and drag) and walk on, and you walk through W as you go, round it.
## Stepping ana past it works too. The tutor names the control; the self-talk says the idea, once.
##
## Physics here is boxes that do not turn: a box per module, per pier and for the pillar. Keep the
## node unturned or turned in 90 degree steps.
##
## NO class_name (engine_gotchas.md).

## The wall's length along its own x, centred on the node.
@export_range(4.0, 80.0, 0.5, "suffix:m") var length: float = 30.0: set = _set_length
## How deep in W the wall is, all of it.
@export_range(1.0, 40.0, 0.5, "suffix:m") var w_depth: float = 18.0: set = _set_w_depth
## A module's length, roughly: the runs either side of the arch are cut into whole modules.
@export_range(2.0, 4.4, 0.05, "suffix:m") var module: float = 3.6: set = _set_module
## Panels and pillars: heights drawn between these for each module.
@export var panel_height: Vector2 = Vector2(1.6, 2.15): set = _set_panel_height
@export var pillar_height: Vector2 = Vector2(2.25, 2.75): set = _set_pillar_height
@export_range(0.15, 0.8, 0.01, "suffix:m") var panel_thickness: float = 0.3: set = _set_panel_thickness
@export_range(0.2, 1.0, 0.01, "suffix:m") var pillar_thickness: float = 0.5: set = _set_pillar_thickness
## The grid in W: 3 m makes six layers across 18 m, one of them on the farm's slice.
@export_range(1.0, 9.0, 0.1, "suffix:m") var w_spacing: float = 3.0: set = _set_w_spacing
@export var stone_seed: int = 11: set = _set_seed

@export_group("The arch")
## Where the arch stands along the wall (its middle, metres from the wall's middle along x): where
## the path crosses.
@export var arch_at: float = 3.8: set = _set_arch_at
@export_range(1.4, 4.0, 0.05, "suffix:m") var arch_width: float = 2.4: set = _set_arch_width
## Where the arch's curve starts, and how wide its piers are.
@export_range(1.0, 3.0, 0.05, "suffix:m") var arch_spring: float = 1.9: set = _set_arch_spring
@export_range(0.5, 1.6, 0.05, "suffix:m") var pier_width: float = 0.9: set = _set_pier_width
## The fallen pillar: how thick and how deep in W.
@export_range(1.1, 1.6, 0.01, "suffix:m") var pillar_fallen_d: float = 1.25: set = _set_fallen_d
@export_range(0.3, 1.5, 0.05, "suffix:m") var pillar_fallen_w: float = 0.7: set = _set_fallen_w
## Which side of the wall it lies on (+1: the +z side, the way the path comes from the start).
@export var fallen_side: float = 1.0: set = _set_fallen_side

@export_group("Look")
## Subtle greys: the panels, the pillars, the caps and coping, and the arch. A touch cool, because
## the evening sun warms everything it lands on and neutral greys came out beige (as the cave's
## rock face did, 28 Sept).
@export var panel_colour: Color = Color(0.64, 0.66, 0.68): set = _set_panel_colour
@export var pillar_colour: Color = Color(0.50, 0.52, 0.55): set = _set_pillar_colour
@export var cap_colour: Color = Color(0.58, 0.60, 0.62): set = _set_cap_colour
@export var arch_colour: Color = Color(0.60, 0.62, 0.64): set = _set_arch_colour
## The single stones set into the faces, a shade either side of the panels.
@export var stone_colours: Array[Color] = [Color(0.72, 0.74, 0.75), Color(0.55, 0.57, 0.60), Color(0.60, 0.62, 0.64), Color(0.69, 0.70, 0.72)]: set = _set_stones
@export_range(0, 16) var stones_per_module: int = 7: set = _set_stones_per

@export_group("Telling you")
@export var tutor_text: String = "The fallen pillar is thin in W. Hold the right mouse button and drag to turn your slice, then walk on."
@export var thought: String = "Blocked. But that pillar looks thin in W. If I turn my slice a little, I could walk round it."
@export var player_path: NodePath = NodePath("../../Player")
@export var box_path: NodePath = NodePath("../../UI/ThoughtBox")
## How near the pillar (on the ground, and in W) before the thought comes.
@export_range(1.0, 8.0, 0.1, "suffix:m") var thought_radius: float = 3.4
@export_range(2.0, 12.0, 0.5, "suffix:s") var thought_hold: float = 4.5

const OWN := &"_ruin_wall_part"
const SAID := &"ruin_wall_thought_said"

var _pending: bool = false
var _box: Node
var _player: Node4D
var _showing: bool = false
var _hold: float = -1.0


func _set_length(v: float) -> void: length = v; _later()
func _set_w_depth(v: float) -> void: w_depth = v; _later()
func _set_module(v: float) -> void: module = v; _later()
func _set_panel_height(v: Vector2) -> void: panel_height = v; _later()
func _set_pillar_height(v: Vector2) -> void: pillar_height = v; _later()
func _set_panel_thickness(v: float) -> void: panel_thickness = v; _later()
func _set_pillar_thickness(v: float) -> void: pillar_thickness = v; _later()
func _set_w_spacing(v: float) -> void: w_spacing = v; _later()
func _set_seed(v: int) -> void: stone_seed = v; _later()
func _set_arch_at(v: float) -> void: arch_at = v; _later()
func _set_arch_width(v: float) -> void: arch_width = v; _later()
func _set_arch_spring(v: float) -> void: arch_spring = v; _later()
func _set_pier_width(v: float) -> void: pier_width = v; _later()
func _set_fallen_d(v: float) -> void: pillar_fallen_d = v; _later()
func _set_fallen_w(v: float) -> void: pillar_fallen_w = v; _later()
func _set_fallen_side(v: float) -> void: fallen_side = v; _later()
func _set_panel_colour(v: Color) -> void: panel_colour = v; _later()
func _set_pillar_colour(v: Color) -> void: pillar_colour = v; _later()
func _set_cap_colour(v: Color) -> void: cap_colour = v; _later()
func _set_arch_colour(v: Color) -> void: arch_colour = v; _later()
func _set_stones(v: Array[Color]) -> void: stone_colours = v; _later()
func _set_stones_per(v: int) -> void: stones_per_module = v; _later()


func _ready() -> void:
	rebuild()
	if not Engine.is_editor_hint():
		_box = get_node_or_null(box_path)
		_player = get_node_or_null(player_path) as Node4D


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


## Where the arch's opening and its piers are along x: [opening's left, right, piers' outer left, right].
func arch_span() -> Array:
	var half: float = arch_width * 0.5
	return [arch_at - half, arch_at + half, arch_at - half - pier_width, arch_at + half + pier_width]


## The fallen pillar's middle, in this node's frame.
func fallen_at() -> Vector4:
	var r: float = pillar_fallen_d * 0.5
	return Vector4(arch_at, r, signf(fallen_side) * (0.45 + r + 0.08), 0.0)


## Everything this script made, taken down and put up again. Children it did not make stay.
func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var batches: Dictionary = {}
	var body := StaticBody4D.new()
	body.name = "Solid"
	_own(body)
	var span: Array = arch_span()
	var runs: Array = [[-length * 0.5, float(span[2])], [float(span[3]), length * 0.5]]
	var joints: Dictionary = {}
	var m_index: int = 0
	for run in runs:
		var a: float = run[0]
		var b: float = run[1]
		if b - a < 0.5:
			continue
		var n: int = maxi(1, int(round((b - a) / module)))
		var ml: float = (b - a) / float(n)
		for k in n:
			var x0: float = a + ml * float(k)
			var x1: float = x0 + ml
			var ph: float = rng.randf_range(panel_height.x, panel_height.y)
			var pl: float = maxf(rng.randf_range(pillar_height.x, pillar_height.y), ph + 0.3)
			_module(m_index, (x0 + x1) * 0.5, ml, ph, pl, body, batches, rng)
			m_index += 1
			for xj in [x0, x1]:
				var key: String = "%.3f" % xj
				joints[key] = maxf(float(joints.get(key, 0.0)), pl)
	# Caps on every pillar, at each grid layer in W where the generator stands a post.
	for key in joints:
		var xj: float = float(key)
		for wl in _w_layers():
			_add(batches, cap_colour, Vector4(pillar_thickness + 0.14, 0.16, pillar_thickness + 0.14, pillar_thickness + 0.14),
				Vector4(xj, float(joints[key]) + 0.08, 0.0, wl))
	_arch(body, batches, rng)
	_fallen(body, batches)
	for colour in batches:
		var node := MeshInstance4D.new()
		node.name = "Stone_" + String(colour)
		node.mesh = batches[colour]
		var mat := TetraMaterial4D.new()
		mat.albedo_color = Color.html(colour)
		node.material_override = mat
		_own(node)
	var spot := Node4D.new()
	spot.name = "TutorSpot"
	spot.position = Vector4(arch_at, 1.0, signf(fallen_side) * 2.2, 0.0)
	spot.add_to_group(&"tutor_spot")
	spot.set_meta(&"tutor_key", "ruin_arch")
	spot.set_meta(&"tutor_text", tutor_text)
	spot.set_meta(&"tutor_radius", 4.5)
	spot.set_meta(&"tutor_w", pillar_fallen_w * 0.5 + 0.4)
	spot.set_meta(&"tutor_when", "in")
	_own(spot)


## The W of each grid layer, as the generator lays them: evenly across the depth, ends included.
func _w_layers() -> Array:
	var n: int = maxi(1, int(round(w_depth / w_spacing)))
	var out: Array = []
	for i in n + 1:
		out.append(-w_depth * 0.5 + w_depth * float(i) / float(n))
	return out


## One module: the fence (pillars, panel), its coping and plinth, its collider and a few stones.
func _module(i: int, cx: float, ml: float, ph: float, pl: float, body: StaticBody4D, batches: Dictionary, rng: RandomNumberGenerator) -> void:
	var f := FenceGenerator4D.new()
	f.name = "Module%d" % i
	f.update_automatically = false
	f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_BOX
	f.box_size = Vector3(ml, panel_thickness, w_depth)
	f.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	f.desired_spacing_meters = w_spacing
	f.post_height_meters = pl
	f.post_thickness_meters = pillar_thickness
	f.rib_height_ratio = clampf(ph / pl, 0.3, 0.97)
	f.rib_thickness_ratio = 0.6
	f.beam_count = 1
	f.beam_coverage = 1.0
	f.beam_max_height_ratio = 1.0
	f.beam_thickness_ratio = 1.0
	f.top_footprint_ratio = 1.0
	var posts := TetraMaterial4D.new()
	posts.albedo_color = pillar_colour
	var panel := TetraMaterial4D.new()
	panel.albedo_color = panel_colour
	f.post_material = posts
	f.rib_material = panel
	f.beam_material = panel
	f.position = Vector4(cx, 0.0, 0.0, 0.0)
	f.set_meta(OWN, true)
	add_child(f)
	f.update_fence_mesh_now()
	# The coping along the panel's top, and the plinth along its foot, the wall's whole W depth.
	_add(batches, cap_colour, Vector4(ml - pillar_thickness - 0.02, 0.12, panel_thickness + 0.14, w_depth), Vector4(cx, ph + 0.06, 0.0, 0.0))
	_add(batches, cap_colour, Vector4(ml, 0.22, panel_thickness + 0.18, w_depth), Vector4(cx, 0.11, 0.0, 0.0))
	_solid(body, Vector4(ml, ph, panel_thickness + 0.2, w_depth), Vector4(cx, ph * 0.5, 0.0, 0.0))
	# A few single stones set into the faces, a shade off the panel and thin in W, half of them
	# near the farm's slice and the rest wherever, so the masonry changes as you step through W.
	if stone_colours.is_empty():
		return
	for s in stones_per_module:
		var sw: float = rng.randf_range(0.45, 0.9)
		var sh: float = rng.randf_range(0.26, 0.42)
		var sx: float = cx + rng.randf_range(-ml * 0.5 + pillar_thickness * 0.5 + sw * 0.5 + 0.05, ml * 0.5 - pillar_thickness * 0.5 - sw * 0.5 - 0.05)
		var sy: float = rng.randf_range(0.35 + sh * 0.5, ph - 0.15 - sh * 0.5)
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var wd: float = rng.randf_range(0.6, 1.6)
		var sww: float = rng.randf_range(-0.3, 0.3) if s % 2 == 0 else rng.randf_range(-w_depth * 0.5 + wd * 0.5, w_depth * 0.5 - wd * 0.5)
		var c: Color = stone_colours[rng.randi() % stone_colours.size()]
		_add(batches, c, Vector4(sw, sh, 0.07, wd), Vector4(sx, sy, side * (panel_thickness * 0.5 + 0.03), sww))


## The arch where the path crosses: two piers, a ring of nine stones round a half circle, the
## spandrels and a lintel course over it, the wall's whole W depth.
func _arch(body: StaticBody4D, batches: Dictionary, rng: RandomNumberGenerator) -> void:
	var span: Array = arch_span()
	var r: float = arch_width * 0.5
	var ring: float = 0.42
	var depth: float = panel_thickness + 0.6
	var top: float = arch_spring + r + ring + 0.35
	for side in [-1.0, 1.0]:
		var px: float = arch_at + side * (r + pier_width * 0.5)
		_add(batches, pillar_colour, Vector4(pier_width, top, depth, w_depth), Vector4(px, top * 0.5, 0.0, 0.0))
		_add(batches, cap_colour, Vector4(pier_width + 0.16, 0.16, depth + 0.16, w_depth), Vector4(px, arch_spring - 0.08, 0.0, 0.0))
		_solid(body, Vector4(pier_width, top, depth, w_depth), Vector4(px, top * 0.5, 0.0, 0.0))
		# The spandrel: the corner between the ring and the lintel, over the pier's inner half.
		var sx0: float = arch_at + side * r * 0.55
		var sx1: float = arch_at + side * r
		_add(batches, arch_colour, Vector4(absf(sx1 - sx0) + 0.02, top - (arch_spring + r * 0.75), depth - 0.06, w_depth),
			Vector4((sx0 + sx1) * 0.5, (top + arch_spring + r * 0.75) * 0.5, 0.0, 0.0))
	var stones: int = 9
	var mid_r: float = r + ring * 0.5
	var seg: float = 2.0 * (r + ring) * sin(PI / (2.0 * float(stones))) * 1.12
	for k in stones:
		var a: float = PI * (float(k) + 0.5) / float(stones)
		var at := Vector4(arch_at + cos(a) * mid_r, arch_spring + sin(a) * mid_r, 0.0, 0.0)
		var key: bool = k == (stones - 1) / 2
		var c: Color = cap_colour if key else arch_colour
		_add(batches, c, Vector4(seg, ring + (0.08 if key else 0.0), depth + (0.06 if key else 0.0), w_depth), at, _turn_xy(a + PI * 0.5))
	# The lintel course over it all, as long as the arch and its piers.
	_add(batches, cap_colour, Vector4(float(span[3]) - float(span[2]) + 0.1, 0.2, depth + 0.1, w_depth), Vector4(arch_at, top + 0.1, 0.0, 0.0))
	# A stone or two out of the ring on the ground, the ruin's own.
	for k in 2:
		var bx: float = arch_at + (rng.randf_range(0.6, 1.4) * (-1.0 if k == 0 else 1.0)) * r
		_add(batches, arch_colour, Vector4(0.42, 0.3, 0.36, 0.5), Vector4(bx, 0.15, -signf(fallen_side) * rng.randf_range(0.7, 1.2), rng.randf_range(-0.4, 0.4)), _turn_xy(rng.randf_range(-0.3, 0.3)))


## The fallen pillar: a round shaft lying across the arch's mouth, made of six slabs turned about its
## length (a twelve-sided prism), with its capital broken off beside it. Thin in W.
func _fallen(body: StaticBody4D, batches: Dictionary) -> void:
	var at: Vector4 = fallen_at()
	var r: float = pillar_fallen_d * 0.5
	var long: float = arch_width + 0.25
	var face: float = 2.0 * r * tan(PI / 12.0) * 1.04
	for k in 6:
		var t: float = PI * float(k) / 6.0
		_add(batches, cap_colour, Vector4(long, pillar_fallen_d, face, pillar_fallen_w), at, _turn_yz(t))
	# The drum's ends a shade darker, as cut faces are.
	for side in [-1.0, 1.0]:
		for k in 6:
			var t2: float = PI * float(k) / 6.0
			_add(batches, pillar_colour, Vector4(0.06, pillar_fallen_d * 0.96, face * 0.96, pillar_fallen_w * 0.96),
				at + Vector4(side * long * 0.5, 0.0, 0.0, 0.0), _turn_yz(t2))
	_add(batches, pillar_colour, Vector4(0.9, 0.34, 0.9, pillar_fallen_w + 0.1),
		at + Vector4(long * 0.5 + 0.75, -r + 0.17, 0.25 * signf(fallen_side), 0.0), _turn_xy(0.25))
	# A body of its own, marked so the paths lie on the ground under it rather than climbing it
	# (path_network_4d.gd ground_at): it is in the way, which is the point.
	var own := StaticBody4D.new()
	own.name = "FallenPillar"
	own.set_meta(&"drape_through", true)
	_own(own)
	_solid(own, Vector4(long, pillar_fallen_d, pillar_fallen_d, pillar_fallen_w), at)


## A rotation in the x-y plane by [param t]: x toward y.
static func _turn_xy(t: float) -> Projection:
	return Projection(Vector4(cos(t), sin(t), 0.0, 0.0), Vector4(-sin(t), cos(t), 0.0, 0.0), Vector4(0.0, 0.0, 1.0, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


## A rotation in the y-z plane by [param t]: about the x axis.
static func _turn_yz(t: float) -> Projection:
	return Projection(Vector4(1.0, 0.0, 0.0, 0.0), Vector4(0.0, cos(t), sin(t), 0.0), Vector4(0.0, -sin(t), cos(t), 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


func _add(batches: Dictionary, colour: Color, size: Vector4, at: Vector4, basis: Projection = Projection.IDENTITY) -> void:
	var key: String = colour.to_html(false)
	if not batches.has(key):
		batches[key] = ArrayTetraMesh4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = size
	(batches[key] as ArrayTetraMesh4D).merge_with(box.to_array_tetra_mesh(), at, basis)


func _solid(body: StaticBody4D, size: Vector4, at: Vector4) -> void:
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	holder.shape = shape
	holder.position = at
	body.add_child(holder)


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)


# --- The self-talk ---------------------------------------------------------------------------

## The first time you stand at the fallen pillar on its slice, you think out loud what to do, once
## a session (remembered on the scene's root, as the cave's first look is), never over somebody.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _box == null or _player == null:
		return
	if _showing:
		if _hold < 0.0 and not bool(_box.call("is_typing")):
			_hold = thought_hold
		elif _hold >= 0.0:
			_hold -= delta
			if _hold <= 0.0:
				_showing = false
				_hold = -1.0
				_box.call("close")
		return
	var root: Node = owner if owner != null else get_tree().current_scene
	if root == null or root.has_meta(SAID):
		return
	var local: Vector4 = global_basis.inverse() * (_player.global_position - global_position)
	var at: Vector4 = fallen_at()
	if Vector2(local.x - at.x, local.z - at.z).length() > thought_radius or absf(local.w - at.w) > pillar_fallen_w * 0.5 + 0.3:
		return
	# Somebody is already talking (the box holds a line until it is closed).
	if String(_box.get("_full")) != "":
		return
	root.set_meta(SAID, true)
	_showing = true
	_box.call("say", String(_box.get("player_name")), thought)


func _exit_tree() -> void:
	if _showing and _box != null and is_instance_valid(_box):
		_box.call("close")
	_showing = false
