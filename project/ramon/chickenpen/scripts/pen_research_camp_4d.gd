@tool
extends Node4D

## THE RESEARCHERS' CAMP, built to Ramon's sheet by measurement (PenLayout/refs/camp_views.png;
## PenLayout/PLAN_REF_LOCK.md part E; Ramon, 6 Oct: "here's a concept for the campsite. use the fence
## tech where you can. when you rotate it so that its 50% visible you can make a button appear that
## says, align to slice").
##
## EVERY NUMBER HERE IS MEASURED. The sheet's top view is a painted map, not a camera view (fitted as
## one, it put the tents 20 m away), so PenLayout/tools/ref_fit_plan.py fits the front view as a
## camera and the top view as a map of the ground with a lean for height, and solves every landmark
## from both: front 1.5 px, top 2.0 px (PenLayout/RefLock/specs/camp_fit.json). The player is painted
## in a different place in each view, so he gives only the scale. The origin is the fire ring's
## middle on the ground; +z is the front view's side.
##
## THE PARTS: two ridge tents of cream canvas with maroon trim, their poles and ridge poles from the
## fence tech (two posts and one beam at their tops), guy ropes to stakes; the left tent's door in the
## side that faces the fire, its flap rolled up over it and a bedroll inside; the right tent's diamond
## on that side and its door at the west gable. The cook frame behind the fire (fence tech: two posts
## and a crossbar) with the cauldron on a chain; the stone fire ring, its logs and flames; two benches
## facing the fire; the lantern on its post; crates and a barrel by the right tent, the log pile, the
## chopping block with the axe in it; field stones round the edge; grass.
##
## ALIGN TO SLICE (Ramon's button). The camp stands off the farm's slice (2.5 kata in the pen). When
## your slice is turned so that it passes through the camp (roughly half of it showing), "V  Align to
## slice" comes up over it; V brings your slice square to the camp's W (the orbit rig's align_to, the
## same move the marsh's V makes), so the whole camp is there.
##
## The fire's flames flicker and light the camp (as the camp before this one did). Built when it
## loads (and in the editor). NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const StoneSet := preload("res://ramon/chickenpen/scripts/pen_stone_set_4d.gd")
const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
@export var camp_seed: int = 31: set = _set_seed
## The sheet's ground: the grass disc (with [member turf_mat]) and the sand round the fire, raised
## [member ground_lift] in the pen so they do not fight the pen's own ground.
@export var ground_patch: bool = true: set = _set_patch
@export var turf_mat: bool = true: set = _set_turf
@export_range(0.0, 0.2, 0.005, "suffix:m") var ground_lift: float = 0.0: set = _set_lift
## How deep in W the props are.
@export_range(0.4, 4.0, 0.05, "suffix:m") var prop_w: float = 1.4: set = _set_prop_w

@export_group("Look")
@export var canvas: Color = Color(0.67, 0.55, 0.41)
@export var canvas_dark: Color = Color(0.30, 0.20, 0.14)
@export var trim: Color = Color(0.45, 0.14, 0.13)
@export var timber: Color = Color(0.50, 0.33, 0.19)
@export var timber_dark: Color = Color(0.36, 0.23, 0.13)
@export var rope: Color = Color(0.70, 0.56, 0.36)
@export var iron: Color = Color(0.17, 0.17, 0.18)
@export var sand: Color = Color(0.62, 0.45, 0.24)
@export var turf: Color = Color(0.36, 0.41, 0.07)
@export var flame: Color = Color(1.0, 0.55, 0.12)
@export var flame_core: Color = Color(1.0, 0.86, 0.35)

@export_group("The fire's light")
@export var fire_colour: Color = Color(1.0, 0.58, 0.28)
@export_range(1.0, 15.0, 0.5, "suffix:m") var fire_reach: float = 7.0
@export_range(0.0, 6.0, 0.05) var fire_energy: float = 1.6

@export_group("Align to slice")
@export var player_path: NodePath = NodePath("../../Player")
@export var align_key: Key = KEY_V
## How near (x, z) the prompt is offered, and how much of the camp's W depth the slice must cut for
## it to count as showing.
@export_range(4.0, 40.0, 0.5, "suffix:m") var align_reach: float = 24.0
@export_range(0.1, 3.0, 0.05, "suffix:m") var visible_half_w: float = 1.0

## Measured (metres from the fire ring's middle on the ground).
const FIRE_R := 0.9
const COOK := [Vector2(-0.86, -3.73), Vector2(0.92, -3.48)]
const COOK_H := 1.76
const TENT_L := [Vector2(-4.15, -3.03), Vector2(-1.97, -4.58)]
const TENT_R := [Vector2(4.31, -3.09), Vector2(2.12, -4.68)]
const POLE_H := 3.55
const RIDGE_H := 3.3
const TENT_HALF := 1.45
## How far each roof panel's foot runs past the poles (the sheet's tents flare at the ground).
const TENT_FLARE := 0.8
const LANTERN := Vector2(-5.03, -1.13)
const LANTERN_H := 2.53
const BENCHES := [Vector2(-2.2, 2.6), Vector2(1.85, 2.7)]
const CRATES := [[Vector2(4.05, -2.45), 0.75], [Vector2(4.3, -1.5), 0.62]]
const BARREL := Vector2(5.39, -1.57)
const LOGS := Vector2(3.77, -0.16)
const STUMP := Vector2(5.0, 1.31)
const ROCKS := [[-5.29, -4.11, 0.75], [-5.24, -1.72, 0.7], [-4.87, 0.93, 0.8], [-3.66, 4.37, 0.7], [-0.87, 5.3, 0.45], [3.54, 2.28, 0.6],
	[4.59, 2.98, 0.9], [5.52, -5.2, 0.7], [-1.1, -6.3, 0.65], [1.2, 4.7, 0.4]]
