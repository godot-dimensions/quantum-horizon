extends Node4D

## Short-lived effects: the shot's beam, and the burst where it lands. Each frees itself.
##
##   beam   a thin 4D box along the shot, lying in your slice (built in the camera's own frame, so
##          it is never tilted out of what you see: a 1D wire along the ray is coplanar with the slice
##          and does not draw at all, ShootingGalleryRamon/scripts/ray_beam_ramon.gd), thicker and
##          longer-lived for a charged shot, shrinking away
##   burst  small cubes flung out in random 4D directions in the colour of what was hit (red pop for a
##          core, amber sparks off armour, white chips off cover, grey sparks off a shell that will
##          not break, green for a friendly), shrinking away
##
## NO class_name (engine_gotchas.md): preload it and call beam() / burst().

const Mats := preload("res://ramon/QuantumRange/scripts/range_mats.gd")

var _kind: String = ""
var _age: float = 0.0
var _life: float = 0.3
var _parts: Array = []
var _mesh: MeshInstance4D
var _mat: TetraMaterial4D
var _thick: float = 0.04


static func beam(parent: Node, from: Vector4, to: Vector4, camera_basis: Projection, charged: bool, color: Color) -> Node4D:
	var fx := Node4D.new()
	fx.set_script(load("res://ramon/QuantumRange/scripts/range_fx_4d.gd"))
	parent.add_child(fx)
	fx.call("_make_beam", from, to, camera_basis, charged, color)
	return fx


static func burst(parent: Node, at: Vector4, color: Color, count: int = 10, size: float = 0.08, speed: float = 4.0) -> Node4D:
	var fx := Node4D.new()
	fx.set_script(load("res://ramon/QuantumRange/scripts/range_fx_4d.gd"))
	parent.add_child(fx)
	fx.call("_make_burst", at, color, count, size, speed)
	return fx


func _make_beam(from: Vector4, to: Vector4, cam: Projection, charged: bool, color: Color) -> void:
	_kind = "beam"
	_life = 0.32 if charged else 0.12
	_thick = 0.11 if charged else 0.03
	var d: Vector4 = to - from
	var length: float = d.length()
	if length < 0.01:
		queue_free()
		return
	# The beam's direction in the camera's own x, y, z (it lies in your slice: the muzzle is offset only
	# within it), turned into a 3D frame with z along it, then lifted back to 4D with the camera's W.
	var local := Vector3(d.dot(cam.x), d.dot(cam.y), d.dot(cam.z)).normalized()
	var b3 := Basis.looking_at(-local, Vector3.UP if absf(local.y) < 0.99 else Vector3.RIGHT)
	var b := Projection(
		cam.x * b3.x.x + cam.y * b3.x.y + cam.z * b3.x.z,
		cam.x * b3.y.x + cam.y * b3.y.y + cam.z * b3.y.z,
		cam.x * b3.z.x + cam.y * b3.z.y + cam.z * b3.z.z,
		cam.w)
	_mesh = MeshInstance4D.new()
	_mesh.mesh = Mats.box(Vector4(1.0, 1.0, 1.0, 1.0))
	_mat = Mats.glow(color)
	_mesh.material_override = _mat
	add_child(_mesh)
	global_position = (from + to) * 0.5
	global_basis = b
	_mesh.basis = Projection(Vector4(_thick, 0, 0, 0), Vector4(0, _thick, 0, 0), Vector4(0, 0, length, 0), Vector4(0, 0, 0, _thick * 2.0))


func _make_burst(at: Vector4, color: Color, count: int, size: float, speed: float) -> void:
	_kind = "burst"
	_life = 0.45
	global_position = at
	var mesh: Mesh4D = Mats.box(Vector4(size, size, size, size))
	_mat = Mats.glow(color)
	for i in count:
		var p := MeshInstance4D.new()
		p.mesh = mesh
		p.material_override = _mat
		add_child(p)
		var dir := Vector4(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1) * 0.6).normalized()
		_parts.append([p, dir * speed * randf_range(0.6, 1.2)])


func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / _life, 0.0, 1.0)
	if _kind == "beam" and is_instance_valid(_mesh):
		var k: float = 1.0 - t
		var b: Projection = _mesh.basis
		_mesh.basis = Projection(b.x.normalized() * _thick * k, b.y.normalized() * _thick * k, b.z, b.w.normalized() * _thick * 2.0 * k)
	elif _kind == "burst":
		var s: float = 1.0 - t
		for e in _parts:
			var p: MeshInstance4D = e[0]
			p.position += (e[1] as Vector4) * delta
			e[1] = (e[1] as Vector4) * exp(-3.0 * delta) + Vector4(0, -6.0 * delta, 0, 0)
			p.basis = Basis4D.from_scale_uniform(maxf(s, 0.001))
	if _age >= _life:
		queue_free()
