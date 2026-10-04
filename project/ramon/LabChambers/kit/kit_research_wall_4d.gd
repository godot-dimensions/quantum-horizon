@tool
extends "res://ramon/LabChambers/kit/kit_desk_4d.gd"

## Kit: the research wall. One large live 2D panel hung flat on the room's right-hand wall, the
## specimen's file: who is on the plinth, the part of its story playing now, what that part means
## and what it measured, and every specimen set side by side (Ramon, 4 Oct: "a dynamic panel (2d)
## that is placed against that wall, and shows tasteful metrics, or explainers ... for each animal,
## metrics update, and benchmark results"; his October-gate slides as inspiration, not a template).
##
## IT TURNS ITS PAGES WITH THE EXHIBIT. The showcase plays the presentation (kit_presentation.gd,
## the same parts for every animal) and the wall shows the page for the part playing: the balls,
## the skin, the slice, the rig, the walk. When nothing plays (the animal in your hands, or a new
## one arriving) it shows the specimen's summary. A page comes in with its figures counting up.
##
## EVERY NUMBER IS MEASURED, never typed in. From the exhibit's own data: its balls, tetrahedra,
## build stages, reach through W, its W profile and the live slice. From its bench (kit_bench.gd):
## the time to loft it whole from its balls and to loft one leg, timed on this machine; the walk's
## cost each frame, timed while it walks. "If re-lofted" is one leg's loft times its legs: what
## the walk would cost if the legs were rebuilt every frame, as the first creatures did.
##
## THE LOOK follows the lab's one style (kit_style.gd, "teaching surfaces"): the room's blue screen
## under the print, white type, cards as a white veil with an icon each (the research desk's
## tiles), light blue for what is live, gold for the slice, warm orange for the costly
## alternative; ExtraBold for the name and the figures. Its ink glows as the desk's does, so it reads
## as a screen sitting in the room's light rather than a white sheet laid over it (Ramon, 4 Oct: "it
## breaks consistency with the other design"; "the info wall is bright white"). `look` "paper" puts
## back the first version: a paper page after the October slides.
##
## The body is the research panel's (kit_desk_4d.gd) stood upright: tilt 90, no collision, its
## screen redrawn `refresh_hz` times a second into a viewport printed on its face.
##
## NO class_name (engine_gotchas.md).

const Presentation := preload("res://ramon/LabChambers/kit/kit_presentation.gd")
const Bench := preload("res://ramon/LabChambers/kit/kit_bench.gd")
const F_LIGHT := preload("res://ramon/Demo/fonts/Montserrat/static/Montserrat-Light.ttf")
const F_REGULAR := preload("res://ramon/Demo/fonts/Montserrat/static/Montserrat-Regular.ttf")

## The page is laid out on a 1600-unit width; its height follows the screen.
const VW := 1600.0
## The two looks' palettes: [paper, ink, grey, hairline, accent, inset card, bar, bar lit].
const LOOKS := {
	"screen": [Color(0, 0, 0, 0), Color(1, 1, 1), Color(0.78, 0.86, 1.0, 0.80), Color(1, 1, 1, 0.16), Color(0.55, 0.85, 1.0), Color(1, 1, 1, 0.07),
		Color(1, 1, 1, 0.30), Color(0.55, 0.85, 1.0)],
	"paper": [Color(0.957, 0.949, 0.925), Color(0.10, 0.10, 0.12), Color(0.44, 0.45, 0.48), Color(0.80, 0.79, 0.76), Color(0.13, 0.40, 0.86),
		Color(0.07, 0.08, 0.11), Color(0.40, 0.66, 1.0, 0.38), Color(0.40, 0.66, 1.0)],
}
const WARM := Color(1.0, 0.55, 0.36)
const GOLD := Color(1.0, 0.80, 0.35)
## Short lines under each part's name in the story list.
const STEP_LINES := {"balls": "placed by a designer", "skin": "lofted by the tool", "slice": "seen through W",
	"rig": "joints from the balls", "walk": "rigid pieces in motion"}

## "screen" (the lab's style) or "paper" (the first version, after the October slides).
@export_enum("screen", "paper") var look: String = "screen":
	set(v):
		look = v
		_palette()
		if is_inside_tree():
			_paint_parts()
## How bright the paper page glows in each mood (the screen look glows as the desk does).
@export var glow_dark: float = 0.5
@export var glow_bright: float = 0.42

var PAPER: Color
var INK: Color
var GREY: Color
var HAIR: Color
var ACCENT: Color
var INSET: Color
var BAR: Color
var BAR_LIT: Color
var _f_light: Font
var _f_regular: Font

