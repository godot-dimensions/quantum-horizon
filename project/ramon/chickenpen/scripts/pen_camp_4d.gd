@tool
extends Node4D

## The researchers' camp, 2.5 m kata in the meadow's middle: easter egg 1, where the first bag of
## azoth is (6 Oct 2026, Ramon, of the ring of standing stones that was here: "what is this? i find
## a bag of zoth here, but its just some pillars?", and for what to put instead: "researchers camp is
## a good idea, tents, bonfire, and simple kicthen scaffold", "bonfire is center").
##
## A PLACE THAT EXPLAINS THE BAG. Somebody camped here, off the farm's slice, and left in a hurry:
## the fire still burning, the kettle on the scaffold, a crate by the tents with the bag of azoth
## beside it ("Found: a bag of azoth, 2 pieces. Somebody hid this."), and a surveyor's tripod, which
## is what the cave's researchers carry.
##
## THE BONFIRE IS THE MIDDLE. Two tents and the kitchen scaffold face it from the north and east,
## two log benches sit round it, the crate and the tripod to the west. From the farm's slice there is
## nothing here but the meadow's sand ring; step 2.5 kata inside it and the camp is there. Everything
## is a little deep in W and no more (the tents 1.6 m, the scaffold 0.9 m, the stones less), so it
## comes and goes as you step, the shallow things first.
##
## Merged into one mesh per colour (as the watchtower is); the flames are three boxes of their own
## that flicker, with a warm light over them. Physics is boxes that do not turn: one per tent, the
## scaffold, the crate, the fire's ring and each bench.
##
## NO class_name (engine_gotchas.md).

@export var stone_seed: int = 23: set = _set_seed
## The fire's light: its colour, reach and how bright it is at most.
@export var fire_colour: Color = Color(1.0, 0.58, 0.28)
@export_range(1.0, 15.0, 0.5, "suffix:m") var fire_reach: float = 7.0
@export_range(0.0, 6.0, 0.05) var fire_energy: float = 1.6

const OWN := &"_camp_part"
const CANVAS := Color(0.70, 0.64, 0.50)
const CANVAS_DARK := Color(0.55, 0.49, 0.37)
const ORANGE := Color(0.80, 0.40, 0.16)
const ORANGE_DARK := Color(0.62, 0.29, 0.12)
const TIMBER := Color(0.45, 0.33, 0.22)
const TIMBER_DARK := Color(0.30, 0.21, 0.14)
const CHAR := Color(0.16, 0.12, 0.10)
const STONE := Color(0.42, 0.41, 0.39)
const STONE_LIGHT := Color(0.52, 0.51, 0.48)
const IRON := Color(0.24, 0.24, 0.25)
const BRASS := Color(0.62, 0.50, 0.28)
const EMBER := Color(0.62, 0.16, 0.05)

var _pending: bool = false
var _flames: Array[MeshInstance4D] = []
var _light: OmniLight4D
var _clock: float = 0.0


func _set_seed(v: int) -> void:
	stone_seed = v
	_later()


