@tool
extends Node4D

## THE DREAM SHIFTER (9 Oct 2026, Ramon's onboarding brief for the dev and art looks; follow_up/pen_dream_shifter.md).
## "a short, stumpy Greek-style pillar, about neck height, with a small floating 24-cell hovering above it ... the
## pillar should be connected to a path but very very close to the main path, impossible to miss."
##
## WHERE: halfway down the first road there is, from the start to Trym's house, on the right-hand side as you walk it,
## at the end of a two-metre spur of path (PenLayout/paths/pen_b.tres, node 25 on the road and 24 at the pillar). The
## first objective is "Follow the path to Trym's house", so nobody can start the game without passing within three
## metres of it, ten seconds in, and from the start it stands in plain view down the road.
##
## WHAT IT IS: a column in marble (a square step, a round base, a shaft that swells a little, a flared capital and a
## square top), round through W as it is across (the loft builder's sections are balls through X, Z and W), and over
## it a 24-cell in crystal. The 24-cell turns slowly through W as well as round, so its slice is never the same shape
## twice: an octahedron, then a cuboctahedron, then something in between. That is the point of it: the one object in
## the valley whose look you cannot pin down. Inside it a smaller one turns the other way; three little 16-cells orbit.
## It wakes when you come near (brighter, faster), and flares when it shifts the world
## (discovery/dream_shifter/pen_look_guide_4d.gd does the shift; this only shows it).
##
## THE LOOKS: the crystal is the Look's own (_look_own), so it is the same crystal in both; the pillar is a landmark
## (orange in the dev look: "DreamShifter" is in the Look's orange_units).
##
## Built when it loads (and in the editor, to place it), never saved into the scene. Move or turn this node to move it;
## its front (+z) faces the road. NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/chickenpen/scripts/loft_builder_4d.gd")
const CELL24 := "res://models/primitives/platonic/24_cell/24_cell.g4b"
const CrystalShader := preload("res://ramon/chickenpen/discovery/dream_shifter/dream_crystal.gdshader")

@export var player_path: NodePath = ^"../../Player"
## The crystal's centre above the ground, and its size (the 24-cell model scaled by this).
@export_range(1.0, 3.5, 0.05, "suffix:m") var orb_height: float = 1.92:
	set(v):
		orb_height = v
		_later()
@export_range(0.1, 1.0, 0.01) var orb_scale: float = 0.38:
	set(v):
		orb_scale = v
		_later()
@export var marble: Color = Color(0.86, 0.84, 0.78)
@export var marble_shadow: Color = Color(0.70, 0.68, 0.63)
@export var core_colour: Color = Color(0.20, 0.34, 0.95)
@export var rim_colour: Color = Color(0.72, 0.96, 1.0)
@export var light_colour: Color = Color(0.55, 0.80, 1.0)
## How near (on the ground) it starts to wake, and how near it is fully awake.
@export_range(2.0, 20.0, 0.5, "suffix:m") var wake_range: float = 9.0
@export_range(1.0, 10.0, 0.5, "suffix:m") var awake_range: float = 3.5

## The column's height to the top of its capital.
const PILLAR_H := 1.36

var _player: Node4D
var _orb: Node4D
var _cell: MeshInstance4D
var _core: MeshInstance4D
var _shards: Array[Node4D] = []
var _cell_mat: ShaderMaterial
var _core_mat: ShaderMaterial
var _light: OmniLight4D
var _anchor: Node4D
var _t: float = 0.0
var _awake: float = 0.0
var _flare: float = 0.0
var _flare_len: float = 1.0
var _band: float = 0.0
## Held fully awake (while it talks and shifts), whatever the distance.
var hold_awake: bool = false


func _later() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()
	if not Engine.is_editor_hint():
		_player = get_node_or_null(player_path) as Node4D


func rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"_ds_part"):
			remove_child(child)
			child.free()
	_shards.clear()
	_light = null
	_pillar()
	_solid()
	_crystal()


func _part(node: Node, parent: Node = null) -> void:
	if parent == null:
		node.set_meta(&"_ds_part", true)
		add_child(node)
	else:
		parent.add_child(node)


func _flat(colour: Color) -> TetraMaterial4D:
	var mat := TetraMaterial4D.new()
	mat.albedo_color = colour
	return mat


