extends Control

## The locator: the range's own copy of the slice radar that works (Trym's slice_radar.gd and Ramon's
## fork ShootingGalleryRamon/scripts/slice_radar_ramon.gd; Ramon, 5 Oct: "The pinpoint/locator HUD is
## working well"), with the one thing it got wrong put right: it shows EVERY target, not just the
## yellow cube, the ducks and the monolith (the white and grey blockers and the green spheres were never
## on it; follow_up/quantum_range_final.md section 1).
##
## HOW TO READ IT (as the original): the ellipse is your own slice, seen from above and tilted; you are
## the dot in its middle. A target's grey dot is where it stands in your slice (the rings are distance:
## 6 m is halfway out, the rim is infinity); the stem from that dot is how far it is through W, up for
## ana (E takes you there), down for kata (Q). A target in your slice has no stem.
##
## ONE CHANGE TO THE STEM: it shows the W offset on its own scale, the same at any distance (1.5 m of W
## is half its full height), not shrunk with the distance as the original's was. A core 1.2 m ana and
## 13 m away got an 8-pixel stem under its own marker (weapon/07_far_off_slice.png, 5 Oct); W is what
## you have to match, so it is what must read.
## The marker at the stem's end is the target's role in the range's colour and shape language:
##
##   core     red dot              (a dark red ring when it is still locked)
##   armour   amber square
##   cover    white diamond        (only the parts that matter: a cluster's satellites)
##   friend   green cross
##   w        cyan ring            (a ring gate)
##
## The part the HUD thinks you are going for (range_hud.gd current()) is circled in white.
##
## Pure 2D drawing from 4D positions: no camera, nothing rendered in 4D for it.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")
const Kit := preload("res://ramon/QuantumRange/carried/kit/kit_style.gd")

const ELLIPSE_SEGMENTS := 96
const NAT_LOG_2 := 0.6931471805599453094
## Metres at which a target is halfway to the rim (the rim is infinitely far, an exponential map).
const HALFWAY_METERS := 6.0
const MINOR_LINE_SPACING_MULTIPLIER := 1.5
## Ramon's choice: false makes E (ana) move targets up the radar.
const W_IS_UP: bool = false
const SQUASH := 0.55

var player: Node4D
var camera: Camera4D
## The highlighted part's world position (Vector4.INF: none).
var current_at: Vector4 = Vector4.INF


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func _process(_d: float) -> void:
	queue_redraw()


func _ellipse(centre: Vector2, radii: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var a: float = TAU * i / ELLIPSE_SEGMENTS
		pts.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


## A position relative to you, in your own frame, mapped onto the radar: [plane point, stem end].
func _map(rel_local: Vector4, centre: Vector2, radii: Vector2) -> Array:
	var l: float = rel_local.length()
	var k: float = (1.0 - exp(-l * (NAT_LOG_2 / HALFWAY_METERS))) / maxf(l, 0.0001)
	var s: Vector4 = rel_local * k
	var on_plane: Vector2 = centre + Vector2(s.x * radii.x, s.z * radii.y)
	var wv: float = rel_local.w
	var w_k: float = signf(wv) * (1.0 - exp(-absf(wv) * (NAT_LOG_2 / 1.5)))
	var w_off: float = -w_k if W_IS_UP else w_k
	return [on_plane, on_plane + Vector2(0.0, w_off * radii.y * 0.95)]


func _draw() -> void:
	var u: float = get_viewport_rect().size.y / 720.0
	var margin: float = 0.9
	var centre: Vector2 = size * 0.5
	var radii: Vector2 = centre * margin
	radii.y = radii.x * SQUASH
	centre.y = size.y * (0.5 + 0.5 * margin) - radii.x * SQUASH
	var pts: PackedVector2Array = _ellipse(centre, radii)
	# Black glass under the disc (the kit's rule: screens and overlays are black glass).
	var glass := PackedColorArray()
	glass.resize(pts.size())
	glass.fill(Color(Kit.UI_GLASS, 0.55))
	draw_polygon(pts, glass)
	var line := Color(1, 1, 1, 0.5)
	var minor := Color(1, 1, 1, 0.22)
	var f: Font = Kit.ui_font("heading")
	var px: int = Kit.type_px("micro", u)
	var last_y: float = -1.0
	for i in range(1, int(12 * MINOR_LINE_SPACING_MULTIPLIER)):
		var mr: Vector2 = radii * (1.0 - exp(-i * (NAT_LOG_2 / MINOR_LINE_SPACING_MULTIPLIER)))
		var mp: PackedVector2Array = _ellipse(centre, mr)
		mp.append(mp[0])
		draw_polyline(mp, minor, 1.0, true)
		if mr.y - last_y > float(px) * 1.4:
			var metres: float = i * HALFWAY_METERS / MINOR_LINE_SPACING_MULTIPLIER
			draw_string(f, centre + Vector2(-30.0 * u, -mr.y - 2.0 * u), "%dm" % int(metres), HORIZONTAL_ALIGNMENT_CENTER, 60.0 * u, px, Color(1, 1, 1, 0.45))
		last_y = mr.y
	var rim: PackedVector2Array = pts.duplicate()
	rim.append(rim[0])
	draw_polyline(rim, line, 2.0, true)
	if player == null:
		return
	var eye: Vector4 = player.global_position
	var inv: Projection = player.global_basis.inverse()
	_draw_axes(centre, radii, inv, u)
	draw_circle(centre, 5.0 * u, Color(1, 1, 1, 0.95))
	# Every target's marks, nearest last so it draws on top.
	var marks: Array = []
	for t in get_tree().get_nodes_in_group("range_target"):
		if not is_instance_valid(t) or not t.is_inside_tree():
			continue
		for m in t.call("marks"):
			marks.append(m)
	marks.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector4).distance_to(eye) > (b[0] as Vector4).distance_to(eye))
	for m in marks:
		var rel: Vector4 = inv * ((m[0] as Vector4) - eye)
		var mp2: Array = _map(rel, centre, radii)
		var a: Vector2 = mp2[0]
		var b: Vector2 = mp2[1]
		var role: String = String(m[1])
		var locked: bool = bool(m[2])
		var col: Color = _role_color(role, locked)
		draw_circle(a, 3.0 * u, Color(0.65, 0.67, 0.70, 0.85))
		if a.distance_to(b) > 1.0:
			draw_line(a, b, Color(col, 0.65), maxf(1.5, 2.0 * u))
		_marker(b, role, locked, col, u)
		if current_at != Vector4.INF and (m[0] as Vector4).distance_to(current_at) < 0.01:
			draw_arc(b, 10.0 * u, 0.0, TAU, 32, Color(1, 1, 1, 0.95), maxf(1.5, 2.0 * u), true)


