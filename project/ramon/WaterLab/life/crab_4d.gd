extends Node4D

## WATER LAB: the crab (Ramon, 9 Oct: "if you could add a walking crab that would be cool, one that
## appears in different areas of W"). An edible crab a third of a metre across, drawn by
## life/crab.gdshader through a slice herd (its legs step on the GPU), walked here over the sand of the
## water's own frame (life/: x along the tank, y up, z to the glass, W).
##
## IT WALKS THROUGH W. The tank's floor is a 3D floor (x, z AND W), and the crab wanders all of it: by
## turns it walks onto your slice at some spot along the tank, stops there and picks at the sand with
## its claws, then walks off through W and is cut smaller and gone, to come back somewhere else. Its
## body keeps facing the glass-ish way it faced; it walks sideways, as crabs do, its legs stepping
## whether the step carries it along the tank or through W.
##
## NO class_name (engine_gotchas.md).

const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const SHADER := preload("res://ramon/WaterLab/life/crab.gdshader")

@export var size: float = 0.34
@export var speed: float = 0.16
var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
var obstacles: Array = []
var ground: Node = null

var herd: Node4D
var cpu_us: float = 0.0
var _p := Vector4.ZERO
var _yaw: float = 0.0
var _target := Vector4.ZERO
var _on_slice_next: bool = true
var _walking: bool = true
var _pause: float = 0.0
var _phase: float = 0.0
var _walk: float = 0.0
var _reach: float = 0.0
var _pinch: float = 0.0
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0


func _ready() -> void:
	_rng.seed = 7731
	herd = Node4D.new()
	herd.name = "CrabHerd"
	herd.set_script(Herd)
	herd.set("mesh", build_mesh())
	herd.set("shader", SHADER)
	herd.set("w_radius", 0.6)
	herd.set("count", 1)
	add_child(herd)
	_p = Vector4(_rng.randf_range(-6.0, 6.0), floor_y, _rng.randf_range(0.3, 1.1), 1.6)
	_pick_target()


