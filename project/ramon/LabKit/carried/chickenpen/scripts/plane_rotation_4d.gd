# CARRIED OVER from res://ramon/chickenpen/scripts/plane_rotation_4d.gd on 4 Oct 2026, so the lab owns this copy: the original can change without breaking the lab, and the other way round (LabKit/carried/README.md).
extends RefCounted
# COPIED INTO chickenpen SO THE SCENE OWNS EVERYTHING IT NEEDS. The original lives at
# res://ramon/LabKit/carried/Model/scripts/plane_rotation_4d.gd and is what animation_test still uses. The two are
# now separate files: a change to the pig in one scene does NOT reach the other.

## The rotation that carries one 4D direction onto another.
##
## In 3D you would name an axis and turn about it. In 4D there is no such axis - a
## rotation lives in a PLANE, and the plane spanned by the two directions is the one
## that turns them into each other while leaving everything perpendicular to it alone.
## So a rotation is stored as two orthonormal vectors spanning that plane, plus the
## sine and cosine of the angle within it.
##
## Used by every skinned limb in this folder: bind a vertex to a bone once, then each
## frame rotate it by the bone's rest-to-now rotation. Deliberately not a Projection -
## building one costs sixteen floats per bone per frame to express four.


## Works out the rotation taking `from` onto `to`. Returns [u, v, cos, sin].
##
## Degenerate cases return the identity: already aligned, exactly reversed (where the
## plane is genuinely ambiguous - any plane containing the vector would do), or either
## vector being zero length.
static func between(from: Vector4, to: Vector4) -> Array:
	var u: Vector4 = from.normalized()
	var t: Vector4 = to.normalized()
	if u.length_squared() < 0.5 or t.length_squared() < 0.5:
		return [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), 1.0, 0.0]
	var c: float = clampf(u.dot(t), -1.0, 1.0)
	var v: Vector4 = t - u * c
	if v.length() < 0.00001:
		return [u, u, 1.0, 0.0]
	return [u, v.normalized(), c, sqrt(maxf(1.0 - c * c, 0.0))]


## Turns a vector by a rotation from between(). A plain Givens rotation in the (u, v)
## plane: the components along u and v turn into each other, the rest is untouched.
static func apply(x: Vector4, r: Array) -> Vector4:
	var u: Vector4 = r[0]
	var v: Vector4 = r[1]
	var c: float = r[2]
	var s: float = r[3]
	var xu: float = u.dot(x)
	var xv: float = v.dot(x)
	return x + ((c - 1.0) * xu - s * xv) * u + (s * xu + (c - 1.0) * xv) * v
