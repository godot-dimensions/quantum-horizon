extends Node4D
## Crosswise: short-lived effects, each freeing itself.
##
##   chips   small cubes of stone flung out and falling, shrinking away: a strike's chips, a rock's
##           shatter, a crate's dust when it lands somewhere it should not have gone
##   ring    a flat glowing disc that grows and pales into the floor: an arrival, a crate going
##           home (the renderer is opaque, so "fading" is going pale toward the white floor)
##
## Chips fly MOSTLY WITHIN THE VIEW: their directions are drawn in the slice's own X, Y and depth
## axes, with only a little W, so you see them (a chip thrown straight along W leaves your slice at
## once and looks like nothing happened). After the QuantumRange's range_fx_4d.gd burst, rebuilt so
## it takes the view and lit materials.
##
## NO class_name (engine_gotchas.md): preload it and call chips() / ring().

const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")
const SELF := "res://ramon/MiegakureLook/Remake/world/mk_fx_4d.gd"

var _kind: String = ""
var _age: float = 0.0
var _life: float = 0.6
var _parts: Array = []
var _size: float = 0.1
var _ring: MeshInstance4D
var _ring_mat: TetraMaterial4D
var _ring_r: float = 1.0
var _ring_color: Color = Color.WHITE


## `view` is the slice's rotation (the camera's slice_rotation()).
static func chips(parent: Node, at: Vector4, color: Color, view: Projection, count: int = 10, size: float = 0.12, speed: float = 3.2, life: float = 0.8) -> Node4D:
	var fx := Node4D.new()
	fx.set_script(load(SELF))
	parent.add_child(fx)
	fx.call("_make_chips", at, color, view, count, size, speed, life)
	return fx


static func ring(parent: Node, at: Vector4, color: Color, radius: float = 1.2, depth_w: float = 0.6, life: float = 0.7) -> Node4D:
	var fx := Node4D.new()
	fx.set_script(load(SELF))
	parent.add_child(fx)
	fx.call("_make_ring", at, color, radius, depth_w, life)
	return fx


func _make_chips(at: Vector4, color: Color, view: Projection, count: int, size: float, speed: float, life: float) -> void:
	_kind = "chips"
	_life = life
	_size = size
	global_position = at
	var mesh := Mats.box_mesh(Vector4(size, size, size, size))
	var mat := Mats.flat(color)
	for i in count:
		var p := MeshInstance4D.new()
		p.mesh = mesh
		p.material_override = mat
		add_child(p)
		var a: float = randf() * TAU
		var up: float = randf_range(0.35, 1.0)
		var local := Vector4(cos(a), up, sin(a), randf_range(-0.15, 0.15)).normalized()
		var v: Vector4 = view * local * speed * randf_range(0.6, 1.1)
		_parts.append([p, v, randf_range(-6.0, 6.0)])


func _make_ring(at: Vector4, color: Color, radius: float, depth_w: float, life: float) -> void:
	_kind = "ring"
	_life = life
	_ring_r = radius
	global_position = at
	_ring = MeshInstance4D.new()
	var disc := CubinderShape4D.new()
	disc.radius = 1.0
	disc.height = 0.02
	disc.thickness = depth_w
	_ring.mesh = disc.to_tetra_mesh({"segments": 48})
	_ring_mat = Mats.glow(color, 1.0, 0.0, true)
	_ring_color = color
	_ring.material_override = _ring_mat
	add_child(_ring)
	_ring.position = Vector4(0, 0.015, 0, 0)
	_ring.basis = Projection(Vector4(0.3, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0.3, 0), Vector4(0, 0, 0, 1))


func _process(delta: float) -> void:
	_age += delta
	var k: float = clampf(_age / _life, 0.0, 1.0)
	if _kind == "chips":
		for part in _parts:
			var p: MeshInstance4D = part[0]
			var v: Vector4 = part[1]
			v.y -= 9.8 * delta
			part[1] = v
			p.position += v * delta
			var s: float = maxf(1.0 - k * k, 0.02)
			p.basis = Basis4D.from_zx(part[2] * _age) * Projection(Vector4(s, 0, 0, 0), Vector4(0, s, 0, 0), Vector4(0, 0, s, 0), Vector4(0, 0, 0, s))
	elif _kind == "ring" and _ring != null:
		var r: float = lerpf(0.3, _ring_r, 1.0 - pow(1.0 - k, 3.0))
		_ring.basis = Projection(Vector4(r, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, r, 0), Vector4(0, 0, 0, 1))
		_ring_mat.get_cross_section_material_3d().set_shader_parameter("glow_color", _ring_color.lerp(Color(0.97, 0.98, 0.98), k))
	if _age >= _life:
		queue_free()
