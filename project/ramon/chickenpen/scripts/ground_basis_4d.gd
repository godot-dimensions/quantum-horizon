class_name GroundBasis4D
extends RefCounted
## The horizontal part of a 4D camera frame, and what the cameras in this folder do with it.
##
## A 3D camera is yaw and pitch. In 4D the pitch stays one angle, but the yaw grows into a
## whole rotation of the horizontal (x, z, w) space: turning left and right and tilting the
## slice through W are the same kind of thing, and they compose. So that rotation is held as
## one basis - the "ground basis", as the editor camera calls it (EditorCamera4D) - with the
## pitch applied after it: `ground * Basis4D.from_yz(pitch)`. Nothing here is a camera; these
## are the operations on that basis, so the orbit rig and the lookout's camera cannot drift
## apart in what a drag means.
##
## A ground basis has y = (0, 1, 0, 0), and every turn here is a right-multiply by a rotation
## of the xzw space, which leaves y alone. Because the turns are local, the w column - the
## normal of the slice you see - is changed only by the slice drags: a turn in place is
## `ground * from_zx(a)`, whose w column is ground.w untouched, so looking round never re-cuts
## the world.

const UP := Vector4(0.0, 1.0, 0.0, 0.0)
const ANA := Vector4(0.0, 0.0, 0.0, 1.0)


## A mouse drag with the slice not held: turn in place. Rightwards motion turns the view right.
static func looked(ground: Projection, drag: Vector2) -> Projection:
	return turned(ground, -drag.x)


## A mouse drag with the slice held: tilt the slice through W, in the frame's own axes.
## Sideways motion tilts the slice normal towards what you see as sideways (the xw plane),
## vertical motion towards what you see as ahead (the zw plane) - the editor camera's mapping.
static func sliced(ground: Projection, drag: Vector2) -> Projection:
	return ground * Basis4D.from_xw(-drag.x) * Basis4D.from_zw(drag.y)


## Turned in place by [param angle], positive to the left (from_zx's sign).
static func turned(ground: Projection, angle: float) -> Projection:
	return ground * Basis4D.from_zx(angle)


## Turned in place so the forward points along [param direction], as seen on this frame's own
## floor: the direction's components off that floor - its height, and its W, which is the part
## you walk - are dropped. [param fraction] of the way, for easing. This asks nothing of the
## heading, so it is exact however the slice is tilted.
static func faced(ground: Projection, direction: Vector4, fraction: float = 1.0) -> Projection:
	var rel: Vector4 = Basis4D.transposed(ground) * direction
	var flat := Vector2(rel.x, rel.z)
	if flat.length_squared() < 1e-12:
		return ground
	return turned(ground, atan2(-flat.x, -flat.y) * fraction)


## The heading: the yaw of the level frame nearest this one - the angle maximising the
## overlap tr(from_zx(angle)ᵀ · ground), which the frame's floor block gives in closed form.
##
## NOT THE COMPASS DIRECTION OF THE FORWARD, though the two agree whenever the frame is level
## or the slice is tilted in one plane alone. The difference is that this one is exactly
## additive under a turn in place - from_zx commutes with itself - so turned_to lands where
## it is asked to and the trip home has a fixed destination, where the forward's floor
## direction wanders under local turns once the slice is tilted in both planes.
static func heading(ground: Projection) -> float:
	var s: float = ground.z.x - ground.x.z
	var c: float = ground.x.x + ground.z.z
	if s * s + c * c < 1e-12:
		return 0.0
	return atan2(s, c)


## The same frame turned in place to a heading of [param yaw]; the slice is left alone.
static func turned_to(ground: Projection, yaw: float) -> Projection:
	return turned(ground, yaw - heading(ground))


## How far the slice normal is tilted away from the world's W axis, in radians.
static func tilt(ground: Projection) -> float:
	return acos(clampf(ground.w.dot(ANA), -1.0, 1.0))


## The level frame nearest this one: the slice flat to the world, with the least turn to get
## there.
static func flattened(ground: Projection) -> Projection:
	return Basis4D.from_zx(heading(ground))


## [param step] of the way from this frame to its flattened one, along the shortest rotation.
## The nearest level frame is the same from every point of that path, so calling this with
## the running frame each tick walks one geodesic rather than chasing a moving target.
##
## Done with Godot's 3D Quaternion on the xzw block rather than Basis4D.slerp_rotation: that
## goes through Rotor4D.from_basis, which reads large compound rotations wrongly (measured:
## slerp_rotation(g, t, 0) came back 0.77 rad off g), so the trip home would veer.
static func eased_flat(ground: Projection, step: float) -> Projection:
	var to_flat: Quaternion = _to_3d(Basis4D.transposed(ground) * flattened(ground)).get_rotation_quaternion()
	return ground * _from_3d(Basis(Quaternion.IDENTITY.slerp(to_flat, step)))


## [param ground] turned toward [param target], another level frame, by at most [param max_angle]
## radians along the one rotation that takes it there. Two level frames differ by a rotation of
## the floor's (x, z, w), so, as in eased_flat, this is a quaternion slerp on that block.
## (The player's turning through W: block_walker_character_4d.gd _turn_avatar.)
static func rotated_toward(ground: Projection, target: Projection, max_angle: float) -> Projection:
	var rel: Quaternion = _to_3d(Basis4D.transposed(ground) * target).get_rotation_quaternion()
	if rel.w < 0.0:
		rel = -rel
	var angle: float = 2.0 * acos(clampf(rel.w, -1.0, 1.0))
	if angle <= max_angle:
		return target
	return ground * _from_3d(Basis(Quaternion.IDENTITY.slerp(rel, max_angle / angle)))


## The xzw block of a level frame as a 3D basis (x, z, w -> X, Y, Z), and back. A level frame
## is a rotation of the xzw space, which is three-dimensional.
static func _to_3d(level: Projection) -> Basis:
	return Basis(
		Vector3(level.x.x, level.x.z, level.x.w),
		Vector3(level.z.x, level.z.z, level.z.w),
		Vector3(level.w.x, level.w.z, level.w.w))


static func _from_3d(b: Basis) -> Projection:
	return Projection(
		Vector4(b.x.x, 0.0, b.x.y, b.x.z),
		UP,
		Vector4(b.y.x, 0.0, b.y.y, b.y.z),
		Vector4(b.z.x, 0.0, b.z.y, b.z.z))


## Drift control: exactly level again, and orthonormal.
static func cleaned(ground: Projection) -> Projection:
	var g: Projection = ground
	g.x.y = 0.0
	g.z.y = 0.0
	g.w.y = 0.0
	g.y = UP
	return Basis4D.orthonormalized(g)
