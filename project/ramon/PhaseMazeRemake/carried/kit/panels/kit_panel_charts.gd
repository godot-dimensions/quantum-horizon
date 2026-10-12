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
## Each takes its data with set_data(d) and draws in its own box (units, at k pixels a unit).
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/PhaseMazeRemake/carried/kit/panels/kit_panel_spec.gd")
const E := preload("res://ramon/PhaseMazeRemake/carried/kit/panels/kit_panel_elements.gd")
const Glyphs := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_glyphs.gd")
const Style := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const Presentation := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_presentation.gd")
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