func _ready() -> void:
	rebuild()


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
	_flames.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var b: Dictionary = {}
	var body := StaticBody4D.new()
	body.name = "Solid"
	_own(body)
	_bonfire(b, body, rng)
	_tent(b, body, Vector2(-0.6, -3.4), 1.6, CANVAS, CANVAS_DARK, Vector3(2.4, 1.6, 2.0))
	_tent(b, body, Vector2(-3.4, -0.6), 1.4, ORANGE, ORANGE_DARK, Vector3(2.0, 1.3, 1.7))
	_kitchen(b, body, Vector2(3.0, -0.4))
	# Two log benches round the fire, to the south-west and south-east.
	for at in [Vector2(-1.5, 1.7), Vector2(1.6, 1.6)]:
		var t: float = atan2(at.y, at.x) + PI * 0.5
		_add(b, TIMBER, Vector4(1.5, 0.3, 0.32, 0.55), Vector4(at.x, 0.17, at.y, rng.randf_range(-0.1, 0.1)), _turn_y(t))
		_add(b, TIMBER_DARK, Vector4(0.04, 0.28, 0.3, 0.5), Vector4(at.x, 0.17, at.y, 0.0) + _turn_y(t) * Vector4(0.76, 0.0, 0.0, 0.0), _turn_y(t))
		_solid(body, Vector4(1.3, 0.34, 1.3, 0.55), Vector4(at.x, 0.17, at.y, 0.0))
	# The crate the bag was left by, a smaller one on it, and a lantern.
	_add(b, TIMBER, Vector4(0.62, 0.55, 0.62, 0.7), Vector4(-2.4, 0.275, 1.6, 0.0), _turn_y(0.3))
	_add(b, TIMBER_DARK, Vector4(0.64, 0.07, 0.64, 0.72), Vector4(-2.4, 0.4, 1.6, 0.0), _turn_y(0.3))
	_add(b, TIMBER, Vector4(0.42, 0.32, 0.36, 0.5), Vector4(-2.45, 0.71, 1.62, 0.05), _turn_y(-0.2))
	_add(b, IRON, Vector4(0.14, 0.24, 0.14, 0.16), Vector4(-2.3, 0.99, 1.55, 0.0))
	_add(b, Color(0.95, 0.80, 0.45), Vector4(0.08, 0.12, 0.08, 0.1), Vector4(-2.3, 0.99, 1.55, 0.0))
	_solid(body, Vector4(0.8, 0.9, 0.8, 0.7), Vector4(-2.4, 0.45, 1.6, 0.0))
	# A surveyor's tripod, the cave researchers' kind, with its instrument on top.
	var foot := Vector4(-2.6, 0.0, -2.9, 0.0)
	var top: Vector4 = foot + Vector4(0.0, 1.35, 0.0, 0.0)
	for k in 3:
		var a: float = TAU * float(k) / 3.0 + 0.4
		_strut(b, TIMBER_DARK, foot + Vector4(cos(a) * 0.45, 0.0, sin(a) * 0.45, sin(a) * 0.12), top, 0.04, 0.08)
	_add(b, BRASS, Vector4(0.22, 0.16, 0.16, 0.16), top + Vector4(0.0, 0.1, 0.0, 0.0))
	_add(b, BRASS, Vector4(0.05, 0.05, 0.3, 0.06), top + Vector4(0.0, 0.2, 0.0, 0.0))
	for colour in b:
		var node := MeshInstance4D.new()
		node.name = "Camp_" + String(colour)
		node.mesh = b[colour]
		var m := TetraMaterial4D.new()
		m.albedo_color = Color.html(colour)
		node.material_override = m
		_own(node)
	_light = OmniLight4D.new()
	_light.name = "FireLight"
	_light.omni_range_meters = fire_reach
	_light.light_color = fire_colour
	_light.light_energy = fire_energy
	_light.position = Vector4(0.0, 1.1, 0.0, 0.0)
	_own(_light)


