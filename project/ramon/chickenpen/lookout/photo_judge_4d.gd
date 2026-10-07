extends Node

## Judges a photograph from the game's state at the moment of the shutter, as Pokemon Snap
## does - not from its pixels.
##
## FOR EACH SUBJECT IN FRAME it asks four things, each from numbers the game already has:
##
##   in frame   in front of the camera, its middle inside the picture
##   sharp      how much of it is in the slice: a 4D body off your slice by dw shows a
##              cross-section sqrt(1 - (dw / w_radius)^2) of its full size, and nothing at
##              all past its W radius. This is the focus ring's whole meaning, scored.
##   size       how big it looks: its radius, times that cross-section, over its distance,
##              against the frame's height
##   centred    how far its middle is from the middle of the frame
##
## and what it is doing (photo_subjects_4d.gd) - one to four stars, the rarer the more
## (New Pokemon Snap's behaviours). Two crows in one frame or two cats is a star more on
## their page; the whole set of three crows is the fourth star.
##
## IT CAN BE BLOCKED. From the cab, the picture only sees out of the window openings: a
## line to the subject that leaves the cab through a solid sill, the header, the floor or
## the roof does not count (the hide's walls are solid where a real hide's are). And the
## hills: a line that dips under the ground's height on its way is behind a hill.
##
## POINTS (Snap's three columns, simplified): size up to 1000 at a third of the frame,
## technique up to 800 for sharp and centred, pose 200 / 500 / 900 / 1500 for one to four
## stars, and 150 for every extra subject of the same page in frame, up to three. A photo
## FILLS a journal slot only if the subject is at least half sharp and big enough to make
## out (2% of the frame); otherwise the toast says why, with the W it was at.
##
## THE FLOCK is judged as a crowd: every bird read back from the GPU at the shutter (a few
## milliseconds, hidden in the mirror's blackout), counted in frame and in the slice, with
## how many are mid-roll, how wide they spread across the picture, and whether the hawk is
## in it too.

const POSE := [0, 200, 500, 900, 1500]
const MIN_SHARP := 0.5
const MIN_SIZE := 0.02

var lookout: Node
var _ground: RefCounted


func setup(owner_lookout: Node) -> void:
	lookout = owner_lookout


func set_ground(ground: RefCounted) -> void:
	_ground = ground


## The whole photograph: {best: {...} or {}, seen: [every subject in frame], flock: {...}}.
func judge(camera: Camera4D, screen: Vector2) -> Dictionary:
	var subjects: Node = lookout.get("subjects")
	var seen: Array = []
	var by_page: Dictionary = {}
	for s in subjects.call("all"):
		var p: Variant = subjects.call("point", s)
		if p == null:
			continue
		var look: Dictionary = measure(camera, screen, p as Vector4, float(s["radius"]), float(s["w_radius"]))
		if look.is_empty():
			continue
		if _blocked(camera.global_position, p as Vector4):
			continue
		var b: Array = subjects.call("behaviour", s)
		look["subject"] = s
		look["id"] = s["id"]
		look["page"] = s["page"]
		look["name"] = s["name"]
		look["stars"] = int(b[0])
		look["doing"] = String(b[1])
		seen.append(look)
		if float(look["sharp"]) >= MIN_SHARP:
			by_page[s["page"]] = int(by_page.get(s["page"], 0)) + 1
	# Groups: two of a kind is a star more, three crows is the fourth.
	for look in seen:
		var page: String = look["page"]
		var together: int = int(by_page.get(page, 0))
		look["together"] = together
		if page == "crows" and together >= 3:
			look["stars"] = 4
			look["doing"] = "All three crows"
		elif page == "cats" and together >= 2:
			look["stars"] = 4
			look["doing"] = "Both cats"
		elif page == "folk":
			var stars: int = clampi(together, 1, 3)
			if stars > int(look["stars"]):
				look["stars"] = stars
				look["doing"] = ["Farm folk", "Farm folk", "Two of them", "A crowd of three"][stars]
		if page == "hawk" and int(look["stars"]) < 4 and camera.global_position.y > (look["at"] as Vector4).y + 2.0 \
				and float(look["looking_down"]) > 0.25:
			look["stars"] = 4
			look["doing"] = "Above the hawk"
		if page == "hawk" and int(look["stars"]) < 3 and float(look["size"]) >= 0.1:
			look["stars"] = 3
			look["doing"] = "Eye to eye"
		look["points"] = points(look)
	var flock: Dictionary = judge_flock(camera, screen)
	if not flock.is_empty():
		seen.append(flock)
		if flock.has("white"):
			seen.append(flock["white"])
	var best: Dictionary = {}
	for look in seen:
		if best.is_empty() or _rank(look) > _rank(best):
			best = look
	return {"best": best, "seen": seen}


