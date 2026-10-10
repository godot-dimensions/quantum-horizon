@tool
extends Node4D

## BALLOONS IN THE SKY (10 Oct 2026, Ramon's walkthrough feedback item 21; follow_up/pen_feedback_10oct.md). They
## replace the 9 Oct airships: "The current Zeppelin in the sky doesn't look convincing. It appears too blocky and
## pivots awkwardly around a central point ... Replace the Zeppelin with another instance of the existing hot-air
## balloon ... a simple, gentle flight path that moves through the sky", and asked how many: "one plus 3 is fine. but
## keep the budget low on these. and all in earthy desat colors please".
##
## One in the farm's slice and three [member ana_w] ana, far out to the right of the Watchstone (as the airships were):
## the W idea stays (step or turn the slice and more of them come). The envelope is the boardable balloon's teardrop
## (lookout/balloon_4d.gd _build_envelope's profile), lofted ONCE as one plain mesh through the pen's loft builder and
## shared by all four; each balloon is that and one more mesh for its basket and ropes, in its own muted colour: eight
## mesh instances in all, kept out of the projection (far and spread through W, their ghosts would cover the sky).
##
## THEY DRIFT, they never turn: a balloon goes where the wind takes it. Each wanders a slow loop ([member drift] metres
## along x and z, a few minutes round) and bobs, its own phase.
##
## Built when it loads (and in the editor, to place them), never saved into the scene. Move this node to move them.
## NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/chickenpen/scripts/loft_builder_4d.gd")

## The boardable balloon's teardrop: [height above the mouth, radius] (lookout/balloon_4d.gd).
const PROFILE := [[0.0, 0.55], [0.8, 1.5], [1.8, 2.5], [3.0, 3.2], [4.4, 3.55], [5.8, 3.5], [7.0, 3.0], [7.9, 2.1], [8.4, 1.0], [8.56, 0.3]]

## Each: [position (offsets from this node), envelope colour, drift phase].
@export var balloons: Array = [
	[Vector4(24.0, 56.0, -150.0, 0.0), Color(0.69, 0.58, 0.40), 0.0],
	[Vector4(-6.0, 52.0, -160.0, 9.0), Color(0.55, 0.60, 0.49), 1.9],
	[Vector4(16.0, 63.0, -172.0, 9.0), Color(0.64, 0.46, 0.38), 3.7],
	[Vector4(42.0, 55.0, -154.0, 9.0), Color(0.52, 0.55, 0.57), 5.2],
]:
	set(v):
		balloons = v
		_later()
## How much bigger than the boardable one (far away, a real-sized balloon is a speck).
@export_range(0.5, 4.0, 0.05) var size: float = 1.7
@export var basket_colour: Color = Color(0.33, 0.25, 0.17)
@export var rope_colour: Color = Color(0.45, 0.40, 0.33)
## How far each wanders along x and z, and how long a loop takes.
@export var drift: Vector2 = Vector2(18.0, 9.0)
@export_range(30.0, 900.0, 5.0, "suffix:s") var loop_seconds: float = 240.0

var _nodes: Array[Node4D] = []
var _t: float = 0.0
static var _envelope: Mesh4D


func _later() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			remove_child(n)
			n.free()
	_nodes.clear()
	var envelope: Mesh4D = _envelope_mesh()
	var basket: ArrayTetraMesh4D = _basket_mesh()
	for i in balloons.size():
		var spec: Array = balloons[i]
		var b := Node4D.new()
		b.name = "SkyBalloon%d" % i
		add_child(b)
		b.position = spec[0]
		b.basis = Basis4D.from_scale_uniform(size)
		_mesh(b, "Envelope", envelope, spec[1], Vector4(0.0, 3.0, 0.0, 0.0))
		_mesh(b, "Basket", basket, basket_colour, Vector4.ZERO)
		_nodes.append(b)


## The teardrop, lofted once for every balloon here (static: shared across rebuilds too).
static func _envelope_mesh() -> Mesh4D:
	if _envelope != null:
		return _envelope
	var secs: Array = []
	for p in PROFILE:
		secs.append({"center": Vector4(0.0, float(p[0]), 0.0, 0.0), "radius": float(p[1]), "v_scale": 1.0, "w_scale": 1.0})
	_envelope = Loft.build(secs, 4, 12, true, false, false, 1, false)
	return _envelope


## The basket and its four ropes up to the mouth, in one mesh.
func _basket_mesh() -> ArrayTetraMesh4D:
	var m := ArrayTetraMesh4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = Vector4(1.3, 1.05, 1.3, 1.3)
	m.merge_with(box.to_array_tetra_mesh(), Vector4(0.0, 0.525, 0.0, 0.0), Projection.IDENTITY)
	for k in 4:
		var a: float = PI * 0.25 + float(k) * PI * 0.5
		var low := Vector4(cos(a) * 0.6, 1.05, sin(a) * 0.6, 0.0)
		var high := Vector4(cos(a) * 0.5, 3.0, sin(a) * 0.5, 0.0)
		var rope := BoxTetraMesh4D.new()
		rope.size = Vector4(0.06, (high - low).length(), 0.06, 0.4)
		m.merge_with(rope.to_array_tetra_mesh(), (low + high) * 0.5, Projection.IDENTITY)
	return m


func _mesh(parent: Node4D, part: String, mesh: Mesh4D, colour: Color, at: Vector4) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	node.mesh = mesh
	var mat := TetraMaterial4D.new()
	mat.albedo_color = colour
	node.material_override = mat
	node.set("allow_projection", false)
	parent.add_child(node)
	node.position = at


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var w: float = TAU / maxf(loop_seconds, 1.0)
	for i in mini(_nodes.size(), balloons.size()):
		var spec: Array = balloons[i]
		var ph: float = float(spec[2])
		# A slow loop (x and z out of step, so it wanders rather than circles) and a bob; no turning, ever.
		var off := Vector4(sin(_t * w + ph) * drift.x, sin(_t * 0.23 + ph) * 0.8, sin(_t * w * 0.71 + ph * 1.3) * drift.y, 0.0)
		_nodes[i].position = (spec[0] as Vector4) + off