## The ground: an ellipse, as the front view has it (the hero view: its ground runs to 8.3 m in front of
## the fire, where the top view's map draws it round; PenLayout/refs/progress, the camp's front view).
const DISC_C := Vector2(0.05, 0.55)
const DISC_R := 6.4
const DISC_RZ := 7.75
const SAND_C := Vector2(0.0, 1.4)
const SAND_R := 4.5
const SAND_RZ := 5.6

const OWN := &"_research_camp_part"

var _pending: bool = false
var _batches: Dictionary = {}
var _glows: Dictionary = {}
var _body: StaticBody4D
var _stones: Array = []
var _tufts: Array = []
var _rng := RandomNumberGenerator.new()
var _wood: TetraMaterial4D
var _flames: Array[MeshInstance4D] = []
var _light: OmniLight4D
var _t: float = 0.0
var _player: Node4D
var _tag: WorldTag4D
var _tag_anchor: Node4D
var _shown: String = ""


func _set_seed(v: int) -> void: camp_seed = v; _later()
func _set_patch(v: bool) -> void: ground_patch = v; _later()
func _set_turf(v: bool) -> void: turf_mat = v; _later()
func _set_lift(v: float) -> void: ground_lift = v; _later()
func _set_prop_w(v: float) -> void: prop_w = v; _later()


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		return
	_player = get_node_or_null(player_path) as Node4D
	_tag_anchor = Node4D.new()
	_tag_anchor.name = "AlignAnchor"
	add_child(_tag_anchor)
	_tag = WorldTag4D.new()
	_tag.name = "AlignPrompt"
	_tag.anchor_path = NodePath("..")
	var cam: Node = _player.get_node_or_null("CameraRig/Pitch/Camera4D") if _player != null else null
	if cam != null:
		_tag.camera_path = cam.get_path()
	_tag.lift = 8.0
	_tag_anchor.add_child(_tag)


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	_batches.clear()
	_glows.clear()
	_stones = []
	_tufts = []
	_flames = []
	_rng.seed = camp_seed
	_wood = TetraMaterial4D.new()
	_wood.albedo_color = timber
	_body = StaticBody4D.new()
	_body.name = "Solid"
	_own(_body)
	if ground_patch:
		_ground()
	_tent(TENT_L, true)
	_tent(TENT_R, false)
	_cook_frame()
	_fire()
	for b in BENCHES:
		_bench(b)
	_lantern()
	for c in CRATES:
		_crate(c[0], float(c[1]))
	_barrel()
	_log_pile()
	_stump()
	for r in ROCKS:
		var s: float = float(r[2])
		_stone(["round", "chip", "block"][_rng.randi() % 3], Vector4(float(r[0]), -0.15 * s, float(r[1]), _rng.randf_range(-0.6, 0.6)), Vector3(s * 1.1, s * 0.75, s), s * 1.6, _rng.randf_range(0.0, TAU))
	_grass()
	_flush()


# --- The ground ---------------------------------------------------------------------------------

func _ground() -> void:
	var lift := Vector4(0, ground_lift, 0, 0)
	if turf_mat:
		_ellipse_y(turf, Vector4(DISC_C.x, -0.05, DISC_C.y, 0), DISC_R, DISC_RZ, 0.1, 4.0, 16)
	_ellipse_y(sand, Vector4(SAND_C.x, -0.035, SAND_C.y, 0) + lift, SAND_R - 0.5, SAND_RZ - 0.5, 0.1, 3.0, 12)
	# Its edge broken by smaller patches.
	for k in 26:
		var a: float = TAU * float(k) / 26.0 + _rng.randf_range(-0.1, 0.1)
		var f: float = 1.0 - _rng.randf_range(0.04, 0.16)
		_box(sand, Vector4(_rng.randf_range(0.6, 1.2), 0.1, _rng.randf_range(0.5, 1.0), 3.0), Vector4(SAND_C.x + cos(a) * SAND_R * f, -0.03, SAND_C.y + sin(a) * SAND_RZ * f, 0) + lift, _turn_y(-a))


# --- The tents ----------------------------------------------------------------------------------