var _page: int = -2            # the part shown (-1: the summary)
var _page_prev: int = -2
var _page_at: float = -10.0
var _serial_seen: int = -1
var _bench_live: Dictionary = {}
var _records: Dictionary = {}
var _records_at: float = -10.0
var _wrote_at: float = -10.0
var _lit_prev: int = -1
var _lit_at: float = -10.0
var _k: float = 1.0


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")
	_palette()


func near(_p: Vector4) -> bool:
	return false


func _palette() -> void:
	var pal: Array = LOOKS.get(look, LOOKS["screen"])
	PAPER = pal[0]
	INK = pal[1]
	GREY = pal[2]
	HAIR = pal[3]
	ACCENT = pal[4]
	INSET = pal[5]
	BAR = pal[6]
	BAR_LIT = pal[7]
	_f_light = F_LIGHT if look == "paper" else LabPrint.font("black")
	_f_regular = F_REGULAR if look == "paper" else LabPrint.font("bold")


func _paint_parts() -> void:
	super()
	if look == "paper" and is_instance_valid(_screen) and _vp != null:
		(_screen.material_override as TetraMaterial4D).get_cross_section_material_3d().set_shader_parameter("print_glow", glow_bright if Style.mood == "bright" else glow_dark)


# -- drawing helpers, in page units ------------------------------------------------------------------

func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _k


func _text(c: Control, f: Font, x: float, y: float, s: String, px: float, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	c.draw_string(f, _p(x, y), s, align, width * _k if width > 0.0 else -1.0, int(round(px * _k)), col)


func _wrap(c: Control, f: Font, x: float, y: float, s: String, px: float, col: Color, width: float, lines: int = 2) -> void:
	c.draw_multiline_string(f, _p(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, width * _k, int(round(px * _k)), lines, col)


func _width(f: Font, s: String, px: float) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(px * _k))).x / _k


func _line(c: Control, a: Vector2, b: Vector2, col: Color, w: float = 1.0) -> void:
	c.draw_line(a * _k, b * _k, col, maxf(1.0, w * _k), true)


func _rect(c: Control, r: Rect2, col: Color, radius: float = 0.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius * _k))
	sb.anti_aliasing = true
	c.draw_style_box(sb, Rect2(r.position * _k, r.size * _k))


static func _ease(x: float) -> float:
	var u: float = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


# -- the page ------------------------------------------------------------------------------------------

func _draw_screen() -> void:
	var c: Control = _canvas
	_k = c.size.x / VW
	var vh: float = c.size.y / _k
	var sc: Node = get_node_or_null(showcase)
	if _f_light == null:
		_palette()
	if PAPER.a > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), PAPER)
	if sc == null or _data.is_empty():
		_text(c, _f_light, 52, vh * 0.5, "Waiting for a specimen", 40, GREY)
		return
	var ex: Node = sc.get("exhibit")
	_bench_live = sc.call("bench")
	var code: String = String(_data.get("code", "XX-01"))
	# The bench book: the walk's measured cost kept as it walks, every specimen read back now and then.
	if bool(_bench_live.get("walking", false)) and float(_bench_live.get("anim_ms", -1.0)) > 0.0 and _clock - _wrote_at > 3.0:
		_wrote_at = _clock
		Bench.write(code, {"anim_ms": float(_bench_live["anim_ms"])})
	if _clock - _records_at > 2.0:
		_records_at = _clock
		_records = Bench.all()
	# Which page: the part playing, or the summary; a new specimen starts its pages again.
	var want: int = int(sc.get("seq_index"))
	var ser: int = int(sc.get("serial"))
	if want != _page or ser != _serial_seen:
		_page_prev = _page if ser == _serial_seen else -2
		_page = want
		_page_at = _clock
		_serial_seen = ser
	var age: float = _clock - _page_at
	var playing: bool = want >= 0
	var progress: float = clampf(float(sc.get("seq_t")) / maxf(float(sc.get("seq_len")), 0.01), 0.0, 1.0) if playing else 0.0
	# The header.
	_text(c, LabPrint.font("bold"), 52, 46, "CREATION LAB   /   RESEARCH WALL", 14, INK)
	var live_s: String = "MEASURED LIVE ON THIS MACHINE"
	var lw: float = _width(LabPrint.font("bold"), live_s, 13)
	_text(c, LabPrint.font("bold"), VW - 52 - lw, 46, live_s, 13, GREY)
	c.draw_circle(_p(VW - 52 - lw - 16, 41), 5.0 * _k, Color(0.25, 0.75, 0.45, 0.55 + 0.45 * sin(_clock * 4.0)))
	_line(c, Vector2(52, 64), Vector2(VW - 52, 64), HAIR, 1.5)
	_line(c, Vector2(52, 64), Vector2(52 + 180.0 * (progress if playing else 1.0), 64), ACCENT, 3.5)
	_draw_specimen(c, ex, playing, want, progress)
	_line(c, Vector2(458, 92), Vector2(458, 690), HAIR, 1.5)
	# The page: the old one leaving, the new one arriving.
	var hero := Rect2(492, 312, 600, 352)
	_rect(c, hero, INSET, 16)
	if _page_prev != -2 and age < 0.3:
		_draw_page(c, sc, ex, _page_prev, 1.0 - age / 0.3, -14.0 * (age / 0.3), 99.0, hero)
	if age >= 0.12:
		_draw_page(c, sc, ex, _page, 1.0, 0.0, age - 0.12, hero)
	_draw_bench_strip(c, code, vh)
	var adapter: String = RenderingServer.get_video_adapter_name()
	var when: String = String(_bench_live.get("measured", Time.get_date_string_from_system()))
	_text(c, LabPrint.font("body"), 52, vh - 14, "Measured in this room on %s, %s. Loft times recorded %s; the walk is timed every frame it plays. One machine, one scene." % [adapter, OS.get_name(), when], 12, GREY)


