extends Node4D

## The dreamer in the far room (Ramon, 28 Sept: "some abstract azatoth entity that you can
## talk to, ethereal, with moving limbs like an octi in all dimensions, and with a vibrant
## core ... it shimmers blue in the core. when it gets upset, or talks with warning the core
## glows red instead" - then: "higher, with many thin tentacles ... epic ... metallic light
## grey", "the center core ... something like a vortex", and "front side that's facing the
## character should be more flat, perhaps a donut, with the hollow side facing the player.
## like a fish mouth with many teeth, and the vortex ... more localized to the center").
##
## A MOUTH THAT FACES YOU. Hung high over the far room, it turns - slowly - to face you: a
## flat ring, two rows of teeth pointing in, and inside the ring, and only there, a vortex
## of streaks that turns faster toward its middle and sinks back into the throat, where the
## heart burns. Behind the ring two dozen limbs trail away from you, reaching in every
## direction there is - W included, so they curl into your slice and out of it.
##
## FACING YOU MEANS FACING YOUR SLICE. Its frame is built from where your head is and from
## your slice's own normal (the camera rig's W), so the ring stands square to you in the
## slice you are looking through, wherever you have turned it. The whole creature is
## children of two nodes turned by that frame; only the swirl and the limbs move piece by
## piece.
##
## LOFTED, AND STILL RIGID. The limbs, the ring and the streaks are one short tapered
## segment lofted once (loft_builder_4d.gd), the teeth one lofted cone; every piece is one
## of those two meshes, stretched and scaled into place. Nothing is skinned or rebuilt, and
## the two meshes' video memory is paid once however many pieces there are.
##
## A THIN TUBE IN 4D IS MOSTLY INVISIBLE: it crosses your slice only within its own radius,
## so every piece is [member w_thickness] times thicker through the slice's normal than
## across it - still thin to look at, and on your slice for metres at a time.
##
## [method set_mood] is called by its conversation (cave_dreamer_talk_4d.gd) and by coming
## too close: blue in calm, red in warning, and everything moves faster when it is red.

const LoftBuilder := preload("res://ramon/chickenpen/scripts/loft_builder_4d.gd")

const CALM_A := Color(0.30, 0.62, 1.0)
const CALM_B := Color(0.55, 0.40, 1.0)
const WARN_A := Color(1.0, 0.22, 0.16)
const WARN_B := Color(1.0, 0.45, 0.10)
## Metallic light grey, paler toward the tips, so the heart's light is what colours it.
const METAL := Color(0.60, 0.62, 0.66)
const METAL_PALE := Color(0.86, 0.88, 0.92)
const THROAT := Color(0.16, 0.17, 0.20)

@export var player_path: NodePath = NodePath("../../../Player")
@export var camera_rig_path: NodePath = NodePath("../../../Player/CameraRig")
## How high the mouth hangs above the floor, and how quickly it turns to you.
@export_range(1.0, 10.0, 0.1) var core_height: float = 5.5
@export_range(0.1, 5.0, 0.05) var turn_rate: float = 0.8
## Coming closer than this, across the floor and through W, upsets it.
@export_range(0.5, 5.0, 0.1) var too_close: float = 2.0
@export_range(1.0, 8.0, 0.1) var w_thickness: float = 3.0

@export_group("Mouth")
@export_range(0.8, 5.0, 0.05) var mouth_radius: float = 2.2
@export_range(0.05, 0.8, 0.01) var lip_radius: float = 0.3
@export_range(8, 48, 1) var lip_segments: int = 24
@export_range(0, 64, 1) var outer_teeth: int = 30
@export_range(0, 64, 1) var inner_teeth: int = 22

@export_group("Vortex")
@export_range(2, 12, 1) var vortex_arms: int = 6
@export_range(3, 24, 1) var streaks_per_arm: int = 9
@export_range(0.2, 0.95, 0.01) var vortex_fill: float = 0.62