## The bonfire, the camp's middle: a ring of stones, embers, a teepee of logs burning down, and the
## flames, three boxes turned about the up axis that flicker (see _process).
func _bonfire(b: Dictionary, body: StaticBody4D, rng: RandomNumberGenerator) -> void:
	var stones: int = 10
	for k in stones:
		var a: float = TAU * float(k) / float(stones) + rng.randf_range(-0.1, 0.1)
		var r: float = 0.78 + rng.randf_range(-0.05, 0.05)
		var s := Vector4(rng.randf_range(0.26, 0.36), rng.randf_range(0.16, 0.24), rng.randf_range(0.22, 0.3), rng.randf_range(0.3, 0.6))
		_add(b, STONE if k % 3 != 0 else STONE_LIGHT, s, Vector4(cos(a) * r, s.y * 0.5, sin(a) * r, rng.randf_range(-0.12, 0.12)), _turn_y(-a))
	_add(b, CHAR, Vector4(1.25, 0.05, 1.25, 0.7), Vector4(0.0, 0.025, 0.0, 0.0))
	_add(b, EMBER, Vector4(0.7, 0.08, 0.7, 0.45), Vector4(0.0, 0.06, 0.0, 0.0), _turn_y(0.6))
	var apex := Vector4(0.0, 0.95, 0.0, 0.0)
	for k in 5:
		var a: float = TAU * float(k) / 5.0 + 0.3
		_strut(b, CHAR if k % 2 == 0 else TIMBER_DARK, Vector4(cos(a) * 0.5, 0.05, sin(a) * 0.5, sin(a * 2.0) * 0.15), apex, 0.09, 0.2)
	for k in 3:
		var f := MeshInstance4D.new()
		f.name = "Flame%d" % k
		var box := BoxTetraMesh4D.new()
		box.size = [Vector4(0.36, 0.75, 0.36, 0.3), Vector4(0.26, 1.0, 0.26, 0.22), Vector4(0.16, 0.6, 0.16, 0.14)][k]
		f.mesh = box
		var m := TetraMaterial4D.new()
		m.albedo_color = [Color(1.0, 0.45, 0.10), Color(1.0, 0.66, 0.20), Color(1.0, 0.90, 0.55)][k]
		f.material_override = m
		f.position = Vector4(0.0, box.size.y * 0.5 + 0.08, 0.0, 0.0)
		f.basis = _turn_y(0.6 * float(k) + 0.4)
		f.set_meta(&"rest", f.position)
		_own(f)
		_flames.append(f)
	_solid(body, Vector4(1.9, 0.4, 1.9, 0.8), Vector4(0.0, 0.2, 0.0, 0.0))


## A ridge tent at [param at] (x, z), its door toward the fire: [param dims] is its length along the
## ridge, its height and its width; [param wd] how deep it is in W. Two sloping sheets, the back
## gable closed, the door's flaps pulled aside, a ridge pole, the poles at its ends and a ground sheet.
func _tent(b: Dictionary, body: StaticBody4D, at: Vector2, wd: float, canvas: Color, dark: Color, dims: Vector3) -> void:
	var length: float = dims.x
	var h: float = dims.y
	var half_w: float = dims.z * 0.5
	# The door (the frame's +x end) toward the fire, at the origin.
	var turn: float = atan2(at.y, -at.x)
	var rot: Projection = _turn_y(turn)
	var o := Vector4(at.x, 0.0, at.y, 0.0)
	var slope: float = atan2(h, half_w)
	var sheet: float = sqrt(h * h + half_w * half_w)
	# Each sheet from the ridge down to its eave: lying flat (thin in y, its width along z), then
	# turned about the ridge's line by the roof's slope, one side each way.
	for side in [-1.0, 1.0]:
		var c := Vector4(0.0, h * 0.5, side * half_w * 0.5, 0.0)
		_add(b, canvas, Vector4(length, 0.05, sheet + 0.06, wd), o + rot * c, rot * _turn_x(side * slope))
	# The back gable: a stack of strips narrowing to the ridge (a triangle in boxes).
	var steps: int = 6
	for k in steps:
		var y0: float = h * float(k) / float(steps)
		var y1: float = h * float(k + 1) / float(steps)
		var wide: float = 2.0 * half_w * (1.0 - (float(k) + 0.5) / float(steps))
		_add(b, dark, Vector4(0.04, y1 - y0 + 0.01, wide, wd - 0.04), o + rot * Vector4(-length * 0.5 + 0.02, (y0 + y1) * 0.5, 0.0, 0.0), rot)
	# The door's two flaps, pulled aside and tied: a narrow strip each side of the opening.
	for side in [-1.0, 1.0]:
		_add(b, dark, Vector4(0.06, h * 0.75, half_w * 0.45, wd - 0.1), o + rot * Vector4(length * 0.5 - 0.05, h * 0.38, side * half_w * 0.62, 0.0), rot)
	_add(b, TIMBER_DARK, Vector4(length + 0.2, 0.06, 0.06, 0.08), o + rot * Vector4(0.0, h + 0.02, 0.0, 0.0), rot)
	for end in [-1.0, 1.0]:
		_add(b, TIMBER_DARK, Vector4(0.05, h + 0.1, 0.05, 0.08), o + rot * Vector4(end * length * 0.5, (h + 0.1) * 0.5, 0.0, 0.0), rot)
		# A guy rope from the pole's top to a peg out along the ridge.
		var from: Vector4 = o + rot * Vector4(end * length * 0.5, h, 0.0, 0.0)
		var peg: Vector4 = o + rot * Vector4(end * (length * 0.5 + 0.9), 0.0, 0.0, 0.0)
		_strut(b, Color(0.70, 0.66, 0.56), from, peg, 0.02, 0.04)
	_add(b, Color(0.22, 0.24, 0.20), Vector4(length + 0.1, 0.03, half_w * 2.0 + 0.2, wd + 0.1), o + rot * Vector4(0.0, 0.015, 0.0, 0.0), rot)
	_solid(body, Vector4(maxf(length, half_w * 2.0), h, maxf(length, half_w * 2.0), wd), o + Vector4(0.0, h * 0.5, 0.0, 0.0))