## The left column: the specimen, and its story with the part playing lit.
func _draw_specimen(c: Control, ex: Node, playing: bool, want: int, progress: float) -> void:
	var st: Dictionary = _data.get("stats", {})
	var fade: float = _ease((_clock - _page_at) / 0.6) if _page_prev == -2 else 1.0
	_text(c, LabPrint.font("bold"), 52, 106, "SPECIMEN  " + String(_data.get("code", "")), 13, GREY)
	_text(c, _f_light, 50, 172, String(_data.get("name", "")), 66, Color(INK, fade))
	_text(c, LabPrint.font("bold"), 52, 204, "%d BALLS   ·   %s TETRAHEDRA" % [int(st.get("balls", 0)), Presentation.thousands(int(st.get("tetra", 0)))], 13, GREY)
	var cut: Color = PAPER if PAPER.a > 0.0 else Style.pick({"bright": Color(0.12, 0.40, 0.88), "dark": Color(0.08, 0.28, 0.66)})
	Glyphs.animal(c, String(_data.get("icon", String(_data.get("name", "")).to_lower())), Rect2(_p(52, 226), _p(360, 170)), Color(INK, 0.9 * fade), cut)
	_text(c, LabPrint.font("bold"), 52, 438, "THE STORY", 13, GREY)
	var status: String = "PLAYING   ·   CLICK FOR THE NEXT PART" if playing else ("ARRIVING" if bool(get_node(showcase).call("arriving")) else "IN YOUR HANDS")
	_text(c, LabPrint.font("bold"), 52, 438, status, 11, ACCENT if playing else GREY, HORIZONTAL_ALIGNMENT_RIGHT, 368)
	_line(c, Vector2(52, 452), Vector2(420, 452), HAIR, 1.5)
	var parts: Array = Presentation.chapters()
	for i in parts.size():
		var y0: float = 470.0 + float(i) * 44.0
		var now: bool = i == want
		var done: bool = playing and i < want
		var col: Color = ACCENT if now else (INK if done else GREY)
		_text(c, LabPrint.font("bold"), 52, y0 + 18, "%02d" % (i + 1), 13, col)
		_text(c, _f_regular if now else _f_light, 92, y0 + 19, String(parts[i]["title"]).capitalize(), 20, INK if now or done else Color(GREY, GREY.a * (0.7 if look == "screen" else 1.0)))
		_text(c, LabPrint.font("body"), 52, y0 + 18, String(STEP_LINES.get(String(parts[i]["key"]), "")), 12, Color(GREY, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 368)
		if now:
			_line(c, Vector2(92, y0 + 30), Vector2(420, y0 + 30), Color(ACCENT, 0.18), 3.0)
			_line(c, Vector2(92, y0 + 30), Vector2(92 + 328.0 * progress, y0 + 30), ACCENT, 3.0)


## One page of the main area, `a` its opacity, `dy` how far it has moved, `age` seconds since it
## began arriving (its parts come in one after another).
func _draw_page(c: Control, sc: Node, ex: Node, page: int, a: float, dy: float, age: float, hero: Rect2) -> void:
	var key: String = String(Presentation.chapters()[page]["key"]) if page >= 0 else "summary"
	var st: Dictionary = _data.get("stats", {})
	var head: Array
	var explain: String
	var figs: Array
	var caption: String
	var nm: String = String(_data.get("name", "specimen")).to_lower()
	var anim: float = float(_bench_live.get("anim_ms", -1.0))
	var reloft: float = float(_bench_live.get("limb_ms", -1.0)) * float(_bench_live.get("limbs", 0))
	var balls: int = int(st.get("balls", 0))
	var tetra: int = int(st.get("tetra", 0))
	match key:
		"balls":
			head = ["Every shape starts", "as a handful of balls."]
			explain = "A designer places each ball by hand. Each one is a cross-section of the body: a size, two stretches, a squareness, and a reach into W."
			figs = [[float(balls), "int", "balls placed by hand", false, "ball"],
				[float(tetra) / maxf(float(balls), 1.0), "ratio", "tetrahedra the tool makes from every ball", true, "tetra"],
				[float(st.get("stages", 0)), "int", "build steps from the first ball to the finished body", false, "stages"]]
			caption = "The %s's balls, drawn from the exhibit itself, lit as they are placed." % nm
		"skin":
			head = ["The tool lofts the skin.", "Nothing is modelled by hand."]
			explain = "Between neighbouring balls the loft fills in tetrahedra, the four-dimensional cousin of triangles. Each bar is the mesh after one more build step."
			figs = [[float(tetra), "int", "tetrahedra in the finished body", false, "tetra"],
				[float(_bench_live.get("build_ms", -1.0)), "ms", "to loft all of it from its balls, on this machine", true, "clock"],
				[float(st.get("mb", 0.0)), "mb", "of mesh data in memory", false, "chip"]]
			caption = "Tetrahedra after each build step of the %s." % nm
		"slice":
			var frac: float = float(sc.call("slice_fraction"))
			var bins: PackedFloat32Array = _profile.get("bins", PackedFloat32Array())
			var cut: float = -1.0
			if bins.size() > 1:
				cut = bins[clampi(int(round((frac * 0.5 + 0.5) * float(bins.size() - 1))), 0, bins.size() - 1)] * 100.0
			head = ["Four dimensions,", "seen one slice at a time."]
			explain = "We only ever see a 3D slice of a 4D body. Slide the slice along W and the same animal shows a different shape."
			figs = [[float(st.get("reach", 0.0)), "pm", "its reach through W, either side of its middle", false, "axes"],
				[cut, "pct_live", "of its fullest cross-section, in the slice right now", true, "slice"],
				[float(int(sc.get("slice_index")) + 1), "slice", "the slice on show, of nine", false, "half"]]
			caption = "How much of the %s each W holds. The line is the slice you see." % nm
		"rig":
			head = ["The balls are the joints.", "The rig comes with the build."]
			explain = "The same balls that shape the body become its skeleton, so a new animal is ready to animate the moment it is built."
			figs = [[float(balls), "int", "joints, one for every ball", false, "ball"],
				[float(_bench_live.get("pieces", -1)), "int", "rigid pieces hung on them", true, "creatures"],
				[0.0, "zero", "bones placed by hand", false, "check"]]
			caption = "The %s's joints, ball to ball, as the x-ray shows them." % nm
		"walk":
			head = ["It walks without", "rebuilding its mesh."]
			explain = "The skin is cut once into rigid pieces. Each frame moves a few transforms and never a vertex, so the cost stays a sliver of a frame."
			figs = [[anim, "ms_live", "the walk's cost each frame, measured live", true, "live"],
				[reloft, "ms", "if its %d legs were re-lofted every frame" % int(_bench_live.get("limbs", 0)), false, "gauge"],
				[reloft / anim if anim > 0.0 and reloft > 0.0 else -1.0, "times", "cheaper with rigid pieces", false, "graph"]]
			caption = "Milliseconds a frame, on a log scale: the walk, live, against re-lofting."
		_:
			head = ["Built from %d balls." % balls, ("Walking at %s a frame." % Presentation.ms(anim)) if anim > 0.0 else "Walking without re-lofting."]
			explain = "Press 1 to 6 for another specimen. Every one is built, sliced and animated the same way, so their numbers compare."
			figs = [[float(tetra), "int", "tetrahedra, lofted from its balls", false, "tetra"],
				[float(_bench_live.get("build_ms", -1.0)), "ms", "to loft it whole, on this machine", false, "clock"],
				[anim, "ms", "for its walk, each frame", true, "live"]]
			caption = "The %s, ball by ball." % nm
	var stag := func(i: int) -> float: return _ease((age - 0.06 * float(i)) / 0.45)
	var col := func(base: Color, i: int) -> Color: return Color(base, base.a * a * float(stag.call(i)))
	var rise := func(i: int) -> float: return dy + 16.0 * (1.0 - float(stag.call(i)))
	var kick: String = ("%02d / %02d   ·   %s" % [page + 1, Presentation.chapters().size(), String(Presentation.chapters()[page]["title"])]) if page >= 0 else "SPECIMEN FILE   ·   %s" % String(_data.get("name", "")).to_upper()
	_text(c, LabPrint.font("bold"), 492, 106 + rise.call(0), kick, 14, col.call(ACCENT, 0))
	_text(c, _f_regular, 490, 166 + rise.call(1), String(head[0]), 46, col.call(INK, 1))
	_text(c, _f_regular, 490, 222 + rise.call(1), String(head[1]), 46, col.call(INK, 1))
	_wrap(c, LabPrint.font("body"), 492, 262 + rise.call(2), explain, 17, col.call(GREY, 2), 1050, 2)
	# The live drawing.
	var ha: float = a * float(stag.call(3))
	if ha > 0.01:
		var inner := Rect2(hero.position + Vector2(28, 26), hero.size - Vector2(56, 52))
		match key:
			"balls":
				_hero_balls(c, inner, ha, false)
			"skin":
				_hero_bars(c, inner, ha, age)
			"slice":
				_hero_profile(c, inner, ha, sc)
			"rig":
				_hero_balls(c, inner, ha, true)
			"walk":
				_hero_cost(c, inner, ha, anim, reloft)
			_:
				_hero_balls(c, inner, ha, false)
	_text(c, LabPrint.font("body"), 492, 688 + rise.call(3), caption, 13, col.call(GREY, 3))
	# The three figures.
	for i in figs.size():
		var f: Array = figs[i]
		var y0: float = 312.0 + float(i) * 118.0
		var fa: float = a * float(stag.call(4 + i))
		if fa <= 0.01:
			continue
		var count_up: float = _ease((age - 0.3 - 0.1 * float(i)) / 0.9)
		var big: String = _figure(float(f[0]), String(f[1]), count_up)
		var known: bool = not big.is_empty()
		var fx: float = 1128.0
		if look == "screen":
			# A tile, as the research desk's: the veil, an icon, the figure, its label.
			_rect(c, Rect2(1120, y0 - 2 + rise.call(4 + i), 428, 106), Color(INSET, INSET.a * fa), 14)
			Glyphs.icon(c, String(f[4]), Rect2(_p(1136, y0 + 18 + rise.call(4 + i)), _p(40, 40)), Color(ACCENT, fa))
			fx = 1192.0
		var fsize: float = (46.0 if look == "screen" else 52.0) if known else 28.0
		_text(c, _f_light, fx, y0 + 52 + rise.call(4 + i), big if known else "measuring", fsize, Color(ACCENT if bool(f[3]) else INK, fa) if known else Color(GREY, fa))
		_wrap(c, LabPrint.font("body"), fx + 2, y0 + 80 + rise.call(4 + i), String(f[2]), 14, Color(GREY, fa), 1540.0 - fx, 2)
		if i < figs.size() - 1 and look == "paper":
			_line(c, Vector2(1128, y0 + 114), Vector2(1548, y0 + 114), Color(HAIR, fa), 1.2)


## A figure as text, counted up to `v` by `u` (0..1); "" if not measured yet.
func _figure(v: float, kind: String, u: float) -> String:
	if kind == "zero":
		return "0"
	if v < 0.0:
		return ""
	var live: bool = kind.ends_with("_live") or kind == "slice"
	var x: float = v if live else v * u
	match kind:
		"int":
			return Presentation.thousands(int(round(x)))
		"ratio":
			return "1 : %d" % int(round(x))
		"ms", "ms_live":
			return Presentation.ms(x)
		"mb":
			return "%.1f MB" % x
		"pm":
			return "± %.2f m" % x
		"pct_live":
			return "%d%%" % int(round(x))
		"slice":
			return "%d / 9" % int(x)
		"times":
			return "%s×" % Presentation.thousands(int(round(x)))
	return str(x)


# -- the live drawings ---------------------------------------------------------------------------------

## The balls in profile, sized as placed, with the bones between them; lit as the build places them
## (blue), or as the rig's joints (gold, a pulse running along them).
func _hero_balls(c: Control, r: Rect2, a: float, gold: bool) -> void:
	var balls: Array = _shape.get("balls", [])
	if balls.is_empty():
		return
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
	var at := func(p: Vector2) -> Vector2: return (off + Vector2(p.x, -p.y) * s) * _k
	var ex: Node = (get_node(showcase) as Node).get("exhibit")
	var lit: int = balls.size()
	if not gold and ex != null and ex.has_method("balls_in_view"):
		lit = int(ex.call("balls_in_view"))
	if lit != _lit_prev:
		_lit_prev = lit
		_lit_at = _clock
	var hue: Color = GOLD if gold else Color(0.82, 0.93, 1.0)
	for bone in _shape.get("bones", []):
		var i0: int = int(bone[0])
		var i1: int = int(bone[1])
		if i0 < balls.size() and i1 < balls.size():
			var on: bool = gold or (i0 < lit and i1 < lit)
			c.draw_line(at.call(balls[i0][0]), at.call(balls[i1][0]), Color(hue, a * (0.85 if on else 0.18)), maxf(1.0, (2.4 if gold else 1.6) * _k), true)
	var pulse: int = int(_clock * 7.0) % maxi(balls.size(), 1)
	for i in balls.size():
		var b: Array = balls[i]
		var rad: float = maxf(float(b[1]) * s, 3.0) * _k
		var on: bool = i < lit
		if gold:
			var hot: bool = absi(i - pulse) <= 1
			c.draw_arc(at.call(b[0]), rad, 0.0, TAU, 40, Color(GOLD, a * (1.0 if hot else 0.75)), maxf(1.0, (3.0 if hot else 2.0) * _k), true)
			c.draw_circle(at.call(b[0]), maxf(2.5, 3.5 * _k), Color(GOLD, a))
		elif on:
			var pop: float = 1.0 + 0.25 * (1.0 - _ease((_clock - _lit_at) / 0.4)) if i == lit - 1 else 1.0
			c.draw_circle(at.call(b[0]), rad * pop, Color(1, 1, 1, 0.20 * a))
			c.draw_arc(at.call(b[0]), rad * pop, 0.0, TAU, 40, Color(0.86, 0.95, 1.0, a), maxf(1.0, 2.0 * _k), true)
		else:
			c.draw_arc(at.call(b[0]), rad, 0.0, TAU, 40, Color(0.86, 0.95, 1.0, 0.22 * a), maxf(1.0, 1.2 * _k), true)


## Tetrahedra after each build step, the bars growing in one after another, the step on show lit.
func _hero_bars(c: Control, r: Rect2, a: float, age: float) -> void:
	var bars: Array = _data.get("bars", [])
	if bars.is_empty():
		return
	var top: float = 1.0
	for v in bars:
		top = maxf(top, float(v))
	var nice: float = pow(10.0, floor(log(top) / log(10.0)))
	var step_v: float = nice * (1.0 if top / nice < 2.5 else (2.0 if top / nice < 5.0 else 5.0)) * 0.5
	var chart := Rect2(r.position + Vector2(56, 6), r.size - Vector2(64, 40))
	var fs: Font = LabPrint.font("body")
	var gv: float = 0.0
	while gv <= top * 1.001:
		var gy: float = chart.end.y - chart.size.y * gv / top
		c.draw_line(Vector2(chart.position.x, gy) * _k, Vector2(chart.end.x, gy) * _k, Color(1, 1, 1, 0.08 * a), maxf(1.0, _k), true)
		c.draw_string(fs, Vector2(r.position.x, gy + 5) * _k, Presentation.thousands(int(gv)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), Color(1, 1, 1, 0.45 * a))
		gv += step_v
	var n: int = bars.size()
	var slot: float = chart.size.x / float(n)
	var ex: Node = (get_node(showcase) as Node).get("exhibit")
	var on_show: int = int(ex.call("stage_in_view")) if ex != null and ex.has_method("stage_in_view") else -1
	for i in n:
		var grow: float = _ease((age - 0.15 - 0.07 * float(i)) / 0.5)
		var h: float = chart.size.y * float(bars[i]) / top * grow
		var lit: bool = i == on_show or (on_show < 0 and i == n - 1)
		var br := Rect2(Vector2(chart.position.x + slot * float(i) + slot * 0.18, chart.end.y - h), Vector2(slot * 0.64, h))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(BAR_LIT, a) if lit else Color(BAR, BAR.a * a)
		sb.set_corner_radius_all(int(4 * _k))
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		c.draw_style_box(sb, Rect2(br.position * _k, br.size * _k))
		c.draw_string(fs, Vector2(br.position.x, chart.end.y + 22) * _k, str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, br.size.x * _k, int(12 * _k), Color(1, 1, 1, 0.5 * a))
		if lit and grow > 0.99:
			c.draw_string(LabPrint.font("bold"), Vector2(br.position.x - 40, br.position.y - 10) * _k, Presentation.thousands(int(bars[i])), HORIZONTAL_ALIGNMENT_CENTER, (br.size.x + 80) * _k, int(14 * _k), Color(1, 1, 1, a))


## The W profile: how much of the body each W holds, the slice stops along its foot, the live slice.
func _hero_profile(c: Control, r: Rect2, a: float, sc: Node) -> void:
	var bins: PackedFloat32Array = _profile.get("bins", PackedFloat32Array())
	if bins.size() < 2:
		return
	var pr := Rect2(r.position + Vector2(10, 10), r.size - Vector2(20, 44))
	var frac: float = float(sc.call("slice_fraction"))
	Glyphs.profile(c, Rect2(pr.position * _k, pr.size * _k), bins, Color(0.80, 0.92, 1.0, 0.24 * a), Color(BAR_LIT.lightened(0.25), a),
		_stops, int(sc.get("slice_index")), frac, Color(GOLD, a))
	var fs: Font = LabPrint.font("bold")
	c.draw_string(fs, Vector2(r.position.x, r.end.y - 4) * _k, "−W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * _k), Color(1, 1, 1, 0.6 * a))
	c.draw_string(fs, Vector2(r.position.x, r.end.y - 4) * _k, "+W", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x * _k, int(14 * _k), Color(1, 1, 1, 0.6 * a))
	var mx: float = pr.position.x + pr.size.x * (clampf(frac, -1.0, 1.0) * 0.5 + 0.5)
	var tag: String = "THE SLICE YOU SEE"
	var tw: float = _width(fs, tag, 12)
	var tx: float = mx + 14.0 if mx + 14.0 + tw < r.end.x else mx - 14.0 - tw
	# On a small dark pill, so the tag reads where it crosses the silhouette.
	_rect(c, Rect2(tx - 8.0, pr.position.y - 4.0, tw + 16.0, 24.0), Color(0.03, 0.05, 0.10, 0.78 * a), 12)
	c.draw_string(fs, Vector2(tx, pr.position.y + 13) * _k, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), Color(GOLD, a))


## Milliseconds a frame on a log scale: the walk's own cost, frame by frame, against re-lofting its
## legs every frame, with one 60 fps frame marked for scale.
func _hero_cost(c: Control, r: Rect2, a: float, anim: float, reloft: float) -> void:
	var samples: PackedFloat32Array = _bench_live.get("samples", PackedFloat32Array())
	var fs: Font = LabPrint.font("body")
	var fb: Font = LabPrint.font("bold")
	var chart := Rect2(r.position + Vector2(64, 8), r.size - Vector2(72, 24))
	var lo: float = log(0.003) / log(10.0)
	var hi: float = log(maxf(80.0, reloft * 3.0)) / log(10.0)
	var y_of := func(v: float) -> float:
		var l: float = log(maxf(v, 0.003)) / log(10.0)
		return chart.end.y - chart.size.y * clampf((l - lo) / (hi - lo), 0.0, 1.0)
	for d in [[0.01, "0.01 ms"], [0.1, "0.1 ms"], [1.0, "1 ms"], [10.0, "10 ms"]]:
		var gy: float = y_of.call(float(d[0]))
		c.draw_line(Vector2(chart.position.x, gy) * _k, Vector2(chart.end.x, gy) * _k, Color(1, 1, 1, 0.07 * a), maxf(1.0, _k), true)
		c.draw_string(fs, Vector2(r.position.x, gy + 5) * _k, String(d[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), Color(1, 1, 1, 0.42 * a))
	var by: float = y_of.call(16.7)
	_dashed(c, Vector2(chart.position.x, by), Vector2(chart.end.x, by), Color(1, 1, 1, 0.45 * a))
	c.draw_string(fs, Vector2(chart.position.x + 8, by + 18) * _k, "one whole frame at 60 fps", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * _k), Color(1, 1, 1, 0.6 * a))
	if reloft > 0.0:
		var ry: float = y_of.call(reloft)
		c.draw_line(Vector2(chart.position.x, ry) * _k, Vector2(chart.end.x, ry) * _k, Color(WARM, a), maxf(1.0, 2.4 * _k), true)
		c.draw_string(fb, Vector2(chart.position.x + 8, ry - 8) * _k, "re-lofting its legs every frame: " + Presentation.ms(reloft), HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * _k), Color(WARM, a))
	if samples.size() < 2:
		c.draw_string(fb, Vector2(chart.position.x, chart.end.y - 20) * _k, "Measured as soon as it walks", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * _k), Color(1, 1, 1, 0.6 * a))
		return
	var pts := PackedVector2Array()
	for i in samples.size():
		pts.append(Vector2(chart.position.x + chart.size.x * float(i) / 179.0, y_of.call(samples[i])) * _k)
	c.draw_polyline(pts, Color(0.86, 0.95, 1.0, 0.8 * a), maxf(1.0, 1.6 * _k), true)
	if anim > 0.0:
		var ay: float = y_of.call(anim)
		c.draw_line(Vector2(chart.position.x, ay) * _k, Vector2(chart.end.x, ay) * _k, Color(BAR_LIT, a), maxf(1.0, 2.4 * _k), true)
		c.draw_string(fb, Vector2(chart.position.x + 8, ay - 10) * _k, "the walk, live: " + Presentation.ms(anim), HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * _k), Color(0.75, 0.88, 1.0, a))