@export_group("Limbs")
@export_range(4, 48, 1) var limb_count: int = 24
@export_range(3, 12, 1) var pieces_per_limb: int = 7
@export_range(1.0, 14.0, 0.1) var limb_length: float = 6.0
@export_range(0.05, 1.5, 0.01) var root_radius: float = 0.2
@export_range(0.01, 0.5, 0.005) var tip_radius: float = 0.035
@export var limb_seed: int = 17

var _player: Node4D
var _rig: Node4D
## Turned by the frame: the mouth (ring, teeth, swirl, heart) and the body (limbs).
var _mouth: Node4D
var _body: Node4D
var _toward := Vector4(0, 0, 1, 0)
var _segment: ArrayTetraMesh4D
var _tooth: ArrayTetraMesh4D
var _heart: MeshInstance4D
var _heart_material: TetraMaterial4D
var _light: OmniLight4D
var _streaks: Array = []
var _streak_materials: Array[TetraMaterial4D] = []
var _limbs: Array = []
var _dirs: Array[Vector4] = []
var _sides: Array = []
var _starts: PackedFloat32Array = []
var _lengths: PackedFloat32Array = []
var _radii: PackedFloat32Array = []
var _t := 0.0
## 0 calm, 1 warning; eased toward what is wanted.
var _heat := 0.0
var _talk_mood := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_rig = get_node_or_null(camera_rig_path) as Node4D
	_mouth = Node4D.new()
	_mouth.name = "Mouth"
	add_child(_mouth)
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	_make_meshes()
	_build_mouth()
	_build_vortex()
	_build_limbs()
	_light = OmniLight4D.new()
	_light.name = "Glow"
	_light.omni_range_meters = 14.0
	_mouth.add_child(_light)
	_light.position = Vector4(0, 0, 0.6, 0)


## The two shapes everything is made of, along y from 0 to 1: a segment of tube narrowing
## by the ratio a limb narrows per segment, with rounded ends, and a cone for the teeth.
func _make_meshes() -> void:
	var shrink: float = pow(tip_radius / root_radius, 1.0 / float(pieces_per_limb))
	_segment = LoftBuilder.build([
		{"center": Vector4(0, -0.18, 0, 0), "radius": 0.62, "w_scale": 1.0},
		{"center": Vector4(0, 0.0, 0, 0), "radius": 1.0, "w_scale": 1.0},
		{"center": Vector4(0, 1.0, 0, 0), "radius": shrink, "w_scale": 1.0},
		{"center": Vector4(0, 1.18, 0, 0), "radius": shrink * 0.62, "w_scale": 1.0},
	], 3, 8, true, false, true, 1, false)
	_tooth = LoftBuilder.build([
		{"center": Vector4(0, -0.05, 0, 0), "radius": 0.7, "w_scale": 1.0},
		{"center": Vector4(0, 0.0, 0, 0), "radius": 1.0, "w_scale": 1.0},
		{"center": Vector4(0, 0.55, 0, 0), "radius": 0.5, "w_scale": 1.0},
		{"center": Vector4(0, 1.0, 0, 0), "radius": 0.05, "w_scale": 1.0},
	], 2, 6, true, false, true, 1, false)


func _piece(parent: Node4D, name_: String, mesh: Mesh4D, material: TetraMaterial4D) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = name_
	m.mesh = mesh
	m.material_override = material
	parent.add_child(m)
	return m