## The kitchen: a timber scaffold facing the fire, four posts and a frame, a worktop and a shelf,
## pots and a kettle, a rail over it with things hanging, and a water barrel at its end.
func _kitchen(b: Dictionary, body: StaticBody4D, at: Vector2) -> void:
	var turn: float = atan2(at.y, -at.x) + PI * 0.5
	var rot: Projection = _turn_y(turn)
	var o := Vector4(at.x, 0.0, at.y, 0.0)
	var l: float = 2.0
	var d: float = 0.7
	var tall: float = 1.9
	var wd: float = 0.9
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add(b, TIMBER_DARK, Vector4(0.08, tall, 0.08, 0.1), o + rot * Vector4(sx * l * 0.5, tall * 0.5, sz * d * 0.5, 0.0), rot)
	for sz in [-1.0, 1.0]:
		_add(b, TIMBER, Vector4(l + 0.1, 0.07, 0.07, 0.1), o + rot * Vector4(0.0, tall - 0.04, sz * d * 0.5, 0.0), rot)
	for sx in [-1.0, 1.0]:
		_add(b, TIMBER, Vector4(0.07, 0.07, d, 0.1), o + rot * Vector4(sx * l * 0.5, tall - 0.04, 0.0, 0.0), rot)
	_add(b, TIMBER, Vector4(l, 0.05, d, wd), o + rot * Vector4(0.0, 0.88, 0.0, 0.0), rot)
	_add(b, TIMBER_DARK, Vector4(l, 0.04, d - 0.1, wd - 0.1), o + rot * Vector4(0.0, 0.32, 0.0, 0.0), rot)
	# On the worktop: two pots and a kettle; on the shelf below: sacks and a box.
	_add(b, IRON, Vector4(0.3, 0.24, 0.3, 0.3), o + rot * Vector4(-0.55, 1.02, 0.05, 0.0), rot)
	_add(b, IRON, Vector4(0.24, 0.18, 0.24, 0.24), o + rot * Vector4(-0.15, 0.99, -0.1, 0.0), rot)
	_add(b, Color(0.35, 0.36, 0.36), Vector4(0.22, 0.2, 0.18, 0.2), o + rot * Vector4(0.45, 1.0, 0.05, 0.0), rot)
	_add(b, Color(0.35, 0.36, 0.36), Vector4(0.03, 0.12, 0.12, 0.04), o + rot * Vector4(0.58, 1.05, 0.05, 0.0), rot)
	_add(b, Color(0.72, 0.66, 0.52), Vector4(0.4, 0.3, 0.35, 0.4), o + rot * Vector4(-0.5, 0.49, 0.0, 0.0), rot)
	_add(b, Color(0.66, 0.60, 0.47), Vector4(0.35, 0.26, 0.32, 0.36), o + rot * Vector4(-0.05, 0.47, 0.05, 0.0), rot)
	_add(b, TIMBER, Vector4(0.4, 0.22, 0.35, 0.4), o + rot * Vector4(0.5, 0.45, 0.0, 0.0), rot)
	# The rail's hanging things: a ladle, a pan and a lantern.
	for k in 3:
		var x: float = -0.6 + 0.6 * float(k)
		_add(b, IRON, Vector4(0.02, 0.3, 0.02, 0.03), o + rot * Vector4(x, tall - 0.22, d * 0.5, 0.0), rot)
		_add(b, [IRON, IRON, BRASS][k], [Vector4(0.08, 0.06, 0.08, 0.08), Vector4(0.26, 0.04, 0.26, 0.2), Vector4(0.12, 0.16, 0.12, 0.12)][k],
			o + rot * Vector4(x, tall - 0.4, d * 0.5, 0.0), rot)
	_add(b, TIMBER_DARK, Vector4(0.5, 0.7, 0.5, 0.5), o + rot * Vector4(l * 0.5 + 0.45, 0.35, 0.0, 0.0), rot)
	_add(b, IRON, Vector4(0.52, 0.04, 0.52, 0.52), o + rot * Vector4(l * 0.5 + 0.45, 0.55, 0.0, 0.0), rot)
	_solid(body, Vector4(l + 0.9, tall, l + 0.9, wd), o + Vector4(0.0, tall * 0.5, 0.0, 0.0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _flames.is_empty():
		return
	_clock += delta
	# Each flame breathes on its own beat, and the light with them.
	for k in _flames.size():
		var f: MeshInstance4D = _flames[k]
		if not is_instance_valid(f):
			continue
		var beat: float = 0.5 + 0.5 * sin(_clock * (7.0 + 2.3 * float(k)) + float(k) * 1.7) * sin(_clock * (2.9 + 0.7 * float(k)))
		var s: float = 0.8 + 0.35 * beat
		f.scale = Vector4(1.0, s, 1.0, 1.0)
		var rest: Vector4 = f.get_meta(&"rest")
		f.position = Vector4(rest.x, (rest.y - 0.08) * s + 0.08, rest.z, rest.w)
	if _light != null:
		_light.light_energy = fire_energy * (0.8 + 0.2 * sin(_clock * 9.0) * sin(_clock * 3.7 + 1.0))


## A box of [param size] at [param at], turned by [param basis], into this colour's merged mesh.
func _add(b: Dictionary, colour: Color, size: Vector4, at: Vector4, basis: Projection = Projection.IDENTITY) -> void:
	var key: String = colour.to_html(false)
	if not b.has(key):
		b[key] = ArrayTetraMesh4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = size
	(b[key] as ArrayTetraMesh4D).merge_with(box.to_array_tetra_mesh(), at, basis)


## A bar of square section [param thick] from [param a] to [param c], [param wd] deep in W.
func _strut(b: Dictionary, colour: Color, a: Vector4, c: Vector4, thick: float, wd: float) -> void:
	var d: Vector4 = c - a
	var length: float = d.length()
	if length < 0.001:
		return
	_add(b, colour, Vector4(thick, length, thick, wd), (a + c) * 0.5, _frame_along(d / length))


## An orthonormal frame whose y is [param y] (lookout_tower_4d.gd's own).
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


## A turn about the up axis by [param t]: x toward -z.
static func _turn_y(t: float) -> Projection:
	return Projection(Vector4(cos(t), 0.0, -sin(t), 0.0), Vector4(0.0, 1.0, 0.0, 0.0), Vector4(sin(t), 0.0, cos(t), 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


## A turn about the x axis by [param t]: y toward z.
static func _turn_x(t: float) -> Projection:
	return Projection(Vector4(1.0, 0.0, 0.0, 0.0), Vector4(0.0, cos(t), sin(t), 0.0), Vector4(0.0, -sin(t), cos(t), 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


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