func _pick_target() -> void:
	var x: float = _rng.randf_range(-half_extents.x + 0.8, half_extents.x - 0.8)
	var z: float = _rng.randf_range(0.1, half_extents.z - 0.35)
	var w: float = 0.0
	if _on_slice_next:
		w = _rng.randf_range(-0.03, 0.03)
	else:
		w = (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(0.9, minf(2.4, half_extents.w - 0.4))
		# Off through W it also moves along the tank, so it comes back somewhere new.
		x = clampf(_p.x + _rng.randf_range(-5.0, 5.0), -half_extents.x + 0.8, half_extents.x - 0.8)
	_target = Vector4(x, floor_y, z, w)
	_on_slice_next = not _on_slice_next


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var dt: float = minf(delta, 0.05)
	_t += dt
	if _walking:
		var to: Vector4 = _target - _p
		to.y = 0.0
		if to.length() < 0.05:
			_walking = false
			# A long stop on your slice, a short one off it.
			_pause = _rng.randf_range(6.0, 11.0) if absf(_p.w) < 0.1 else _rng.randf_range(1.0, 3.0)
		else:
			var step: Vector4 = to.normalized() * minf(speed * dt, to.length())
			_p += step
			# Turn the body so its walk along the floor is sideways (crabs face away from their way).
			var flat := Vector2(to.x, to.z)
			if flat.length() > 0.05:
				var want: float = atan2(flat.x, flat.y) + PI * 0.5
				if absf(wrapf(want - _yaw, -PI, PI)) > PI * 0.5:
					want += PI
				_yaw = lerp_angle(_yaw, want, 1.0 - exp(-0.8 * dt))
			_walk = lerpf(_walk, 1.0, 1.0 - exp(-5.0 * dt))
			_phase += TAU * 2.2 * dt
	else:
		_walk = lerpf(_walk, 0.0, 1.0 - exp(-4.0 * dt))
		_pause -= dt
		if _pause <= 0.0:
			_walking = true
			_pick_target()
	_p.y = float(ground.call("height_at", _p.x, _p.z, _p.w)) if ground != null else floor_y
	# Stopped, the claws pick at the sand and come back to the mouth.
	var picking: bool = not _walking
	_reach = lerpf(_reach, (0.5 + 0.5 * sin(_t * 2.4)) if picking else 0.0, 1.0 - exp(-4.0 * dt))
	_pinch = 0.5 + 0.5 * sin(_t * 5.0) if picking else lerpf(_pinch, 0.0, dt * 3.0)
	_draw()
	cpu_us = lerpf(cpu_us, float(Time.get_ticks_usec() - t0), 0.05)


func _draw() -> void:
	var h := Vector4(sin(_yaw), 0.0, cos(_yaw), 0.0)
	var right := Vector4(cos(_yaw), 0.0, -sin(_yaw), 0.0)
	herd.call("write", 0, _p, h, right, Color(_pinch, 0.0, 0.0, 1.0), Vector4(_phase, _walk, size, _reach))
	herd.call("upload")


## On your (level) slice now, and where (for the panels).
func on_slice() -> bool:
	return absf(_p.w) < 0.6 * size


func bench_row() -> Array:
	return ["Crab", "1", "%.3f ms" % (cpu_us / 1000.0), "1", "legs step on the GPU"]


# -- its shape ------------------------------------------------------------------------------------------------

static func build_mesh() -> ArrayMesh:
	var m := CrabMesh.new()
	# The carapace: an ellipsoid, fuller above than below, raised on its legs.
	m.ellipsoid(Vector3(0.0, 0.18, 0.0), Vector3(0.5, 0.15, 0.38), Vector3(0.5, 0.06, 0.38), 0, 0.0, 0.0, Vector3.ZERO, Vector3.ZERO, 22, 12)
	for side in [-1.0, 1.0]:
		# Eyes.
		m.ellipsoid(Vector3(side * 0.1, 0.31, 0.35), Vector3(0.035, 0.035, 0.035), Vector3(0.035, 0.035, 0.035), 1, 0.0, side, Vector3.ZERO, Vector3.ZERO, 8, 6)
		# The legs: a thigh up and out from the hip, a shank down to the sand.
		for i in 4:
			var hip := Vector3(side * 0.42, 0.16, 0.14 - 0.13 * float(i))
			var knee: Vector3 = hip + Vector3(side * 0.30, 0.12, -0.05 * float(i) + 0.03)
			var foot: Vector3 = knee + Vector3(side * 0.16, -0.30, -0.05 * float(i))
			m.tube(hip, knee, 0.045, 0.035, 4, float(i), side, hip, knee)
			m.tube(knee, foot, 0.032, 0.01, 5, float(i), side, hip, knee)
		# The claw: the arm forward from the shoulder, the hand across the face, the finger.
		var shoulder := Vector3(side * 0.30, 0.14, 0.30)
		var wrist := Vector3(side * 0.42, 0.13, 0.52)
		var hinge := Vector3(side * 0.16, 0.13, 0.64)
		m.tube(shoulder, wrist, 0.055, 0.05, 2, 0.0, side, shoulder, hinge)
		m.ellipsoid(Vector3(side * 0.27, 0.11, 0.61), Vector3(0.15, 0.075, 0.09), Vector3(0.15, 0.075, 0.09), 2, 0.0, side, shoulder, hinge, 12, 8)
		m.tube(hinge, Vector3(side * 0.03, 0.115, 0.67), 0.028, 0.008, 3, 0.0, side, shoulder, hinge)
	return m.commit()


## The crab's mesh in the making: each part carries its hip (CUSTOM0) and knee (CUSTOM1).
class CrabMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var idx := PackedInt32Array()

	func _v(p: Vector3, n: Vector3, part: int, slot: float, side: float, hip: Vector3, knee: Vector3) -> int:
		verts.append(p)
		normals.append(n.normalized())
		uvs.append(Vector2(slot, float(part)))
		uv2s.append(Vector2(side, 0.0))
		c0.append_array([hip.x, hip.y, hip.z, 0.0])
		c1.append_array([knee.x, knee.y, knee.z, 0.0])
		return verts.size() - 1

	func _grid(rows: Array) -> void:
		for i in rows.size() - 1:
			var a: Array = rows[i]
			var b: Array = rows[i + 1]
			for j in a.size() - 1:
				idx.append_array([a[j], a[j + 1], b[j + 1], a[j], b[j + 1], b[j]])

	## An ellipsoid with different half heights above (`up`) and below (`down`).
	func ellipsoid(c: Vector3, up: Vector3, down: Vector3, part: int, slot: float, side: float, hip: Vector3, knee: Vector3, lon: int, lat: int) -> void:
		var rows: Array = []
		for i in lat + 1:
			var th: float = PI * float(i) / float(lat)
			var row: Array = []
			for j in lon + 1:
				var ph: float = TAU * float(j) / float(lon)
				var d := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				var e: Vector3 = up if d.y >= 0.0 else down
				var p: Vector3 = c + Vector3(d.x * e.x, d.y * e.y, d.z * e.z)
				var n := Vector3(d.x / e.x, d.y / e.y, d.z / e.z)
				row.append(_v(p, n, part, slot, side, hip, knee))
			rows.append(row)
		_grid(rows)

	## A tapering tube from `a` to `b`, closed at its far end.
	func tube(a: Vector3, b: Vector3, r0: float, r1: float, part: int, slot: float, side: float, hip: Vector3, knee: Vector3) -> void:
		var axis: Vector3 = (b - a).normalized()
		var u: Vector3 = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var w: Vector3 = axis.cross(u)
		var rows: Array = []
		var sides: int = 6
		for i in 4:
			var t: float = float(i) / 3.0
			var r: float = lerpf(r0, r1, t)
			var row: Array = []
			for j in sides + 1:
				var ph: float = TAU * float(j) / float(sides)
				var d: Vector3 = u * cos(ph) + w * sin(ph)
				row.append(_v(a.lerp(b, t) + d * r, d, part, slot, side, hip, knee))
			rows.append(row)
		var tip: int = _v(b + axis * r1, axis, part, slot, side, hip, knee)
		_grid(rows)
		var last: Array = rows[rows.size() - 1]
		for j in sides:
			idx.append_array([last[j], last[j + 1], tip])

	func commit() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		var col := PackedColorArray()
		col.resize(verts.size())
		col.fill(Color.WHITE)
		arrays[Mesh.ARRAY_COLOR] = col
		arrays[Mesh.ARRAY_CUSTOM0] = c0
		arrays[Mesh.ARRAY_CUSTOM1] = c1
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		var fmt: int = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
		mesh.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
		return mesh