## The ring and its teeth, in the mouth's own frame: x across, y up, z toward you, w
## through your slice. They never move within it, so they are placed once.
func _build_mouth() -> void:
	var lip := TetraMaterial4D.new()
	lip.albedo_color = METAL
	var teeth := TetraMaterial4D.new()
	teeth.albedo_color = METAL_PALE
	for i in lip_segments:
		var a0: float = TAU * float(i) / float(lip_segments)
		var a1: float = TAU * float(i + 1) / float(lip_segments)
		var p0 := Vector4(cos(a0), sin(a0), 0, 0) * mouth_radius
		var p1 := Vector4(cos(a1), sin(a1), 0, 0) * mouth_radius
		var ring: MeshInstance4D = _piece(_mouth, "Lip%d" % i, _segment, lip)
		ring.position = p0
		ring.basis = _segment_basis(p1 - p0, lip_radius)
	# Two rows, pointing in and a little back into the throat; the inner row shorter and set
	# between the outer's.
	for row in 2:
		var count: int = outer_teeth if row == 0 else inner_teeth
		for i in count:
			var a: float = TAU * (float(i) + 0.5 * float(row)) / float(maxi(count, 1))
			var radial := Vector4(cos(a), sin(a), 0, 0)
			var root: Vector4 = radial * (mouth_radius - lip_radius * 0.4 - 0.35 * float(row)) + Vector4(0, 0, 0.12 - 0.25 * float(row), 0)
			var length: float = 0.8 if row == 0 else 0.5
			var aim: Vector4 = (-radial * 0.85 + Vector4(0, 0, -0.45, 0)).normalized()
			var tooth: MeshInstance4D = _piece(_mouth, "Tooth%d_%d" % [row, i], _tooth, teeth)
			tooth.position = root
			tooth.basis = _segment_basis(aim * length, 0.13 if row == 0 else 0.09)
	var throat := TetraMaterial4D.new()
	throat.albedo_color = THROAT
	# A dark ring behind the teeth, so the mouth reads as a hole and not a hoop.
	for i in lip_segments:
		var a0: float = TAU * float(i) / float(lip_segments)
		var a1: float = TAU * float(i + 1) / float(lip_segments)
		var r: float = mouth_radius * 0.8
		var p0 := Vector4(cos(a0) * r, sin(a0) * r, -0.5, 0)
		var p1 := Vector4(cos(a1) * r, sin(a1) * r, -0.5, 0)
		var back: MeshInstance4D = _piece(_mouth, "Throat%d" % i, _segment, throat)
		back.position = p0
		back.basis = _segment_basis(p1 - p0, lip_radius * 1.4)
	_heart_material = TetraMaterial4D.new()
	_heart = MeshInstance4D.new()
	_heart.name = "Heart"
	var heart_mesh := OrthoplexTetraMesh4D.new()
	heart_mesh.size = Vector4.ONE * 0.9
	_heart.mesh = heart_mesh
	_heart.material_override = _heart_material
	_mouth.add_child(_heart)
	_heart.position = Vector4(0, 0, -0.9, 0)


func _build_vortex() -> void:
	for j in streaks_per_arm:
		_streak_materials.append(TetraMaterial4D.new())
	for arm in vortex_arms:
		for j in streaks_per_arm:
			_streaks.append([_piece(_mouth, "Swirl%d_%d" % [arm, j], _segment, _streak_materials[j]), arm, j])


## The limbs leave from behind the ring, trailing away from you and out round it, most of
## them hanging, and through W as well: most nearly level with your slice and carried
## through it by their curl, every fourth set off along W itself.
func _build_limbs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = limb_seed
	var ratio: float = 0.86
	var first: float = limb_length * (1.0 - ratio) / (1.0 - pow(ratio, pieces_per_limb))
	var shrink: float = pow(tip_radius / root_radius, 1.0 / float(pieces_per_limb))
	var along := 0.0
	for k in pieces_per_limb:
		_starts.append(along)
		_lengths.append(first * pow(ratio, k))
		_radii.append(root_radius * pow(shrink, k))
		along += _lengths[k]
	var shades: Array[TetraMaterial4D] = []
	for k in pieces_per_limb:
		var s: float = float(k) / float(pieces_per_limb - 1)
		var material := TetraMaterial4D.new()
		material.albedo_color = METAL.lerp(METAL_PALE, s * s)
		shades.append(material)
	for i in limb_count:
		var round_: float = TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(limb_count)
		var through: float = rng.randf_range(-0.2, 0.2)
		if i % 4 == 3:
			through = rng.randf_range(0.6, 0.9) * (1.0 if i % 8 == 3 else -1.0)
		var out := Vector4(cos(round_), sin(round_) * 0.8 - rng.randf_range(0.2, 0.7), 0, 0)
		var d: Vector4 = (out * 0.8 + Vector4(0, 0, -rng.randf_range(0.5, 0.9), through)).normalized()
		_dirs.append(d)
		var a: Vector4 = _square_to(d, Vector4(0, 1, 0, 0))
		var b: Vector4 = _square_to(d, Vector4(0, 0, 0, 1) if absf(d.w) < 0.9 else Vector4(1, 0, 0, 0), a)
		_sides.append([a, b, out.normalized() * mouth_radius * 0.9])
		var pieces: Array = []
		for k in pieces_per_limb:
			pieces.append(_piece(_body, "Limb%d_%d" % [i, k], _segment, shades[k]))
		_limbs.append(pieces)