## A ridge tent between two poles ([param poles]: the front pole, then the back one): the poles and the
## ridge pole from the fence tech, two canvas roof panels down to the ground either side, a closed
## triangle at each gable, maroon trim along every edge, guy ropes. [param door_side]: the left tent
## (its door in the side facing the fire, the flap rolled over it, a bedroll inside); otherwise the
## right tent (the diamond on that side, the door at its back gable).
func _tent(poles: Array, door_side: bool) -> void:
	var a2: Vector2 = poles[0]
	var b2: Vector2 = poles[1]
	var a := Vector4(a2.x, 0, a2.y, 0)
	var b := Vector4(b2.x, 0, b2.y, 0)
	var along: Vector4 = (b - a).normalized()
	var side := Vector4(-along.z, 0, along.x, 0)
	# The side toward the fire (the origin) is +side.
	var mid: Vector4 = (a + b) * 0.5
	if side.dot(-mid) < 0.0:
		side = -side
	var length: float = (b - a).length() + 0.3
	var up := Vector4(0, 1, 0, 0)
	# The poles and the ridge pole: fence tech.
	_fence_pair(a2, b2, POLE_H, 0.17, 1, 0.12, "Tent")
	for p in [a, b]:
		_box(rope, Vector4(0.2, 0.18, 0.2, prop_w + 0.04), p + Vector4(0, POLE_H - 0.42, 0, 0))
	# The roof: two panels from the ridge down to the ground either side, flaring out past the poles at
	# the ground (the sheet's tents are wider at the foot than at the ridge), and a hip at each end from
	# the pole top down to the panels' foot corners.
	var ridge_len: float = (b - a).length()
	var flare: float = TENT_FLARE
	for s in [-1.0, 1.0]:
		var top_line: Vector4 = mid + up * RIDGE_H
		var foot: Vector4 = mid + side * (s * TENT_HALF)
		var slope: Vector4 = (foot - top_line)
		var slope_len: float = slope.length()
		var sd: Vector4 = slope / slope_len
		var basis: Projection = _frame_axes(along, sd)
		var centre: Vector4 = (top_line + foot) * 0.5
		# A trapezoid: the box's top edge (toward the ridge) as long as the ridge, its foot longer.
		var box := BoxTetraMesh4D.new()
		box.size = Vector4(ridge_len + 2.0 * flare, slope_len, 0.05, prop_w)
		var mesh: ArrayTetraMesh4D = box.to_array_tetra_mesh()
		var verts: PackedVector4Array = mesh.get_vertex_positions()
		for i in verts.size():
			# Local -y is toward the ridge (sd points down the slope).
			if verts[i].y < 0.0:
				verts[i] = Vector4(verts[i].x * ridge_len / (ridge_len + 2.0 * flare), verts[i].y, verts[i].z, verts[i].w)
		mesh.set_vertex_positions(verts)
		_merge(canvas, mesh, centre, basis)
		var out_n: Vector4 = basis.z if (basis.z as Vector4).dot(side * s + up) > 0.0 else -basis.z
		# Trim: along the foot, and down both slanted ends.
		_box(trim, Vector4(ridge_len + 2.0 * flare + 0.04, 0.14, 0.06, prop_w + 0.02), foot - sd * 0.07 + out_n * 0.01, basis)
		for e in [-1.0, 1.0]:
			var t0: Vector4 = top_line + along * (e * ridge_len * 0.5)
			var f0: Vector4 = foot + along * (e * (ridge_len * 0.5 + flare))
			_strut(trim, t0 + out_n * 0.03, f0 + out_n * 0.03, 0.1)
		var facing_fire: bool = s > 0.0
		if facing_fire and door_side:
			_door_in_side(mid, along, side, sd, basis, slope_len, out_n)
		elif facing_fire and not door_side:
			_diamond(mid + side * (TENT_HALF * 0.52) + up * (RIDGE_H * 0.48) + out_n * 0.04, along, sd)
	# The hips: a triangle at each end, from the pole top to the two foot corners.
	for e in [-1.0, 1.0]:
		var apex: Vector4 = mid + along * (e * ridge_len * 0.5) + up * RIDGE_H
		var c1: Vector4 = mid + along * (e * (ridge_len * 0.5 + flare)) + side * TENT_HALF
		var c2: Vector4 = mid + along * (e * (ridge_len * 0.5 + flare)) - side * TENT_HALF
		var open: bool = not door_side and e < 0.0
		_hip(canvas_dark if open else canvas, apex, c1, c2)
		_box(trim, Vector4(0.1, 0.12, TENT_HALF * 2.0, prop_w + 0.02), (c1 + c2) * 0.5 + up * 0.06, _frame_axes(along, up))
		if open:
			# The flaps tied back either side of the door.
			for s in [-1.0, 1.0]:
				var corner: Vector4 = c1 if s > 0.0 else c2
				_strut(canvas, corner.lerp(apex, 0.1) + up * 0.1, apex.lerp(corner, 0.35), 0.16)
	# The guy ropes: from each pole top out along the ridge and to either side, to stakes.
	for p in [a, b]:
		var out: Vector4 = (p - mid).normalized()
		for s in [-0.8, 0.0, 0.8]:
			var stake: Vector4 = p + out * 1.7 + side * (s * 1.4)
			_strut(rope, p + up * (POLE_H - 0.3), stake + up * 0.3, 0.035)
			_box(timber_dark, Vector4(0.09, 0.35, 0.09, prop_w), stake + up * 0.17)
	# Solid: the tent's footprint, as boxes that do not turn (a short row along the ridge).
	for k in 4:
		var q: Vector4 = a.lerp(b, (float(k) + 0.5) / 4.0)
		_solid(Vector4(1.6, 2.4, 1.6, prop_w), q + up * 1.2)


## The left tent's door: a dark opening in the side facing the fire, the flap rolled up into a scroll
## over it with maroon ties, a bedroll inside.
func _door_in_side(mid: Vector4, along: Vector4, side: Vector4, sd: Vector4, basis: Projection, slope_len: float, n: Vector4) -> void:
	var up := Vector4(0, 1, 0, 0)
	# Along the slope from the ridge: the opening from 0.42 to 1.0 of the way down.
	var top_line: Vector4 = mid + up * RIDGE_H
	var p0: Vector4 = top_line + sd * (slope_len * 0.42)
	var p1: Vector4 = top_line + sd * (slope_len * 0.98)
	var centre: Vector4 = (p0 + p1) * 0.5 + n * 0.04
	_box(canvas_dark, Vector4(1.15, (p1 - p0).length(), 0.03, prop_w * 0.9), centre, basis)
	# The scroll over it.
	var scroll_at: Vector4 = p0 + n * 0.12 - sd * 0.1
	for k in 2:
		_box(canvas, Vector4(1.35, 0.2, 0.2, prop_w * 0.8), scroll_at, basis * _turn_x_local(PI * 0.25 * float(k)))
	for e in [-1.0, 1.0]:
		_box(trim, Vector4(0.08, 0.24, 0.24, prop_w * 0.85), scroll_at + along * (e * 0.45), basis)
	# The bedroll on the ground inside: a maroon roll along the tent.
	var bed: Vector4 = mid + side * 0.55 + up * 0.2
	for k in 2:
		_box(trim, Vector4(1.1, 0.36, 0.36, prop_w * 0.7), bed, _frame_with(along, up) * _turn_x_local(PI * 0.25 * float(k)))
	_box(canvas_dark, Vector4(1.6, 0.06, 1.6, prop_w * 0.7), mid + up * 0.03)


