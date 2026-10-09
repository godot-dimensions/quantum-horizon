@tool
extends RefCounted

## Kit: the research panel's live drawings for animals, each an element of its own (the chart
## surface's content, kit_panel_elements.gd El), in the Figma's tokens. They are the drawings the
## first research wall made (kit_research_wall_4d.gd), carried over with their data and their
## animations (the handoff: "retain the application's existing ... chart data, live measurement
## logic ... and animations"), only set in the new chart surface:
##   Glyph     the animal in profile (kit_glyphs.gd animal), the production drawing
##   Balls     its balls in profile and the bones between them; lit as the build places them, or as
##             the rig's joints, a pulse running along them
##   Profile   how much of the body each W holds, the slice stops, the slice you see
##   Cost      milliseconds a frame on a log scale: the walk live against re-lofting its legs
##   Wave      WATER LAB (carried copy, 9 Oct): moving diagrams of how the water and the fish work,
##             one `mode` each (gerstner, solve, absorb, swim, cut), animated by their own clock:
##             the research page keeps redrawing while one is shown (kit_panel_research.gd tick)
## Each takes its data with set_data(d) and draws in its own box (units, at k pixels a unit).
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/WaterLab/carried/kit/panels/kit_panel_spec.gd")
const E := preload("res://ramon/WaterLab/carried/kit/panels/kit_panel_elements.gd")
const Glyphs := preload("res://ramon/WaterLab/carried/kit/kit_glyphs.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")
const Presentation := preload("res://ramon/WaterLab/carried/kit/kit_presentation.gd")
const GOLD := Color(1.0, 0.80, 0.35)
const WARM := Color(1.0, 0.55, 0.36)


static func ms(v: float) -> String:
	return Presentation.ms(v)


## The animal, filled in white, its eye and inner lines cut in the wall's blue.
class Glyph extends E.El:
	var kind: String = "goat"
	var fig: float = Spec.SPEC_GLYPH_FIG

	func set_kind(kd: String) -> void:
		if kd != kind:
			kind = kd
			queue_redraw()

	func _draw() -> void:
		var cut: Color = Spec.TOKENS["blue"] if Spec.flat else Style.pick(Style.CODE_BLUE)
		var r := Rect2((size - Vector2(fig, fig) * k) * 0.5, Vector2(fig, fig) * k)
		Glyphs.animal(self, kind, r, Spec.ink("white"), cut)