## [param v] with the parts along [param d] (and [param e]) taken out, unit length.
static func _square_to(d: Vector4, v: Vector4, e: Vector4 = Vector4.ZERO) -> Vector4:
	var out: Vector4 = v - d * v.dot(d)
	if e != Vector4.ZERO:
		out -= e * out.dot(e)
	if out.length() < 0.001:
		out = _square_to(d, Vector4(1, 0, 0, 0) if absf(d.x) < 0.9 else Vector4(0, 0, 1, 0), e)
	return out.normalized()


## "warn" or "calm", from the conversation.
func set_mood(mood: String) -> void:
	_talk_mood = 1.0 if mood == "warn" else 0.0


## Whether it is showing red now - for the tests.
func is_warning() -> bool:
	return _heat > 0.5


func _process(delta: float) -> void:
	_t += delta
	var close := false
	if _player != null and _player.is_inside_tree():
		var gap: Vector4 = _player.global_position - global_position
		gap.y = 0.0
		close = gap.length() < too_close
	_heat = move_toward(_heat, maxf(_talk_mood, 1.0 if close else 0.0), delta * 2.5)
	var agitation: float = 1.0 + 1.6 * _heat
	var centre := Vector4(0, core_height + 0.25 * sin(_t * 0.9), 0, 0)
	var frame: Projection = _facing(delta, centre)
	_mouth.position = centre
	_mouth.basis = frame
	_body.position = centre
	_body.basis = frame

	var shimmer: float = 0.5 + 0.5 * sin(_t * (2.3 + 3.0 * _heat))
	var colour: Color = CALM_A.lerp(CALM_B, shimmer).lerp(WARN_A.lerp(WARN_B, shimmer), _heat)
	_heart_material.albedo_color = colour.lerp(Color.WHITE, 0.45 + 0.25 * shimmer)
	_heart.basis = Basis4D.from_zw(-_t * 1.7) * Basis4D.from_xy(_t * 1.1)
	for j in _streak_materials.size():
		var inward: float = float(j) / float(maxi(_streak_materials.size() - 1, 1))
		_streak_materials[j].albedo_color = colour.darkened(0.4 * (1.0 - inward)).lerp(Color.WHITE, 0.3 * inward * inward)
	_light.light_color = colour
	_light.light_energy = 4.5 + 2.0 * shimmer + 2.0 * _heat
	_place_vortex(agitation)
	_place_limbs(agitation)


## The mouth's frame, turned a little further toward you every frame: z toward your head, y
## as near up as that allows, w your slice's own normal, x across - and right-handed.
func _facing(delta: float, centre: Vector4) -> Projection:
	var normal := Vector4(0, 0, 0, 1)
	if _rig != null and _rig.is_inside_tree():
		normal = (global_basis.inverse() * _rig.global_basis.w).normalized()
	if _player != null and _player.is_inside_tree():
		var head: Vector4 = _player.global_position + Vector4(0, 1.4, 0, 0)
		var want: Vector4 = global_basis.inverse() * (head - (global_position + global_basis * centre))
		want -= normal * want.dot(normal)
		if want.length() > 0.01:
			_toward = _toward.lerp(want.normalized(), clampf(delta * turn_rate, 0.0, 1.0)).normalized()
	var z: Vector4 = _square_to(normal, _toward)
	var y: Vector4 = _square_to(z, Vector4(0, 1, 0, 0), normal)
	var x: Vector4 = Vector4.ZERO
	for e in [Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(0, 1, 0, 0)]:
		var v: Vector4 = e - z * e.dot(z) - y * e.dot(y) - normal * e.dot(normal)
		if v.length() > 0.3:
			x = v.normalized()
			break
	var frame := Projection(x, y, z, normal)
	if frame.determinant() < 0.0:
		frame.x = -frame.x
	return frame