## [param point]'s look in [param camera]: {sharp, size, centred, screen, depth, w_off, at}
## or empty when it is behind, off the frame, or out of the slice altogether.
func measure(camera: Camera4D, screen: Vector2, point: Vector4, radius: float, w_radius: float) -> Dictionary:
	var basis: Projection = camera.global_basis
	var rel: Vector4 = point - camera.global_position
	var depth: float = -rel.dot(basis.z)
	if depth < 0.3:
		return {}
	var t: float = tan(vertical_fov(camera) * 0.5)
	var aspect: float = screen.x / maxf(screen.y, 1.0)
	var sx: float = rel.dot(basis.x) / (depth * t * aspect)
	var sy: float = rel.dot(basis.y) / (depth * t)
	if absf(sx) > 1.0 or absf(sy) > 1.0:
		return {}
	var w_off: float = rel.dot(basis.w)
	var ratio: float = 1.0 - (w_off / maxf(w_radius, 0.001)) * (w_off / maxf(w_radius, 0.001))
	if ratio <= 0.0:
		return {}
	var sharp: float = sqrt(ratio)
	# Diameter against the frame's height.
	var size: float = (radius * sharp) / (depth * t)
	var centred: float = 1.0 - clampf(Vector2(sx * aspect, sy).length() / 1.0, 0.0, 1.0)
	return {"sharp": sharp, "size": size, "centred": centred, "screen": Vector2(sx, sy), "depth": depth,
		"w_off": w_off, "at": point, "looking_down": basis.z.y}


func points(look: Dictionary) -> int:
	var size_pts: float = clampf(float(look["size"]) / 0.33, 0.0, 1.0) * 1000.0
	var technique: float = float(look["sharp"]) * float(look["sharp"]) * 400.0 + float(look["centred"]) * 400.0
	var pose: int = POSE[clampi(int(look.get("stars", 0)), 0, 4)]
	var extra: int = clampi(int(look.get("together", 1)) - 1, 0, 3) * 150
	return int(round(size_pts + technique)) + pose + extra


## Whether a photo of this look fills its journal slot, and if not, why.
func verdict(look: Dictionary) -> String:
	if look.is_empty():
		return "nothing"
	if float(look.get("sharp", 0.0)) < MIN_SHARP:
		return "soft"
	if float(look.get("size", 0.0)) < MIN_SIZE:
		return "small"
	return "good"


## Which subject a photo is OF, when several are in it. A secret wins whenever it is in
## the picture and good: the white starling in a photo of five thousand starlings is a
## photo of the white starling.
func _rank(look: Dictionary) -> float:
	var r: float = float(look.get("points", 0))
	# A place (the marsh) is what a photo is of only when nothing living is.
	if bool((look.get("subject", {}) as Dictionary).get("place", false)):
		r *= 0.05
	if verdict(look) != "good":
		r *= 0.25
	elif String(look.get("page", "")) in ["owl", "white_starling", "heron"]:
		r += 100000.0
	return r


# --- Blocked lines ----------------------------------------------------------------------------