## The balls in profile: {"balls": [[Vector2, r], ...], "bones": [[i, j], ...], "lit": n, "gold": bool,
## "pulse": i}.
class Balls extends E.El:
	var d: Dictionary = {}

	func set_data(v: Dictionary) -> void:
		d = v
		queue_redraw()

	func _draw() -> void:
		var balls: Array = d.get("balls", [])
		if balls.is_empty():
			return
		var r := Rect2(Vector2(24, 18) * k, size - Vector2(48, 36) * k)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for b in balls:
			var p: Vector2 = b[0]
			var rr: float = float(b[1])
			lo = Vector2(minf(lo.x, p.x - rr), minf(lo.y, p.y - rr))
			hi = Vector2(maxf(hi.x, p.x + rr), maxf(hi.y, p.y + rr))
		var span: Vector2 = (hi - lo).max(Vector2(0.001, 0.001))
		var s: float = minf(r.size.x / span.x, r.size.y / span.y)
		var off: Vector2 = r.get_center() - Vector2((lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5) * s
		var at := func(p: Vector2) -> Vector2: return off + Vector2(p.x, -p.y) * s
		var gold: bool = bool(d.get("gold", false))
		var lit: int = int(d.get("lit", balls.size()))
		var pulse: int = int(d.get("pulse", -10))
		var hue: Color = GOLD if gold else Spec.ink("accent")
		for bone in d.get("bones", []):
			var i0: int = int(bone[0])
			var i1: int = int(bone[1])
			if i0 < balls.size() and i1 < balls.size():
				var on: bool = gold or (i0 < lit and i1 < lit)
				draw_line(at.call(balls[i0][0]), at.call(balls[i1][0]), Color(hue, 0.85 if on else 0.2), maxf(1.0, (1.2 if gold else 0.8) * k), true)
		for i in balls.size():
			var b: Array = balls[i]
			var rad: float = maxf(float(b[1]) * s, 1.5 * k)
			if gold:
				var hot: bool = absi(i - pulse) <= 1
				draw_arc(at.call(b[0]), rad, 0.0, TAU, 40, Color(GOLD, 1.0 if hot else 0.75), maxf(1.0, (1.5 if hot else 1.0) * k), true)
				draw_circle(at.call(b[0]), maxf(2.0, 1.6 * k), GOLD)
			elif i < lit:
				draw_circle(at.call(b[0]), rad, Spec.ink("white", 0.18))
				draw_arc(at.call(b[0]), rad, 0.0, TAU, 40, Spec.ink("white"), maxf(1.0, 0.9 * k), true)
			else:
				draw_arc(at.call(b[0]), rad, 0.0, TAU, 40, Spec.ink("white", 0.25), maxf(1.0, 0.6 * k), true)


## The W profile: {"bins": PackedFloat32Array, "stops": [...], "index": i, "frac": -1..1}.
class Profile extends E.El:
	var d: Dictionary = {}

	func set_data(v: Dictionary) -> void:
		d = v
		queue_redraw()

	func _draw() -> void:
		var bins: PackedFloat32Array = d.get("bins", PackedFloat32Array())
		if bins.size() < 2:
			return
		var pr := Rect2(Vector2(20, 22) * k, size - Vector2(40, 48) * k)
		var frac: float = float(d.get("frac", 0.0))
		Glyphs.profile(self, pr, bins, Spec.ink("white", 0.22), Spec.ink("accent"), d.get("stops", []), int(d.get("index", -1)), frac, GOLD)
		var f: Font = Spec.font("micro")
		var px: int = int(round(Spec.size_of("micro") * k))
		draw_string(f, Vector2(20 * k, size.y - 10 * k), "−W", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Spec.ink("muted"))
		draw_string(f, Vector2(0, size.y - 10 * k), "+W", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 20 * k, px, Spec.ink("muted"))
		var mx: float = pr.position.x + pr.size.x * (clampf(frac, -1.0, 1.0) * 0.5 + 0.5)
		var tag: String = "THE SLICE YOU SEE"
		var fb: Font = Spec.font("label")
		var tpx: int = int(round(Spec.size_of("tiny") * k))
		var tw: float = fb.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
		var tx: float = mx + 6.0 * k if mx + 6.0 * k + tw < size.x - 8.0 * k else mx - 6.0 * k - tw
		draw_string(fb, Vector2(tx, 14 * k), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, GOLD)


## WATER LAB: a moving diagram. {"mode": ..., and per mode: "absorption" (Vector3 per metre),
## "steep" (0..1), "amp" (tail amplitude, body lengths), "w" (-1..1 the slice through a fish)}.
class Wave extends E.El:
	var d: Dictionary = {}
	var animated: bool = true

	func set_data(v: Dictionary) -> void:
		d = v
		queue_redraw()

	func _draw() -> void:
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var r := Rect2(Vector2(24, 20) * k, size - Vector2(48, 44) * k)
		match String(d.get("mode", "gerstner")):
			"gerstner":
				_gerstner(r, t)
			"solve":
				_solve(r, t)
			"absorb":
				_absorb(r, t)
			"swim":
				_swim(r, t)
			"cut":
				_cut(r, t)
			"weed":
				_weed(r, t)

	func _label(p: Vector2, s: String, col: Color, role: String = "micro") -> void:
		draw_string(Spec.font(role), p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(Spec.size_of(role) * k)), col)

	## Water particles turning in circles under a Gerstner wave: the surface is the path of the top
	## row, a trochoid, sharp at the crests; each row below turns in a smaller circle.
	func _gerstner(r: Rect2, t: float) -> void:
		var steep: float = clampf(float(d.get("steep", 0.75)), 0.1, 1.0)
		var lam: float = r.size.x / 2.0
		var kk: float = TAU / lam
		var amp: float = r.size.y * 0.16
		var om: float = 1.6
		var y0: float = r.position.y + r.size.y * 0.32
		var surf := PackedVector2Array()
		for i in 121:
			var x0: float = r.position.x + r.size.x * float(i) / 120.0
			var ph: float = kk * x0 - om * t
			surf.append(Vector2(x0 - steep * amp * sin(ph), y0 - amp * cos(ph)))
		var fill := surf.duplicate()
		fill.append(Vector2(r.end.x, r.end.y))
		fill.append(Vector2(r.position.x, r.end.y))
		draw_colored_polygon(fill, Spec.ink("white", 0.06))
		draw_polyline(surf, Spec.ink("white"), maxf(1.5, 1.6 * k), true)
		for row in 4:
			var depth: float = float(row) * r.size.y * 0.17
			var shrink: float = exp(-kk * depth * 0.9)
			var yc: float = y0 + depth
			for col_i in 9:
				var x0: float = r.position.x + r.size.x * (float(col_i) + 0.5) / 9.0
				var ph: float = kk * x0 - om * t
				var rad: float = amp * shrink
				var hot: bool = col_i == 4
				draw_arc(Vector2(x0, yc), rad, 0.0, TAU, 32, Spec.ink("white", 0.30 if hot else 0.12), maxf(1.0, 0.6 * k), true)
				var p := Vector2(x0 - steep * rad * sin(ph), yc - rad * cos(ph))
				draw_circle(p, maxf(2.0, (2.2 if hot else 1.5) * k), GOLD if hot else Spec.ink("accent"))
		_label(Vector2(r.position.x, r.end.y + 16 * k), "Each particle turns in a circle; the surface they make is sharp at the crest, flat in the trough.", Spec.ink("muted"))

	## The slice solve: the water at a point came from somewhere else. The shader starts at the
	## point, asks where the water there moves to, and steps back by the miss, twice.
	func _solve(r: Rect2, t: float) -> void:
		var lam: float = r.size.x / 1.6
		var kk: float = TAU / lam
		var amp: float = r.size.y * 0.15
		var q: float = 0.8
		var y0: float = r.position.y + r.size.y * 0.45
		var om: float = 0.9
		var disp := func(x: float) -> float: return x - q * amp * sin(kk * x - om * t)
		var height := func(x: float) -> float: return y0 - amp * cos(kk * x - om * t)
		var surf := PackedVector2Array()
		for i in 121:
			var x0: float = r.position.x + r.size.x * float(i) / 120.0
			surf.append(Vector2(disp.call(x0), height.call(x0)))
		draw_polyline(surf, Spec.ink("white"), maxf(1.5, 1.4 * k), true)
		for i in 11:
			var x0: float = r.position.x + r.size.x * (float(i) + 0.5) / 11.0
			var top := Vector2(disp.call(x0), height.call(x0))
			draw_line(Vector2(x0, r.end.y - 6 * k), top, Spec.ink("white", 0.12), maxf(1.0, 0.6 * k), true)
			draw_circle(Vector2(x0, r.end.y - 6 * k), maxf(1.5, 1.4 * k), Spec.ink("white", 0.35))
		# The point being drawn, and the guesses converging on the water that lands there.
		var target: float = r.position.x + r.size.x * (0.5 + 0.18 * sin(t * 0.4))
		draw_line(Vector2(target, r.position.y), Vector2(target, r.end.y), GOLD, maxf(1.0, 1.0 * k), true)
		var guess: float = target
		for n in 3:
			var lands: float = disp.call(guess)
			var gy: float = r.end.y - 6 * k
			draw_circle(Vector2(guess, gy), maxf(2.0, 2.2 * k), Spec.ink("accent", 1.0 - 0.25 * float(n)))
			draw_line(Vector2(guess, gy), Vector2(lands, height.call(guess)), Spec.ink("accent", 0.8 - 0.2 * float(n)), maxf(1.0, 1.0 * k), true)
			guess += target - lands
		draw_circle(Vector2(target, height.call(guess)), maxf(2.5, 2.8 * k), GOLD)
		_label(Vector2(r.position.x, r.end.y + 16 * k), "Gold: the point drawn. Blue: each pass of the solve, closer to the water that lands there.", Spec.ink("muted"))

	## Beer-Lambert: what is left of red, green and blue light after so many metres of water.
	func _absorb(r: Rect2, t: float) -> void:
		var a: Vector3 = d.get("absorption", Vector3(0.26, 0.065, 0.045))
		var depth_max: float = 12.0
		var cols: Array = [Color(1.0, 0.35, 0.3), Color(0.35, 1.0, 0.5), Color(0.4, 0.6, 1.0)]
		for c in 3:
			var pts := PackedVector2Array()
			for i in 81:
				var dd: float = depth_max * float(i) / 80.0
				pts.append(Vector2(r.position.x + r.size.x * float(i) / 80.0, r.end.y - r.size.y * exp(-a[c] * dd)))
			draw_polyline(pts, cols[c], maxf(1.5, 1.4 * k), true)
		var u: float = fposmod(t * 0.12, 1.0)
		var md: float = depth_max * u
		var mx: float = r.position.x + r.size.x * u
		draw_line(Vector2(mx, r.position.y), Vector2(mx, r.end.y), Spec.ink("white", 0.5), maxf(1.0, 0.8 * k), true)
		var left := Color(exp(-a.x * md), exp(-a.y * md), exp(-a.z * md))
		var sw := Rect2(Vector2(r.end.x - 70 * k, r.position.y), Vector2(70, 34) * k)
		draw_rect(sw, Color(left.r * 0.95, left.g * 0.95, left.b * 0.95))
		_label(sw.position + Vector2(0, 46 * k), "%.1f m of water" % md, Spec.ink("white"))
		_label(Vector2(r.position.x, r.end.y + 16 * k), "Red is gone first, then green: deep water, and the far side of the tank, turn blue.", Spec.ink("muted"))

	## The koi's swim from above: the spine as a wave running head to tail inside its envelope.
	func _swim(r: Rect2, t: float) -> void:
		var amp: float = float(d.get("amp", 0.10))
		var cy: float = r.get_center().y
		var L: float = r.size.x * 0.92
		var x0: float = r.position.x + r.size.x * 0.04
		var scale_y: float = L * 1.6
		var env_hi := PackedVector2Array()
		var env_lo := PackedVector2Array()
		var spine := PackedVector2Array()
		for i in 101:
			var s: float = float(i) / 100.0
			var a: float = amp * 10.0 * (0.02 - 0.08 * s + 0.16 * s * s)
			var x: float = x0 + L * s
			env_hi.append(Vector2(x, cy - a * scale_y))
			env_lo.append(Vector2(x, cy + a * scale_y))
			spine.append(Vector2(x, cy + a * scale_y * sin(TAU * s - t * TAU * 1.2)))
		draw_polyline(env_hi, Spec.ink("white", 0.25), maxf(1.0, 0.8 * k), true)
		draw_polyline(env_lo, Spec.ink("white", 0.25), maxf(1.0, 0.8 * k), true)
		draw_polyline(spine, Spec.ink("accent"), maxf(2.0, 2.4 * k), true)
		draw_circle(spine[0], maxf(3.0, 3.4 * k), Spec.ink("white"))
		draw_circle(spine[25], maxf(2.0, 2.0 * k), GOLD)
		_label(spine[0] + Vector2(0, -14 * k), "head 0.02", Spec.ink("muted"))
		_label(Vector2(spine[25].x - 20 * k, cy + 30 * k), "least here", GOLD)
		_label(Vector2(r.end.x - 70 * k, cy - amp * scale_y - 8 * k), "tail %.2f" % amp, Spec.ink("muted"))
		_label(Vector2(r.position.x, r.end.y + 16 * k), "The wave runs head to tail a beat at a time; between beats the koi glides.", Spec.ink("muted"))

	## The weed (the pen's grass under water): a band of current sweeping along the bed, each blade
	## leaning as it passes, a wave running up it, buoyancy standing it back up; at the right, one blade
	## cut by the slice at three W, narrower and shorter off its middle.
	func _weed(r: Rect2, t: float) -> void:
		var bed := Rect2(r.position, Vector2(r.size.x * 0.66, r.size.y))
		var ground: float = bed.end.y - 6.0 * k
		draw_line(Vector2(bed.position.x, ground), Vector2(bed.end.x, ground), Spec.ink("white", 0.4), maxf(1.0, 1.0 * k), true)
		# The band: moving downstream, wrapped.
		var bx: float = bed.position.x + fposmod(t * 0.18, 1.3) * bed.size.x - 0.15 * bed.size.x
		var band_w: float = bed.size.x * 0.22
		draw_rect(Rect2(Vector2(bx - band_w * 0.5, bed.position.y), Vector2(band_w, ground - bed.position.y)), Color(GOLD, 0.10))
		_label(Vector2(clampf(bx - 30 * k, bed.position.x, bed.end.x - 80 * k), bed.position.y + 10 * k), "the current", GOLD)
		for i in 9:
			var rx: float = bed.position.x + bed.size.x * (float(i) + 0.5) / 9.0
			var h: float = bed.size.y * (0.55 + 0.35 * fposmod(float(i) * 0.618, 1.0))
			var near: float = exp(-pow((rx - bx) / band_w, 2.0))
			var pts := PackedVector2Array()
			for j in 21:
				var s: float = float(j) / 20.0
				var lean: float = (0.12 + 0.5 * near) * s * s
				var wave: float = 0.10 * s * sin(TAU * s * 0.9 - t * 1.6 + float(i))
				var dx: float = (lean + wave) * h
				pts.append(Vector2(rx + dx, ground - s * h + 0.5 * dx * dx / maxf(s * h, 1.0)))
			draw_polyline(pts, Color(0.55, 0.85, 0.45, 0.95) if near > 0.4 else Color(0.45, 0.72, 0.38, 0.85), maxf(1.5, 2.2 * k), true)
		# The cut: one blade at three W.
		var cut := Rect2(Vector2(r.position.x + r.size.x * 0.72, r.position.y), Vector2(r.size.x * 0.28, r.size.y))
		for n in 3:
			var w: float = float(n) * 0.45
			var sec: float = sqrt(maxf(1.0 - w * w, 0.0))
			var cx: float = cut.position.x + cut.size.x * (float(n) + 0.5) / 3.0
			var bh: float = cut.size.y * 0.8 * sec
			var bw: float = 9.0 * k * sec
			draw_colored_polygon(PackedVector2Array([Vector2(cx - bw * 0.5, ground), Vector2(cx + bw * 0.5, ground), Vector2(cx + bw * 0.2, ground - bh), Vector2(cx - bw * 0.2, ground - bh)]), Color(0.45, 0.75, 0.40, 0.9))
			_label(Vector2(cx - 14 * k, ground + 14 * k), "w %.2f" % (w * 0.45), Spec.ink("muted"))
		_label(Vector2(r.position.x, r.end.y + 16 * k), "A band of current runs along the bed; each blade leans, a wave climbs it, buoyancy stands it back up.", Spec.ink("muted"))

	## The 4D cut: how much of a fish the slice shows, as the slice moves through it in W.
	func _cut(r: Rect2, t: float) -> void:
		var pts := PackedVector2Array()
		var base: float = r.end.y - 4 * k
		var half: float = r.size.x * 0.22
		var cx: float = r.position.x + half + 10 * k
		for i in 81:
			var w: float = -1.0 + 2.0 * float(i) / 80.0
			pts.append(Vector2(cx + w * half, base - r.size.y * 0.8 * sqrt(maxf(1.0 - w * w, 0.0))))
		draw_polyline(pts, Spec.ink("white"), maxf(1.5, 1.4 * k), true)
		draw_line(Vector2(cx - half, base), Vector2(cx + half, base), Spec.ink("white", 0.3), maxf(1.0, 0.6 * k), true)
		var w_now: float = sin(t * 0.6) * 1.05
		var sec: float = sqrt(maxf(1.0 - w_now * w_now, 0.0))
		var mx: float = cx + clampf(w_now, -1.0, 1.0) * half
		draw_line(Vector2(mx, r.position.y), Vector2(mx, base), GOLD, maxf(1.0, 1.0 * k), true)
		_label(Vector2(cx - half, base + 14 * k), "−W", Spec.ink("muted"))
		_label(Vector2(cx + half - 14 * k, base + 14 * k), "+W", Spec.ink("muted"))
		# The fish the slice shows, to the right (round 5: the animals are lofted in 4D). Each section of
		# the body is as deep through W as it is wide, so off the middle the slender parts go first: the
		# tail fin at once, then the ends, the body last.
		var fc := Vector2(r.position.x + r.size.x * 0.74, r.get_center().y)
		var fl: float = r.size.x * 0.20
		var wn: float = absf(w_now)
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for i in 41:
			var s: float = float(i) / 40.0
			var prof: float = pow(sin(PI * pow(s, 0.8)), 0.8)
			var cut: float = sqrt(maxf(1.0 - (wn / maxf(prof, 0.001)) * (wn / maxf(prof, 0.001)), 0.0)) if prof > wn else 0.0
			var x: float = fc.x + fl * (1.0 - 2.0 * s)
			top.append(Vector2(x, fc.y - fl * 0.32 * prof * cut))
			bottom.append(Vector2(x, fc.y + fl * 0.28 * prof * cut))
		bottom.reverse()
		top.append_array(bottom)
		if sec > 0.02:
			draw_colored_polygon(top, Spec.ink("white", 0.9))
		var fin: float = sqrt(maxf(1.0 - (wn / 0.08) * (wn / 0.08), 0.0))
		if fin > 0.02:
			var tx: float = fc.x - fl
			draw_colored_polygon(PackedVector2Array([Vector2(tx + fl * 0.1, fc.y), Vector2(tx - fl * 0.45 * fin, fc.y - fl * 0.35 * fin), Vector2(tx - fl * 0.45 * fin, fc.y + fl * 0.35 * fin)]), Spec.ink("white", 0.9))
		_label(Vector2(fc.x - 60 * k, r.end.y - 4 * k), "the cut: %d%%" % int(round(sec * 100.0)), GOLD)
		_label(Vector2(r.position.x, r.end.y + 16 * k), "A fish is a 4D body: whole on your slice. Off it the fins go first, then the ends, then all of it.", Spec.ink("muted"))


