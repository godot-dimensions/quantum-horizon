extends Node4D

## The Voxel Lab: chips thrown off a cut. Small 4D boxes in the colours the cut went through, flung
## out of the surface and a little through W (so a few stay in your slice and a few leave it), falling,
## spinning and shrinking away in under a second; then this node frees itself.
##
## Every chip shares one box mesh and one material per colour: drawable after the first burst, so a
## burst costs nothing to show.
##
## spawn(parent, at, normal, colors, count, size, speed) -> the node.
##
## NO class_name (engine_gotchas.md).

const LIFE := 0.85
const GRAVITY := 9.0

static var _mesh: BoxTetraMesh4D
static var _mats: Dictionary = {}

var _chips: Array = []
var _t: float = 0.0


static func spawn(parent: Node, at: Vector4, normal: Vector4, colors: Array, count: int = 14, size: float = 0.06, speed: float = 2.6) -> Node4D:
	var node := Node4D.new()
	node.name = "Chips"
	node.set_script(load("res://ramon/VoxelLab/room/vl_chips_4d.gd"))
	parent.add_child(node)
	node.global_position = at
	node.call("_fill", normal, colors, count, size, speed)
	return node


func _fill(normal: Vector4, colors: Array, count: int, size: float, speed: float) -> void:
	if _mesh == null:
		_mesh = BoxTetraMesh4D.new()
		_mesh.size = Vector4.ONE
	var n: Vector4 = normal.normalized() if normal.length() > 0.0 else Vector4(0, 1, 0, 0)
	for i in count:
		var c: Color = colors[i % maxi(colors.size(), 1)] if not colors.is_empty() else Color(0.6, 0.6, 0.6)
		var mi := MeshInstance4D.new()
		mi.mesh = _mesh
		mi.material_override = _mat(c)
		var s: float = size * randf_range(0.55, 1.25)
		mi.scale = Vector4(s, s * randf_range(0.6, 1.0), s, s)
		add_child(mi)
		var spread := Vector4(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1), randf_range(-0.6, 0.6))
		var v: Vector4 = (n * 1.1 + spread * 0.75).normalized() * speed * randf_range(0.55, 1.15)
		var spin := Vector2(randf_range(-9, 9), randf_range(-9, 9))
		_chips.append([mi, v, spin, s])


static func _mat(c: Color) -> TetraMaterial4D:
	var key: String = c.to_html()
	if not _mats.has(key):
		var m := TetraMaterial4D.new()
		m.albedo_color = c
		_mats[key] = m
	return _mats[key]


func _process(delta: float) -> void:
	_t += delta
	var k: float = clampf(1.0 - _t / LIFE, 0.0, 1.0)
	for ch in _chips:
		var mi: MeshInstance4D = ch[0]
		var v: Vector4 = ch[1]
		v.y -= GRAVITY * delta
		ch[1] = v
		mi.position += v * delta
		var spin: Vector2 = ch[2]
		mi.basis = Basis4D.from_xy(spin.x * _t) * Basis4D.from_yz(spin.y * _t)
		var s: float = float(ch[3]) * (0.25 + 0.75 * k)
		mi.scale = Vector4(s, s, s, s)
	if _t > LIFE:
		queue_free()