func _blocked(eye: Vector4, point: Vector4) -> bool:
	return _blocked_by_cab(eye, point) or _blocked_by_ground(eye, point)


## From inside the cab, only the window band lets a line out: it leaves the cab's box
## through one of its faces, and only the side and W faces have openings, between sill and
## lintel.
func _blocked_by_cab(eye: Vector4, point: Vector4) -> bool:
	var tower: Node4D = lookout.get("tower")
	if tower == null or bool(tower.call("is_balcony")):
		return false
	var local_eye: Vector4 = eye - tower.global_position
	var local_to: Vector4 = point - tower.global_position
	var h: float = float(tower.get("deck_height"))
	var half: float = float(tower.get("cab_size")) * 0.5 - 0.06
	var w_half: float = float(tower.get("cab_w_depth")) * 0.5 - 0.06
	var top: float = h + float(tower.get("cab_height"))
	if absf(local_eye.x) > half or absf(local_eye.z) > half or absf(local_eye.w) > w_half or local_eye.y < h or local_eye.y > top:
		return false
	var d: Vector4 = local_to - local_eye
	# The first face the line reaches, going out.
	var t_out: float = INF
	var face: int = -1
	for axis in 4:
		var limit: float = [half, 0.0, half, w_half][axis]
		if axis == 1:
			continue
		var dv: float = d[axis]
		if absf(dv) < 1e-6:
			continue
		var t: float = ((limit if dv > 0.0 else -limit) - local_eye[axis]) / dv
		if t >= 0.0 and t < t_out:
			t_out = t
			face = axis
	for y_limit in [h, top]:
		if absf(d.y) > 1e-6:
			var t: float = (y_limit - local_eye.y) / d.y
			if t >= 0.0 and t < t_out:
				t_out = t
				face = 1
	if face < 0 or t_out > 1.0:
		return false
	if face == 1:
		return true
	var y: float = local_eye.y + d.y * t_out
	return y < h + float(tower.get("sill")) or y > h + float(tower.get("lintel"))


## A line that passes under the hills' surface somewhere along it.
func _blocked_by_ground(eye: Vector4, point: Vector4) -> bool:
	if _ground == null:
		return false
	for i in range(1, 16):
		var p: Vector4 = eye.lerp(point, float(i) / 16.0)
		if p.y < float(_ground.call("floor_at", p.x, p.z)) - 0.3:
			return true
	return false


# --- The flock ---------------------------------------------------------------------------------