func _dashed(c: Control, a: Vector2, b: Vector2, col: Color) -> void:
	var n: int = 40
	for i in n:
		if i % 2 == 0:
			c.draw_line(a.lerp(b, float(i) / float(n)) * _k, a.lerp(b, float(i + 1) / float(n)) * _k, col, maxf(1.0, 1.4 * _k), true)


## Every specimen measured so far, the same columns for each, the one on the plinth in the accent.
func _draw_bench_strip(c: Control, code: String, vh: float) -> void:
	var y: float = 712.0
	_line(c, Vector2(52, y), Vector2(VW - 52, y), HAIR, 1.5)
	var fb: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	_text(c, fb, 52, y + 28, "BENCHMARK", 13, ACCENT)
	_text(c, fl, 52 + _width(fb, "BENCHMARK", 13) + 14, y + 28, "every specimen, measured the same way in this room", 13, GREY)
	var cols: Array = [[52, "SPECIMEN"], [300, "BALLS"], [430, "TETRAHEDRA"], [610, "LOFTED IN"], [790, "ONE LEG"], [950, "WALK, EACH FRAME"], [1170, "IF RE-LOFTED"], [1370, "RIGID IS"]]
	for col in cols:
		_text(c, fb, float(col[0]), y + 56, String(col[1]), 11, GREY)
	var codes: Array = _records.keys()
	codes.sort()
	if not codes.has(code):
		codes.append(code)
	var row: int = 0
	for cd in codes:
		if row >= 3:
			break
		var rec: Dictionary = _records.get(cd, {})
		if cd == code:
			rec = rec.duplicate()
			for k in _bench_live:
				rec[k] = _bench_live[k]
			rec["balls"] = int(_data.get("stats", {}).get("balls", rec.get("balls", 0)))
			rec["tetra"] = int(_data.get("stats", {}).get("tetra", rec.get("tetra", 0)))
		var ry: float = y + 80.0 + float(row) * 22.0
		if ry > vh - 34.0:
			break
		var now: bool = cd == code
		var ink: Color = ACCENT if now else INK
		var f: Font = fb if now else fl
		var an: float = float(rec.get("anim_ms", -1.0))
		var rl: float = float(rec.get("limb_ms", -1.0)) * float(rec.get("limbs", 0))
		if now:
			c.draw_circle(_p(42, ry - 5), 4.0 * _k, ACCENT)
		_text(c, f, 52, ry, "%s  %s" % [String(rec.get("name", cd)), String(cd)], 14, ink)
		_text(c, f, 300, ry, str(int(rec.get("balls", 0))), 14, ink)
		_text(c, f, 430, ry, Presentation.thousands(int(rec.get("tetra", 0))), 14, ink)
		_text(c, f, 610, ry, Presentation.ms(float(rec["build_ms"])) if float(rec.get("build_ms", -1.0)) > 0.0 else "not yet", 14, ink if rec.has("build_ms") else GREY)
		_text(c, f, 790, ry, Presentation.ms(float(rec["limb_ms"])) if float(rec.get("limb_ms", -1.0)) > 0.0 else "not yet", 14, ink if rec.has("limb_ms") else GREY)
		_text(c, f, 950, ry, Presentation.ms(an) if an > 0.0 else "not yet", 14, ink if an > 0.0 else GREY)
		_text(c, f, 1170, ry, Presentation.ms(rl) if rl > 0.0 else "not yet", 14, ink if rl > 0.0 else GREY)
		_text(c, f, 1370, ry, ("%s× cheaper" % Presentation.thousands(int(round(rl / an)))) if an > 0.0 and rl > 0.0 else "not yet", 14, ink if an > 0.0 and rl > 0.0 else GREY)
		row += 1