## The column: two square steps, a round base (a torus, a hollow, a torus), the shaft with a little swell, a ring at
## its neck, the flared echinus and the square abacus on top. Round parts are lofted (sections are balls through X, Z
## and W, so it is as round in W as across); square parts are boxes.
func _pillar() -> void:
	var col := Node4D.new()
	col.name = "Column"
	_part(col)
	var steps := ArrayTetraMesh4D.new()
	for s in [[Vector4(0.0, 0.06, 0.0, 0.0), Vector4(0.96, 0.12, 0.96, 0.96)], [Vector4(0.0, 0.17, 0.0, 0.0), Vector4(0.80, 0.10, 0.80, 0.80)]]:
		var box := BoxTetraMesh4D.new()
		box.size = s[1]
		steps.merge_with(box.to_array_tetra_mesh(), s[0], Projection.IDENTITY)
	var top := BoxTetraMesh4D.new()
	top.size = Vector4(0.72, 0.09, 0.72, 0.72)
	steps.merge_with(top.to_array_tetra_mesh(), Vector4(0.0, PILLAR_H - 0.045, 0.0, 0.0), Projection.IDENTITY)
	_mesh(col, "Steps", steps, _flat(marble_shadow))
	# The round body, bottom to top: [height, radius]. The base's torus and hollow, the shaft swelling a little a third
	# of the way up (entasis) and narrowing to its neck ring, then the echinus flaring out under the abacus.
	var profile: Array = [
		[0.22, 0.31], [0.26, 0.335], [0.30, 0.31], [0.33, 0.27], [0.36, 0.29], [0.40, 0.255],
		[0.62, 0.262], [0.95, 0.248], [1.13, 0.228], [1.15, 0.24], [1.17, 0.226], [1.21, 0.25], [1.27, 0.31], [1.30, 0.34],
	]
	var secs: Array = []
	for p in profile:
		secs.append({"center": Vector4(0.0, float(p[0]), 0.0, 0.0), "radius": float(p[1]), "v_scale": 1.0, "w_scale": 1.0})
	var body: ArrayTetraMesh4D = Loft.build(secs, 5, 12, false, false, false, 1, false)
	if body != null:
		_mesh(col, "Shaft", body, _flat(marble))


