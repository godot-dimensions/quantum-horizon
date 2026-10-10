extends RefCounted

## SLICE SENSE (discovery, 9 Oct 2026): where something is against the player's slice, measured along the
## slice's own normal, so it stays right when the slice is turned. The Tutor's raw-W test (|p.w - player.w|) is
## only right while the slice is flat (chicken_pen_learnings.md: "Off-slice checks must use the camera's slice
## normal, not raw w").
##
## The slice is the camera's: every point p with (p - eye) . n = 0, n the camera's fourth axis (its basis w). The
## camp's align (scripts/pen_research_camp_4d.gd _slice_w_at) uses the same plane.
##
## NO class_name (engine_gotchas.md): preloaded by what uses it.


## How far [param p] is off the slice of [param cam], along the slice's normal: 0 in the slice, positive ana of it.
static func off_slice(cam: Camera4D, p: Vector4) -> float:
	if cam == null:
		return INF
	var n: Vector4 = cam.global_basis.w.normalized()
	return (p - cam.global_position).dot(n)


## The W at which the slice of [param cam] crosses the ground point (x, y, z): where to hang a tag so that it is in
## your slice. INF when the slice runs along W there (a quarter turn).
static func slice_w_at(cam: Camera4D, x: float, y: float, z: float) -> float:
	if cam == null:
		return INF
	var n: Vector4 = cam.global_basis.w.normalized()
	if absf(n.w) < 1e-3:
		return INF
	var e: Vector4 = cam.global_position
	return e.w - (n.x * (x - e.x) + n.y * (y - e.y) + n.z * (z - e.z)) / n.w


## How much of something round, [param radius] deep along the normal, a slice [param d] off its middle shows: the
## share of its widest cut that remains (1 cut through the middle, 0 missed). The Aquatic Lab's shark measure.
static func share(d: float, radius: float) -> float:
	if radius <= 0.0:
		return 1.0 if absf(d) < 1e-3 else 0.0
	var t: float = d / radius
	return sqrt(maxf(1.0 - t * t, 0.0))


## How far the slice is turned from flat, in radians (0 flat): the angle between its normal and W.
static func tilt(cam: Camera4D) -> float:
	if cam == null:
		return 0.0
	var n: Vector4 = cam.global_basis.w.normalized()
	return acos(clampf(absf(n.w), 0.0, 1.0))


## The player's camera, by the pen's path.
static func camera_of(player: Node) -> Camera4D:
	return player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D if player != null else null
