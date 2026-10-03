@tool
extends RefCounted

## Small 4D helpers the kit shares. NO class_name (engine_gotchas.md): preload this file.


## An orthonormal basis whose +Z column is `z_axis` (4D has no two-vector cross product, so the
## standard axes least parallel to it are Gram-Schmidted into place). Lights shine along their
## local -Z, so pointing +Z at the light's source makes it shine from there.
static func basis_with_z(z_axis: Vector4) -> Projection:
	var forward: Vector4 = z_axis.normalized()
	var candidates: Array[Vector4] = [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]
	candidates.sort_custom(func(a: Vector4, b: Vector4) -> bool: return absf(a.dot(forward)) < absf(b.dot(forward)))
	var axes: Array[Vector4] = []
	for c in candidates:
		var v: Vector4 = c - forward * c.dot(forward)
		for e in axes:
			v -= e * v.dot(e)
		if v.length() > 0.001:
			axes.append(v.normalized())
		if axes.size() == 3:
			break
	var p := Projection.IDENTITY
	p.x = axes[0]
	p.y = axes[1]
	p.w = axes[2]
	p.z = forward
	# Keep a right-handed basis (determinant +1), so nothing mirrors.
	if p.determinant() < 0.0:
		p.x = -p.x
	return p


## The direction from the scene toward a light at `elevation` above the horizon and `azimuth`
## round from +Z towards +X, in degrees, tilted `ana` degrees out of the slice.
static func sun_direction(elevation: float, azimuth: float, ana: float = 0.0) -> Vector4:
	var e: float = deg_to_rad(elevation)
	var a: float = deg_to_rad(azimuth)
	var t: float = deg_to_rad(ana)
	var flat: float = cos(e)
	var d3 := Vector3(sin(a) * flat, sin(e), cos(a) * flat)
	return Vector4(d3.x * cos(t), d3.y * cos(t), d3.z * cos(t), sin(t))


## Smoothstep from 0 to 1.
static func ease01(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