## The right tent's diamond: a maroon diamond outline with a small solid one inside, on the side
## facing the fire.
func _diamond(at: Vector4, along: Vector4, sd: Vector4) -> void:
	var u: Vector4 = along
	var v: Vector4 = (-sd).normalized()
	var surf: Vector4 = at
	for k in 4:
		var ang: float = PI * 0.25 + PI * 0.5 * float(k)
		var dir: Vector4 = u * cos(ang) + v * sin(ang)
		var tang: Vector4 = u * cos(ang + PI * 0.5) + v * sin(ang + PI * 0.5)
		_box(trim, Vector4(0.42, 0.08, 0.03, prop_w * 0.85), surf + dir * 0.21, _frame_axes(tang, dir))
	_box(trim, Vector4(0.15, 0.15, 0.03, prop_w * 0.85), surf, _frame_axes(u * 0.7071 + v * 0.7071, -u * 0.7071 + v * 0.7071))


# --- The cook frame, the fire -------------------------------------------------------------------

## Two posts and a crossbar (fence tech), the cauldron on a chain from the bar's middle.
func _cook_frame() -> void:
	_fence_pair(COOK[0], COOK[1], COOK_H, 0.16, 1, 0.14, "CookFrame")
	var a := Vector4(COOK[0].x, 0, COOK[0].y, 0)
	var b := Vector4(COOK[1].x, 0, COOK[1].y, 0)
	var mid: Vector4 = (a + b) * 0.5
	for p in [a, b]:
		_box(iron, Vector4(0.2, 0.14, 0.2, prop_w + 0.03), p + Vector4(0, COOK_H - 0.12, 0, 0))
	var pot_y: float = 1.05
	_strut(iron, mid + Vector4(0, COOK_H - 0.08, 0, 0), mid + Vector4(0, pot_y + 0.36, 0, 0), 0.03)
	# The pot: rings narrowing to the bottom, a rim, the stew glowing.
	var rings: Array = [[0.0, 0.2], [0.12, 0.3], [0.26, 0.34], [0.38, 0.33]]
	for r in rings:
		_disc_y(iron, mid + Vector4(0, pot_y + float(r[0]), 0, 0), float(r[1]), 0.14, prop_w * 0.6, 8)
	_disc_y(iron, mid + Vector4(0, pot_y + 0.46, 0, 0), 0.35, 0.04, prop_w * 0.62, 8)
	_disc_y(flame, mid + Vector4(0, pot_y + 0.45, 0, 0), 0.28, 0.03, prop_w * 0.5, 8, true)
	for e in [-1.0, 1.0]:
		_strut(iron, mid + Vector4(e * 0.3, pot_y + 0.46, 0, 0), mid + Vector4(0, pot_y + 0.75, 0, 0), 0.025)