func judge_flock(camera: Camera4D, screen: Vector2) -> Dictionary:
	var flock := lookout.get("room").get_node_or_null("World/Flock") as Node4D
	if flock == null or not flock.is_visible_in_tree() or int(flock.get("count")) == 0:
		return {}
	var started: int = Time.get_ticks_usec()
	var positions: PackedVector4Array = flock.call("positions")
	var agitation: PackedFloat32Array = flock.call("agitation")
	var basis: Projection = camera.global_basis
	var eye: Vector4 = camera.global_position
	# Into the camera's frame in one go: the flock's space to the camera's.
	var inverse: Projection = basis.inverse()
	var to_cam: Projection = inverse * flock.global_basis
	var origin: Vector4 = inverse * (flock.global_position - eye)
	var t: float = tan(vertical_fov(camera) * 0.5)
	var aspect: float = screen.x / maxf(screen.y, 1.0)
	var w_radius: float = float(flock.get("bird_w_radius"))
	var bird: float = float(flock.get("bird_scale")) * 0.2
	var n: int = 0
	var rolling: int = 0
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var near: float = INF
	var white: int = int(flock.get("white_bird")) if flock.get("white_bird") != null else -1
	var white_look: Dictionary = {}
	var middle := Vector2.ZERO
	for i in positions.size():
		var c: Vector4 = to_cam * positions[i] + origin
		if absf(c.w) > w_radius:
			continue
		var depth: float = -c.z
		if depth < 0.5:
			continue
		var sx: float = c.x / (depth * t * aspect)
		var sy: float = c.y / (depth * t)
		if absf(sx) > 1.0 or absf(sy) > 1.0:
			continue
		n += 1
		middle += Vector2(sx, sy)
		lo = Vector2(minf(lo.x, sx), minf(lo.y, sy))
		hi = Vector2(maxf(hi.x, sx), maxf(hi.y, sy))
		near = minf(near, depth)
		if i < agitation.size() and agitation[i] > 0.1:
			rolling += 1
		if i == white:
			var sharp: float = sqrt(maxf(1.0 - (c.w / w_radius) * (c.w / w_radius), 0.0))
			white_look = {"sharp": sharp, "size": bird * sharp / (depth * t), "centred": 1.0 - clampf(Vector2(sx * aspect, sy).length(), 0.0, 1.0),
				"screen": Vector2(sx, sy), "depth": depth, "w_off": c.w}
	var cost_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	if n < 25:
		return _white(white_look, n) if not white_look.is_empty() else {}
	var spread: float = (hi.x - lo.x) * 0.5
	var stars: int = 1
	var doing: String = "A flock in flight"
	var share: float = float(rolling) / float(n)
	if share >= 0.06 and n >= 60:
		stars = 2
		doing = "The turning wave"
	if n >= 1200 or (n >= 600 and spread >= 0.55):
		stars = 3
		doing = "A sky full of birds"
	var hawk: Variant = flock.call("hawk_position")
	var hawk_in: bool = false
	if hawk != null:
		var hc: Vector4 = to_cam * (hawk as Vector4) + origin
		var hd: float = -hc.z
		if hd > 0.5 and absf(hc.x / (hd * t * aspect)) < 1.0 and absf(hc.y / (hd * t)) < 1.0 and absf(hc.w) < 0.6:
			hawk_in = true
			if String(flock.call("stats").get("hawk", "")) == "diving" and n >= 150:
				stars = 4
				doing = "The hawk's hole"
	var look: Dictionary = {
		"id": "starlings", "page": "starlings", "name": "The starlings", "stars": stars, "doing": doing,
		"birds": n, "rolling": rolling, "spread": spread, "hawk_in": hawk_in, "cost_ms": cost_ms,
		# A crowd is sharp by construction (only birds in the slice were counted); its size is
		# how much of the frame it spreads over, its centre where its middle is.
		"sharp": 1.0, "size": clampf(spread * 0.6 + float(n) / 4000.0, 0.0, 1.0),
		"centred": 1.0 - clampf((middle / float(n)).length(), 0.0, 1.0), "together": 1,
	}
	look["points"] = points(look)
	if not white_look.is_empty():
		look["white"] = _white(white_look, n)
	return look


## The white starling, from its own look and the birds round it.
func _white(look: Dictionary, crowd: int) -> Dictionary:
	var stars: int = 1
	var doing: String = "One white bird"
	if float(look["sharp"]) >= 0.7 and float(look["centred"]) >= 0.85:
		stars = 2
		doing = "Picked out"
	if float(look["size"]) >= 0.05:
		stars = 3
		doing = "Close up"
	if crowd >= 400 and lookout.get("station").get("mode") == 4:
		stars = 4
		doing = "In the middle of it"
	var out: Dictionary = look.duplicate()
	out.merge({"id": "white_starling", "page": "white_starling", "name": "The white starling", "stars": stars,
		"doing": doing, "together": 1}, true)
	out["points"] = points(out)
	return out


## The vertical angle the picture is actually drawn at: the 4D field of view under the
## default PERSPECTIVE_4D projection, the 3D one under PERSPECTIVE_3D.
static func vertical_fov(camera: Camera4D) -> float:
	if int(camera.get("projection_type")) == 1:
		return float(camera.get("field_of_view_4d"))
	return float(camera.get("field_of_view_3d"))