func _mesh(parent: Node, part: String, mesh: Mesh4D, mat: Material4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	return node


## One box for the column, so you walk round it, not through it.
func _solid() -> void:
	var body := StaticBody4D.new()
	body.name = "Solid"
	_part(body)
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = Vector4(0.8, PILLAR_H, 0.8, 0.8)
	holder.shape = shape
	holder.position = Vector4(0.0, PILLAR_H * 0.5, 0.0, 0.0)
	body.add_child(holder)


## The crystal: the 24-cell, a smaller one inside turning the other way, three 16-cells in orbit, its light, and the
## point the prompt and the talking hang off.
func _crystal() -> void:
	_orb = Node4D.new()
	_orb.name = "Orb"
	_part(_orb)
	_orb.position = Vector4(0.0, orb_height, 0.0, 0.0)
	var mesh: Mesh4D = load(CELL24) as Mesh4D
	if mesh == null:
		var fallback := OrthoplexTetraMesh4D.new()
		mesh = fallback
	var cell_mat: TetraMaterial4D = _crystal_material(core_colour, rim_colour)
	_cell_mat = cell_mat.get_cross_section_material_3d()
	_cell = _crystal_mesh("Cell", mesh, orb_scale, cell_mat)
	var core_mat: TetraMaterial4D = _crystal_material(rim_colour, Color(1.0, 1.0, 1.0))
	_core_mat = core_mat.get_cross_section_material_3d()
	_core = _crystal_mesh("Core", mesh, orb_scale * 0.42, core_mat)
	var shard_mesh := OrthoplexTetraMesh4D.new()
	for i in 3:
		var pivot := Node4D.new()
		pivot.name = "Orbit%d" % i
		_orb.add_child(pivot)
		var shard := MeshInstance4D.new()
		shard.name = "Shard"
		shard.mesh = shard_mesh
		shard.material_override = _cell.material_override
		shard.set_meta(&"_look_own", true)
		pivot.add_child(shard)
		shard.position = Vector4(orb_scale * 1.9, 0.0, 0.0, 0.0)
		shard.basis = Basis4D.from_scale_uniform(orb_scale * 0.16)
		_shards.append(pivot)
	# The scene's own Head (under this node, saved with it) is what the prompt and the dialogue box hang off; without
	# one, a point under the crystal.
	_anchor = get_node_or_null(^"Head") as Node4D
	if _anchor == null:
		_anchor = Node4D.new()
		_anchor.name = "TalkAnchor"
		_part(_anchor)
		_anchor.position = Vector4(0.0, orb_height - 0.25, 0.0, 0.0)
	if not Engine.is_editor_hint():
		_light = OmniLight4D.new()
		_light.name = "Glow"
		_light.set("omni_range_meters", 5.0)
		_light.light_color = light_colour
		_light.light_energy = 0.6
		_orb.add_child(_light)


func _crystal_material(core: Color, rim: Color) -> TetraMaterial4D:
	var mat := TetraMaterial4D.new()
	mat.albedo_color = Color.WHITE
	var cs: ShaderMaterial = mat.get_cross_section_material_3d()
	cs.shader = CrystalShader
	cs.set_shader_parameter("core_color", core)
	cs.set_shader_parameter("rim_color", rim)
	cs.set_shader_parameter("energy", 1.0)
	return mat


func _crystal_mesh(part: String, mesh: Mesh4D, s: float, mat: TetraMaterial4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = mesh
	node.material_override = mat
	node.set_meta(&"_look_own", true)
	_orb.add_child(node)
	node.basis = Basis4D.from_scale_uniform(s)
	return node


## Where the prompt and the conversation hang (the WorldTag's and the dialogue box's anchor).
func anchor() -> Node4D:
	return _anchor


## The crystal's centre, in the world.
func orb_position() -> Vector4:
	return _orb.global_position if _orb != null else global_position + Vector4(0.0, orb_height, 0.0, 0.0)


## A flash of light and a sweep up through the crystal, [param seconds] long: it shifting the world.
func flare(seconds: float = 1.2) -> void:
	_flare_len = maxf(seconds, 0.1)
	_flare = _flare_len


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _orb == null:
		return
	_t += delta
	var want: float = 0.0
	if hold_awake:
		want = 1.0
	elif _player != null:
		var gap: Vector4 = _player.global_position - global_position
		var d: float = Vector2(gap.x, gap.z).length()
		if absf(gap.w) < 3.0:
			want = 1.0 - smoothstep(awake_range, wake_range, d)
	_awake = move_toward(_awake, want, delta * 1.5)
	var f: float = 0.0
	if _flare > 0.0:
		_flare = maxf(_flare - delta, 0.0)
		var k: float = 1.0 - _flare / _flare_len
		f = sin(PI * k)
		_band = k * 2.0
	else:
		_band = fmod(_band + delta * (0.12 + 0.25 * _awake), 1.0)
	var spin: float = 0.25 + 0.45 * _awake + 2.5 * f
	# Round in three planes at three speeds, two of them into W: its slice keeps changing shape.
	var a: float = _t * spin
	_cell.basis = Basis4D.from_zx(a * 0.7) * Basis4D.from_xw(a * 0.43) * Basis4D.from_wy(a * 0.29) * Basis4D.from_scale_uniform(orb_scale * (1.0 + 0.18 * f))
	_core.basis = Basis4D.from_zx(-a * 1.3) * Basis4D.from_zw(-a * 0.8) * Basis4D.from_scale_uniform(orb_scale * 0.42 * (1.0 + 0.5 * f))
	for i in _shards.size():
		var ph: float = _t * (0.9 + 0.5 * _awake + 3.0 * f) + TAU * float(i) / 3.0
		_shards[i].basis = Basis4D.from_zx(ph) * Basis4D.from_xy(0.35 * sin(_t * 0.7 + float(i))) * Basis4D.from_xw(0.5 * sin(_t * 0.4 + float(i) * 2.0))
	_orb.position = Vector4(0.0, orb_height + sin(_t * 1.3) * 0.05 + 0.08 * f, 0.0, 0.0)
	var energy: float = 0.85 + 0.35 * _awake + 1.4 * f
	_cell_mat.set_shader_parameter("energy", energy)
	_cell_mat.set_shader_parameter("band", _band)
	_core_mat.set_shader_parameter("energy", 1.0 + 0.3 * _awake + 1.0 * f)
	if _light != null:
		_light.light_energy = 0.5 + 1.2 * _awake + 3.0 * f
		_light.set("omni_range_meters", 4.0 + 3.0 * _awake + 6.0 * f)