## The fire: a ring of stones, logs crossed in it, flames and embers glowing, and its light.
func _fire() -> void:
	var n: int = 11
	for k in n:
		var a: float = TAU * float(k) / float(n)
		var s: float = _rng.randf_range(0.34, 0.44)
		_stone(["chip", "round", "block"][k % 3], Vector4(cos(a) * FIRE_R * 0.82, -0.05, sin(a) * FIRE_R * 0.82, _rng.randf_range(-0.3, 0.3)),
			Vector3(s * 1.1, s * 0.8, s), s * 2.0, -a + _rng.randf_range(-0.3, 0.3))
	for k in 5:
		var a: float = TAU * float(k) / 5.0 + 0.3
		var out := Vector4(cos(a), 0, sin(a), 0)
		_log(out * 0.45 + Vector4(0, 0.12, 0, 0), out * -0.05 + Vector4(0, 0.45, 0, 0), 0.13)
	_disc_y(flame, Vector4(0, 0.08, 0, 0), 0.42, 0.06, prop_w * 0.6, 8, true)
	var flames := MeshInstance4D.new()
	flames.name = "Flames"
	var fm := ArrayTetraMesh4D.new()
	for k in 4:
		var box := BoxTetraMesh4D.new()
		box.size = Vector4(0.24, 1.1 - 0.15 * float(k), 0.24, prop_w * 0.5)
		fm.merge_with(box.to_array_tetra_mesh(), Vector4(cos(float(k) * 1.7) * 0.14, 0.6 - 0.07 * float(k), sin(float(k) * 1.7) * 0.14, 0), _turn_y(0.4 * float(k)) * _turn_z(0.22 * (float(k) - 1.5)))
	flames.mesh = fm
	flames.material_override = Mats.glow(flame, 1.0)
	_own(flames)
	_flames.append(flames)
	var core := MeshInstance4D.new()
	core.name = "FlameCore"
	var cm := ArrayTetraMesh4D.new()
	var cb := BoxTetraMesh4D.new()
	cb.size = Vector4(0.2, 0.62, 0.2, prop_w * 0.45)
	cm.merge_with(cb.to_array_tetra_mesh(), Vector4(0, 0.42, 0, 0), _turn_y(0.7))
	core.mesh = cm
	core.material_override = Mats.glow(flame_core, 1.0)
	_own(core)
	_flames.append(core)
	if not Engine.is_editor_hint():
		_light = OmniLight4D.new()
		_light.name = "FireLight"
		_light.position = Vector4(0, 1.0, 0, 0)
		_light.set("omni_range_meters", fire_reach)
		_light.light_color = fire_colour
		_light.light_energy = fire_energy
		_own(_light)
	_solid(Vector4(FIRE_R * 2.0, 0.5, FIRE_R * 2.0, prop_w), Vector4(0, 0.25, 0, 0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	for i in _flames.size():
		var f: MeshInstance4D = _flames[i]
		if is_instance_valid(f):
			var s: float = 1.0 + 0.12 * sin(_t * (7.0 + float(i) * 2.3)) + 0.06 * sin(_t * 13.0 + float(i))
			f.basis = Basis4D.from_zx(_t * 0.6 + float(i)) * Projection(Vector4(1, 0, 0, 0), Vector4(0, s, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	if _light != null:
		_light.light_energy = fire_energy * (0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 5.3 + 1.0))
	_update_align()


# --- Benches, the lantern, the stores -----------------------------------------------------------

## A bench facing the fire: a thick plank on two blocks, iron brackets at its ends.
func _bench(at2: Vector2) -> void:
	var c := Vector4(at2.x, 0, at2.y, 0)
	var to_fire: Vector2 = -at2.normalized()
	var yaw: float = atan2(to_fire.x, to_fire.y)
	var rot: Projection = Basis4D.from_zx(yaw)
	_box(timber, Vector4(1.9, 0.12, 0.44, prop_w), c + Vector4(0, 0.44, 0, 0), rot)
	for e in [-1.0, 1.0]:
		var leg: Vector4 = c + rot * Vector4(e * 0.72, 0, 0, 0)
		_box(timber_dark, Vector4(0.14, 0.38, 0.4, prop_w), leg + Vector4(0, 0.19, 0, 0), rot)
		_box(iron, Vector4(0.06, 0.14, 0.46, prop_w + 0.02), c + rot * Vector4(e * 0.85, 0.44, 0, 0), rot)
	_solid(Vector4(1.4, 0.5, 1.4, prop_w), c + Vector4(0, 0.25, 0, 0))


## The lantern: a post with an arm toward the camp and a brace, the lantern hanging from it, its
## panes glowing.
func _lantern() -> void:
	var c := Vector4(LANTERN.x, 0, LANTERN.y, 0)
	var toward: Vector4 = Vector4(-LANTERN.x, 0, -LANTERN.y, 0).normalized()
	_box(timber_dark, Vector4(0.16, LANTERN_H, 0.16, prop_w), c + Vector4(0, LANTERN_H * 0.5, 0, 0))
	_box(iron, Vector4(0.2, 0.14, 0.2, prop_w + 0.03), c + Vector4(0, LANTERN_H - 0.25, 0, 0))
	var arm_end: Vector4 = c + toward * 0.62 + Vector4(0, LANTERN_H - 0.12, 0, 0)
	_strut(timber, c + Vector4(0, LANTERN_H - 0.12, 0, 0), arm_end, 0.12)
	_strut(timber_dark, c + Vector4(0, LANTERN_H - 0.6, 0, 0), c + toward * 0.4 + Vector4(0, LANTERN_H - 0.15, 0, 0), 0.07)
	var lamp: Vector4 = arm_end - Vector4(0, 0.48, 0, 0)
	_strut(iron, arm_end, lamp + Vector4(0, 0.25, 0, 0), 0.03)
	_box(iron, Vector4(0.3, 0.06, 0.3, prop_w * 0.6), lamp + Vector4(0, 0.22, 0, 0))
	_box(iron, Vector4(0.3, 0.05, 0.3, prop_w * 0.6), lamp - Vector4(0, 0.2, 0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(iron, Vector4(0.04, 0.4, 0.04, prop_w * 0.6), lamp + Vector4(sx * 0.13, 0, sz * 0.13, 0))
	_box(flame_core, Vector4(0.22, 0.32, 0.22, prop_w * 0.5), lamp, Projection.IDENTITY, true)
	_box(iron, Vector4(0.18, 0.1, 0.18, prop_w * 0.6), lamp + Vector4(0, 0.3, 0, 0))
	_solid(Vector4(0.3, LANTERN_H, 0.3, prop_w), c + Vector4(0, LANTERN_H * 0.5, 0, 0))


## A crate: its box, a darker frame round every edge, iron corners.
func _crate(at2: Vector2, s: float) -> void:
	var c := Vector4(at2.x, s * 0.5, at2.y, 0)
	var rot: Projection = Basis4D.from_zx(_rng.randf_range(-0.25, 0.25))
	_box(timber, Vector4(s, s, s, prop_w * 0.7), c, rot)
	for ax in 3:
		for e1 in [-1.0, 1.0]:
			for e2 in [-1.0, 1.0]:
				var size := Vector4(0.08, 0.08, 0.08, prop_w * 0.72)
				size[ax if ax < 3 else 0] = s + 0.02
				var off := Vector4.ZERO
				var others: Array = [0, 1, 2]
				others.erase(ax)
				off[others[0]] = e1 * s * 0.5
				off[others[1]] = e2 * s * 0.5
				_box(timber_dark, size, c + rot * off, rot)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(iron, Vector4(0.1, 0.1, 0.1, prop_w * 0.74), c + rot * Vector4(sx * s * 0.5, sy * s * 0.5, sz * s * 0.5, 0), rot)
	_solid(Vector4(s, s, s, prop_w), c)


func _barrel() -> void:
	var c := Vector4(BARREL.x, 0, BARREL.y, 0)
	var r: float = 0.38
	var h: float = 0.95
	var face: float = 2.0 * r * tan(PI / 8.0) * 1.03
	for k in 4:
		var t: float = PI * float(k) / 4.0
		_box(timber, Vector4(r * 2.0, h, face, prop_w * 0.6), c + Vector4(0, h * 0.5, 0, 0), _turn_y(t))
		for y in [0.15, 0.5, 0.82]:
			_box(iron, Vector4(r * 2.0 + 0.03, 0.06, face + 0.012, prop_w * 0.6 + 0.02), c + Vector4(0, y, 0, 0), _turn_y(t))
		_box(timber_dark, Vector4(r * 1.8, 0.04, face * 0.9, prop_w * 0.55), c + Vector4(0, h + 0.01, 0, 0), _turn_y(t))
	_solid(Vector4(0.8, h, 0.8, prop_w), c + Vector4(0, h * 0.5, 0, 0))


## The log pile: logs along z, their ends toward the camp's front, four, three, two, one.
func _log_pile() -> void:
	var c := Vector4(LOGS.x, 0, LOGS.y, 0)
	var r: float = 0.14
	var rows: Array = [4, 3, 2, 1]
	for i in rows.size():
		var cnt: int = rows[i]
		for k in cnt:
			var x: float = (float(k) - float(cnt - 1) * 0.5) * r * 2.05
			var y: float = r + float(i) * r * 1.75
			var a: Vector4 = c + Vector4(x, y, -0.6, 0)
			var b: Vector4 = c + Vector4(x, y, 0.6 + _rng.randf_range(-0.08, 0.08), 0)
			_log(a, b, r)
	_solid(Vector4(1.2, 0.75, 1.3, prop_w), c + Vector4(0, 0.37, 0, 0))


## The chopping block: a stump with the axe in it.
func _stump() -> void:
	var c := Vector4(STUMP.x, 0, STUMP.y, 0)
	_disc_y(timber, c + Vector4(0, 0.27, 0, 0), 0.32, 0.54, prop_w * 0.7, 8)
	_disc_y(timber.lightened(0.2), c + Vector4(0, 0.545, 0, 0), 0.28, 0.02, prop_w * 0.65, 8)
	var blade: Vector4 = c + Vector4(0.05, 0.6, 0, 0)
	_box(iron, Vector4(0.22, 0.16, 0.05, prop_w * 0.5), blade)
	_strut(timber_dark, blade + Vector4(0.08, 0.05, 0, 0), blade + Vector4(0.75, 0.45, 0.1, 0), 0.06)
	_solid(Vector4(0.7, 0.55, 0.7, prop_w), c + Vector4(0, 0.27, 0, 0))


## A log from [param a] to [param b]: an eight-sided round (two crossed boxes), its ends paler.
func _log(a: Vector4, b: Vector4, r: float) -> void:
	var d: Vector4 = b - a
	var length: float = d.length()
	var frame: Projection = _frame_along(d / length)
	for k in 2:
		_box(timber, Vector4(r * 1.75, length, r * 1.75, prop_w * 0.5), (a + b) * 0.5, frame * _turn_y(PI * 0.25 * float(k)))
	for e in [a, b]:
		_box(timber.lightened(0.25), Vector4(r * 1.5, 0.02, r * 1.5, prop_w * 0.48), e, frame)


## Grass: clumps thick round the disc's edge, some by the tents and the stores.
func _grass() -> void:
	for k in 56:
		var a: float = TAU * float(k) / 56.0 + _rng.randf_range(-0.05, 0.05)
		var f: float = 1.0 - _rng.randf_range(0.02, 0.14)
		_tuft(Vector4(DISC_C.x + cos(a) * DISC_R * f, 0.0, DISC_C.y + sin(a) * DISC_RZ * f, _rng.randf_range(-0.9, 0.9)), _rng.randf_range(1.0, 1.6))
	for k in 14:
		var a: float = _rng.randf_range(0.0, TAU)
		var r: float = _rng.randf_range(SAND_R - 0.2, DISC_R - 1.0)
		_tuft(Vector4(DISC_C.x + cos(a) * r, 0.0, DISC_C.y + sin(a) * r, _rng.randf_range(-0.9, 0.9)), _rng.randf_range(0.9, 1.3))


# --- Align to slice ------------------------------------------------------------------------------

## Where the player's slice crosses the camp's (x, z): the W it is at there. The slice is the
## camera's: every point p with (p - eye) . n = 0, n the camera's fourth axis.
func slice_w_here() -> float:
	var cam := _camera()
	if cam == null:
		return INF
	var n: Vector4 = cam.global_basis.w.normalized()
	if absf(n.w) < 1e-3:
		return INF
	var e: Vector4 = cam.global_position
	var c: Vector4 = global_position
	return e.w - (n.x * (c.x - e.x) + n.y * (c.y + 1.0 - e.y) + n.z * (c.z - e.z)) / n.w


## Whether the camp is partly in your slice now and not already square to it: what brings the button.
func can_align() -> bool:
	if _player == null or not _player.is_inside_tree() or not _player.is_visible_in_tree() or _player.get("input_enabled") == false:
		return false
	var gap: Vector4 = global_position - _player.global_position
	if Vector2(gap.x, gap.z).length() > align_reach:
		return false
	var rig: Node = _player.get_node_or_null("CameraRig")
	if rig == null or not rig.has_method("align_to") or bool(rig.call("is_aligned_to", global_position.w)):
		return false
	var off: float = absf(slice_w_here() - global_position.w)
	return off < visible_half_w and absf(_player.global_position.w - global_position.w) > 0.3


func align() -> void:
	var rig: Node = _player.get_node_or_null("CameraRig") if _player != null else null
	if rig != null and rig.has_method("align_to"):
		rig.call("align_to", global_position.w)


func _camera() -> Camera4D:
	return _player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if _player != null else null


func _update_align() -> void:
	if _tag == null:
		return
	var text: String = ""
	if can_align():
		# Over the fire, at your own W so the tag sits in your slice.
		var at: Vector4 = global_position + Vector4(0, 3.2, 0, 0)
		at.w = slice_w_here()
		_tag_anchor.global_position = at
		text = "%s  Align to slice" % OS.get_keycode_string(align_key)
	if text != _shown:
		_shown = text
		if text == "":
			_tag.clear()
		else:
			_tag.show_text(text)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == align_key and can_align():
		get_viewport().set_input_as_handled()
		align()


# --- Helpers ------------------------------------------------------------------------------------

## Two posts with one beam at their tops, as a fence (fence tech: a seed strip in W between them).
func _fence_pair(a: Vector2, b: Vector2, height: float, thick: float, beams: int, beam_h: float, name: String) -> void:
	var seed := ArrayPolyMesh4D.new()
	var hw: float = prop_w * 0.5
	var v0: int = seed.append_vertex(Vector4(a.x, 0, a.y, -hw))
	var v1: int = seed.append_vertex(Vector4(b.x, 0, b.y, -hw))
	var v2: int = seed.append_vertex(Vector4(b.x, 0, b.y, hw))
	var v3: int = seed.append_vertex(Vector4(a.x, 0, a.y, hw))
	var e0: int = seed.append_edge_indices(v0, v1)
	var e1: int = seed.append_edge_indices(v1, v2)
	var e2: int = seed.append_edge_indices(v2, v3)
	var e3: int = seed.append_edge_indices(v3, v0)
	seed.append_poly_cell(2, PackedInt32Array([e0, e1, e2, e3]))
	var f := FenceGenerator4D.new()
	f.name = name
	f.update_automatically = false
	f.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
	f.seed_mesh_4d = seed
	f.post_height_meters = height
	f.post_thickness_meters = thick
	f.rib_height_ratio = 0.999
	f.rib_thickness_ratio = 0.95
	f.beam_count = beams
	f.beam_max_height_ratio = (height - 0.1) / height
	f.beam_coverage = clampf(beam_h / ((height - 0.1) / float(beams)), 0.02, 1.0)
	f.beam_thickness_ratio = 0.75
	f.desired_spacing_meters = 0.0
	f.post_material = _wood
	f.rib_material = _wood
	f.beam_material = _wood
	_own(f)
	f.update_fence_mesh_now()


## A flat triangle from [param apex] down to [param c1] and [param c2] (a tent's hip).
func _hip(colour: Color, apex: Vector4, c1: Vector4, c2: Vector4) -> void:
	var base_mid: Vector4 = (c1 + c2) * 0.5
	var x: Vector4 = (c1 - c2).normalized()
	var to_apex: Vector4 = apex - base_mid
	var y: Vector4 = (to_apex - x * x.dot(to_apex)).normalized()
	var tall: float = (to_apex - x * x.dot(to_apex)).length()
	var box := BoxTetraMesh4D.new()
	box.size = Vector4((c1 - c2).length(), tall, 0.05, prop_w)
	var mesh: ArrayTetraMesh4D = box.to_array_tetra_mesh()
	var verts: PackedVector4Array = mesh.get_vertex_positions()
	var shift: float = x.dot(apex - base_mid)
	for i in verts.size():
		if verts[i].y > 0.0:
			verts[i] = Vector4(shift, verts[i].y, verts[i].z, verts[i].w)
	mesh.set_vertex_positions(verts)
	_merge(colour, mesh, base_mid + y * (tall * 0.5), _frame_axes(x, y))


## A triangle (a gable) standing at [param at] across [param along]: base [param half] either side
## along [param side], apex [param tall] up, [param t] thick.
func _triangle(colour: Color, at: Vector4, along: Vector4, side: Vector4, half: float, tall: float, t: float) -> void:
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(half * 2.0, tall, t, prop_w)
	var mesh: ArrayTetraMesh4D = box.to_array_tetra_mesh()
	var verts: PackedVector4Array = mesh.get_vertex_positions()
	for i in verts.size():
		if verts[i].y > 0.0:
			verts[i] = Vector4(0.0, verts[i].y, verts[i].z, verts[i].w)
	mesh.set_vertex_positions(verts)
	_merge(colour, mesh, at + Vector4(0, tall * 0.5, 0, 0), _frame_axes(side, Vector4(0, 1, 0, 0)))


## A frame with x along [param x] and y along [param y] (both unit, at right angles), z the third.
static func _frame_axes(x: Vector4, y: Vector4) -> Projection:
	var z := Vector4(x.y * y.z - x.z * y.y, x.z * y.x - x.x * y.z, x.x * y.y - x.y * y.x, 0)
	var f := Projection(x, y, z, Vector4(0, 0, 0, 1))
	if f.determinant() < 0.0:
		f = Projection(x, y, -z, Vector4(0, 0, 0, 1))
	return f


## A frame with x along [param x] and z along [param z] (horizontal), y up.
static func _frame_with(x: Vector4, z: Vector4) -> Projection:
	return _frame_axes(x.normalized(), Vector4(0, 1, 0, 0)) if absf(x.y) < 0.9 else Projection.IDENTITY


static func _turn_x_local(t: float) -> Projection:
	return Projection(Vector4(1, 0, 0, 0), Vector4(0, cos(t), sin(t), 0), Vector4(0, -sin(t), cos(t), 0), Vector4(0, 0, 0, 1))


func _stone(kind: String, base: Vector4, size: Vector3, wsize: float, yaw: float) -> void:
	var half: Vector4 = (CutStone.KINDS[kind][0] as Vector4)
	var scale := Vector4(size.x / (2.0 * half.x), size.y / (2.0 * half.y), size.z / (2.0 * half.z), wsize / (2.0 * half.w))
	_stones.append([kind, _rng.randi() % CutStone.VARIANTS, base + Vector4(0, size.y * 0.5, 0, 0), scale, yaw, Vector2.ZERO])


func _tuft(at: Vector4, size: float) -> void:
	_tufts.append([_rng.randi() % 6, at, size, _rng.randf_range(0.0, TAU)])


## An ellipse lying flat, [param rx] by [param rz].
func _ellipse_y(colour: Color, at: Vector4, rx: float, rz: float, t: float, wd: float, sides: int = 16) -> void:
	var face: float = 2.0 * tan(PI / float(sides)) * 1.03
	var scale := Projection(Vector4(rx, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, rz, 0), Vector4(0, 0, 0, 1))
	for k in sides / 2:
		_box(colour, Vector4(2.0, t, face, wd), at, scale * _turn_y(PI * float(k) / float(sides / 2)))


## A round disc lying flat: [param sides] sided, [param t] thick, [param wd] deep in W.
func _disc_y(colour: Color, at: Vector4, r: float, t: float, wd: float, sides: int = 12, glow: bool = false) -> void:
	var face: float = 2.0 * r * tan(PI / float(sides)) * 1.03
	for k in sides / 2:
		_box(colour, Vector4(r * 2.0, t, face, wd), at, _turn_y(PI * float(k) / float(sides / 2)), glow)


func _box(colour: Color, size: Vector4, at: Vector4, basis: Projection = Projection.IDENTITY, glow: bool = false) -> void:
	var box := BoxTetraMesh4D.new()
	box.size = size
	_merge(colour, box.to_array_tetra_mesh(), at, basis, glow)


func _merge(colour: Color, mesh: ArrayTetraMesh4D, at: Vector4, basis: Projection = Projection.IDENTITY, glow: bool = false) -> void:
	var into: Dictionary = _glows if glow else _batches
	var key: String = colour.to_html(false)
	if not into.has(key):
		into[key] = ArrayTetraMesh4D.new()
	(into[key] as ArrayTetraMesh4D).merge_with(mesh, at, basis)


func _strut(colour: Color, a: Vector4, b: Vector4, thick: float) -> void:
	var d: Vector4 = b - a
	var length_: float = d.length()
	if length_ < 0.001:
		return
	_box(colour, Vector4(thick, length_, thick, prop_w), (a + b) * 0.5, _frame_along(d / length_))


func _flush() -> void:
	for key in _batches:
		var node := MeshInstance4D.new()
		node.name = "Props_" + String(key)
		node.mesh = _batches[key]
		var m := TetraMaterial4D.new()
		m.albedo_color = Color.html(key)
		node.material_override = m
		_own(node)
	for key in _glows:
		var node := MeshInstance4D.new()
		node.name = "Glow_" + String(key)
		node.mesh = _glows[key]
		node.material_override = Mats.glow(Color.html(key), 1.0)
		_own(node)
	var merged := ArrayTetraMesh4D.new()
	var count: int = 0
	for s in _stones:
		var mesh: ArrayTetraMesh4D = StoneSet.stone_mesh(String(s[0]), int(s[1]))
		if mesh != null:
			merged.merge_with(mesh, s[2], StoneSet.placement_basis(s[3], float(s[4]), s[5]))
			count += 1
	for t in _tufts:
		var mesh: ArrayTetraMesh4D = StoneSet.stone_mesh("tuft", int(t[0]))
		if mesh != null:
			var sz: float = t[2]
			merged.merge_with(mesh, t[1], Basis4D.from_zx(float(t[3])) * Projection(Vector4(sz, 0, 0, 0), Vector4(0, sz, 0, 0), Vector4(0, 0, sz, 0), Vector4(0, 0, 0, sz)))
			count += 1
	if count > 0:
		var node := MeshInstance4D.new()
		node.name = "Stones"
		node.mesh = merged
		node.material_override = TerrainBake.material()
		_own(node)
	_batches.clear()
	_glows.clear()


func _solid(size: Vector4, at: Vector4) -> void:
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	holder.shape = shape
	holder.position = at
	_body.add_child(holder)


static func _frame_along(y: Vector4) -> Projection:
	var picks: Array[Vector4] = []
	for axis in [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1)]:
		var v: Vector4 = axis - y * y.dot(axis)
		for p in picks:
			v -= p * p.dot(v)
		if v.length() > 0.2:
			picks.append(v.normalized())
		if picks.size() == 3:
			break
	var frame := Projection(picks[0], y, picks[1], picks[2])
	if frame.determinant() < 0.0:
		frame.w = -frame.w
	return frame


static func _turn_y(t: float) -> Projection:
	return Projection(Vector4(cos(t), 0.0, -sin(t), 0.0), Vector4(0.0, 1.0, 0.0, 0.0), Vector4(sin(t), 0.0, cos(t), 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


static func _turn_z(t: float) -> Projection:
	return Projection(Vector4(cos(t), sin(t), 0.0, 0.0), Vector4(-sin(t), cos(t), 0.0, 0.0), Vector4(0.0, 0.0, 1.0, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)
