extends RefCounted

## The slice as two angles, for the pen's tests and capture scripts (6 Oct 2026).
##
## Until 4 Oct the orbit rig held the slice as two numbers, `_slice_xw` and `_slice_zw`: tilts in
## the world's own x-w and z-w planes, applied outside the heading, so its frame was
##     from_xw(xw) * from_zw(zw) * from_zx(yaw)
## The camera controls change (b27ffa1, "to match the usual controls") made the rig's basis hold
## heading and tilt together (GroundBasis4D) and removed the two numbers. A script that still set
## them set nothing, silently, and went on testing a flat slice: two dozen tests and captures
## did, and some of them kept passing. They were written in those angles, so rather than rewrite
## each one's situations in new terms, they build the same frame here: the same tilt of the world
## they always meant, checked the same way.
##
## A PLAYER'S DRAG IS NOT THIS. It tilts the slice in the view's own axes (GroundBasis4D.sliced,
## the rig's drag_slice), so the same drag does the same thing on screen whichever way you face.
## A test of what a drag does should drag; _verify_drag_guidance_runner.gd does.
##
## No class_name (engine_gotchas.md): preload it.

const ANA := Vector4(0.0, 0.0, 0.0, 1.0)


## Tilt [param rig]'s slice to [param xw] and [param zw], keeping its heading, or turning it to
## [param yaw] when one is given. Give it whenever the old script set the yaw and both tilts
## together: with both planes tilted, the rig's own yaw property reads the heading a little
## differently from the old angle (GroundBasis4D.heading explains).
static func tilt(rig: Node, xw: float, zw: float, yaw: float = NAN) -> void:
	var node := rig as Node4D
	if node == null:
		return
	if is_nan(yaw):
		yaw = angles(node.basis).z
	node.basis = frame(xw, zw, yaw)
	if node.has_method("_apply"):
		node.call("_apply")


## The rig frame the old angles made.
static func frame(xw: float, zw: float, yaw: float) -> Projection:
	return Basis4D.from_xw(xw) * Basis4D.from_zw(zw) * Basis4D.from_zx(yaw)


## The old angles of a rig frame, (xw, zw, yaw): the inverse of frame(). The slice's normal gives
## the two tilts (the heading never moves it), and what is left once they are taken off is the
## heading. Rebuilding a frame from its own angles gives the frame back, so a script that sets
## the same tilt every frame never drifts.
static func angles(f: Projection) -> Vector3:
	var n: Vector4 = f.w
	# The signs of the two tilts, read off Basis4D rather than assumed.
	var kx: float = signf((Basis4D.from_xw(0.5) * ANA).x)
	var kz: float = signf((Basis4D.from_zw(0.5) * ANA).z)
	var zw: float = asin(clampf(n.z * kz, -1.0, 1.0))
	var xw: float = atan2(n.x * kx, n.w)
	var level: Projection = Basis4D.transposed(Basis4D.from_xw(xw) * Basis4D.from_zw(zw)) * f
	return Vector3(xw, zw, GroundBasis4D.heading(level))