func _role_color(role: String, locked: bool) -> Color:
	match role:
		"core":
			return Color(0.62, 0.20, 0.20) if locked else Style.glow("core")
		"armour":
			return Style.glow("armour")
		"friend":
			return Style.glow("friend")
		"w":
			return Style.glow("w")
	return Color(0.97, 0.97, 0.98)


func _marker(at: Vector2, role: String, locked: bool, col: Color, u: float) -> void:
	var s: float = 5.5 * u
	match role:
		"core":
			if locked:
				draw_arc(at, s, 0.0, TAU, 24, col, maxf(1.5, 2.0 * u), true)
			else:
				draw_circle(at, s, col)
		"armour":
			draw_rect(Rect2(at - Vector2(s, s), Vector2(s, s) * 2.0), col, true)
		"friend":
			var t: float = s * 0.45
			draw_rect(Rect2(at - Vector2(s, t), Vector2(s * 2.0, t * 2.0)), col, true)
			draw_rect(Rect2(at - Vector2(t, s), Vector2(t * 2.0, s * 2.0)), col, true)
		"w":
			draw_arc(at, s, 0.0, TAU, 24, col, maxf(2.0, 2.5 * u), true)
		_:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 1.2), at + Vector2(s, 0), at + Vector2(0, s * 1.2), at + Vector2(-s, 0)]), col)


## Ramon's settings: the six cardinal letters (N S E W, A and K for ana and kata) and each axis drawn
## projected onto the plane with its W rise, in the engine's own axis colours.
func _draw_axes(centre: Vector2, radii: Vector2, inv: Projection, u: float) -> void:
	var f: Font = Kit.ui_font("heading")
	var px: int = Kit.type_px("micro", u)
	var labels := {"N": -inv.z, "S": inv.z, "E": inv.x, "W": -inv.x, "A": inv.w, "K": -inv.w}
	for label in labels:
		var v: Vector4 = labels[label]
		var p: Vector2 = centre + Vector2(v.x * radii.x, v.z * radii.y)
		var wo: float = -v.w if W_IS_UP else v.w
		var e: Vector2 = p + Vector2(0.0, wo * radii.y)
		draw_string(f, e + Vector2(-8.0 * u, (12.0 if wo >= 0.0 else -4.0) * u), String(label), HORIZONTAL_ALIGNMENT_CENTER, 16.0 * u, px, Color(1, 1, 1, 0.55))
	for i in 4:
		var v: Vector4 = inv[i]
		var off := Vector2(v.x * radii.x, v.z * radii.y)
		var wo: float = -v.w if W_IS_UP else v.w
		var stem: Vector2 = off + Vector2(0.0, wo * radii.y)
		var c: Color = Vector4D.axis_color(i)
		c.a = 0.55
		draw_line(centre, centre + off, c, 1.0)
		draw_line(centre + off, centre + stem, c, 1.0)
		draw_line(centre, centre - off, c, 1.0)
		draw_line(centre - off, centre - stem, c, 1.0)