## The walk's cost: {"samples": PackedFloat32Array (ms a frame), "anim": ms, "reloft": ms}.
class Cost extends E.El:
	var d: Dictionary = {}

	func set_data(v: Dictionary) -> void:
		d = v
		queue_redraw()

	func _draw() -> void:
		var samples: PackedFloat32Array = d.get("samples", PackedFloat32Array())
		var anim: float = float(d.get("anim", -1.0))
		var reloft: float = float(d.get("reloft", -1.0))
		var f: Font = Spec.font("micro")
		var px: int = int(round(Spec.size_of("micro") * k))
		var tpx: int = int(round(Spec.size_of("tiny") * k))
		var chart := Rect2(Vector2(40, 14) * k, size - Vector2(52, 30) * k)
		var lo: float = log(0.003) / log(10.0)
		var hi: float = log(maxf(80.0, reloft * 3.0)) / log(10.0)
		var y_of := func(v: float) -> float:
			var l: float = log(maxf(v, 0.003)) / log(10.0)
			return chart.end.y - chart.size.y * clampf((l - lo) / (hi - lo), 0.0, 1.0)
		for g in [[0.01, "0.01 ms"], [0.1, "0.1 ms"], [1.0, "1 ms"], [10.0, "10 ms"]]:
			var gy: float = y_of.call(float(g[0]))
			draw_line(Vector2(chart.position.x, gy), Vector2(chart.end.x, gy), Spec.ink("white", 0.08), maxf(1.0, 0.5 * k), true)
			draw_string(f, Vector2(Spec.AXIS_X * k, gy + 2.0 * k), String(g[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, Spec.ink("muted"))
		# One whole frame at 60 fps, dashed, for scale.
		var by: float = y_of.call(16.7)
		for i in 40:
			if i % 2 == 0:
				var a := Vector2(lerpf(chart.position.x, chart.end.x, float(i) / 40.0), by)
				var b := Vector2(lerpf(chart.position.x, chart.end.x, float(i + 1) / 40.0), by)
				draw_line(a, b, Spec.ink("white", 0.45), maxf(1.0, 0.6 * k), true)
		draw_string(f, Vector2(chart.position.x + 4 * k, by + 9 * k), "one whole frame at 60 fps", HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, Spec.ink("muted"))
		if reloft > 0.0:
			var ry: float = y_of.call(reloft)
			draw_line(Vector2(chart.position.x, ry), Vector2(chart.end.x, ry), WARM, maxf(1.0, 1.0 * k), true)
			draw_string(f, Vector2(chart.position.x + 4 * k, ry - 4 * k), "re-lofting its legs every frame: " + Presentation.ms(reloft), HORIZONTAL_ALIGNMENT_LEFT, -1, px, WARM)
		if samples.size() < 2:
			draw_string(f, Vector2(chart.position.x, chart.end.y - 8 * k), "Measured as soon as it walks", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Spec.ink("muted"))
			return
		var pts := PackedVector2Array()
		for i in samples.size():
			pts.append(Vector2(chart.position.x + chart.size.x * float(i) / maxf(1.0, float(samples.size() - 1)), y_of.call(samples[i])))
		draw_polyline(pts, Spec.ink("white", 0.8), maxf(1.0, 0.7 * k), true)
		if anim > 0.0:
			var ay: float = y_of.call(anim)
			draw_line(Vector2(chart.position.x, ay), Vector2(chart.end.x, ay), Spec.ink("accent"), maxf(1.0, 1.0 * k), true)
			draw_string(f, Vector2(chart.position.x + 4 * k, ay - 4 * k), "the walk, live: " + Presentation.ms(anim), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Spec.ink("accent"))