## The swirl, inside the ring and only there: each arm a spiral from the teeth's tips in to
## the middle, turning faster toward it, and sinking back into the throat as it goes.
func _place_vortex(agitation: float) -> void:
	var rim: float = mouth_radius * vortex_fill
	for entry in _streaks:
		var piece: MeshInstance4D = entry[0]
		var arm: int = entry[1]
		var j: int = entry[2]
		var inward: float = float(j) / float(maxi(streaks_per_arm - 1, 1))
		var r: float = lerpf(rim, 0.2, inward)
		var angle: float = TAU * float(arm) / float(vortex_arms) + inward * 3.0 + _t * agitation * (0.8 + 1.4 / maxf(r, 0.2))
		var radial := Vector4(cos(angle), sin(angle), 0, 0)
		var tangent := Vector4(-sin(angle), cos(angle), 0, 0)
		var here: Vector4 = radial * r + Vector4(0, 0, -0.2 - 0.6 * inward * inward, 0)
		var along: Vector4 = (tangent - radial * 0.35).normalized()
		var length: float = lerpf(0.55, 0.2, inward)
		piece.position = here - along * length * 0.5
		piece.basis = _segment_basis(along * length, lerpf(0.07, 0.04, inward))


## The limbs, each a path out from behind the ring that curls in its own two directions, the
## curl growing along it - the root nearly still, the tip free - and each segment spanning
## from the path at its start to the path at its end.
func _place_limbs(agitation: float) -> void:
	for i in _limbs.size():
		var pieces: Array = _limbs[i]
		var d: Vector4 = _dirs[i]
		var a: Vector4 = _sides[i][0]
		var b: Vector4 = _sides[i][1]
		var root: Vector4 = _sides[i][2] + Vector4(0, 0, -0.4, 0)
		var phase: float = float(i) * 2.39
		var from: Vector4 = _limb_point(root, d, a, b, phase, 0.0, agitation)
		for k in pieces.size():
			var to: Vector4 = _limb_point(root, d, a, b, phase, _starts[k] + _lengths[k], agitation)
			var piece: MeshInstance4D = pieces[k]
			piece.position = from
			piece.basis = _segment_basis(to - from, _radii[k])
			from = to


func _limb_point(root: Vector4, d: Vector4, a: Vector4, b: Vector4, phase: float, along: float, agitation: float) -> Vector4:
	var s: float = along / limb_length
	var curl: float = s * s * (2.2 + 0.8 * _heat)
	var wave: float = _t * 0.9 * agitation + phase - s * 3.6
	var at: Vector4 = root + d * along
	at += a * (sin(wave) * curl) + b * (cos(wave * 0.83 + 0.6) * curl)
	return at


## A piece's y along [param span], its three other axes square to it and [param radius]
## long - the one nearest w (the slice's normal, in the frame) [member w_thickness] times
## that - and right-handed: a mirrored one would be drawn inside out.
func _segment_basis(span: Vector4, radius: float) -> Projection:
	var t: Vector4 = span.normalized()
	var across: Array[Vector4] = []
	for e in [Vector4(0, 0, 0, 1), Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0)]:
		var v: Vector4 = e - t * e.dot(t)
		for u in across:
			v -= u * v.dot(u)
		if v.length() > 0.3:
			across.append(v.normalized())
		if across.size() == 3:
			break
	var thick: float = lerpf(1.0, w_thickness, absf(across[0].w))
	var basis := Projection(across[0] * radius * thick, span, across[1] * radius, across[2] * radius)
	if basis.determinant() < 0.0:
		basis.w = -basis.w
	return basis
