extends Control

## The range's screen layer, in the kit's black glass and Montserrat (carried/kit/kit_style.gd: screens
## and overlays are black glass, the walls are blue). Sizes follow the window's height (`u`, 720 px = 1).
##
##   top left       the objective card: the experiment, its stage, what to do, progress and the clock
##   top centre     a toast: one short line (a stage cleared, a penalty, a hint)
##   centre         the crosshair and its charge ring (range_crosshair.gd); the countdown; a stage's
##                  card as it begins; the results card at the end
##   bottom centre  the locator (range_radar.gd) and, above it, your W against the bay's limit, the
##                  slice angle, and how far through W the part you are going for is
##   bottom right   the keys that work now, one per line
##   the edges      glow cyan when the part you are going for is cut by your slice (both old ranges'
##                  alignment glow, in the range's colour for W)
##
## "The part you are going for" (current()) is the live target part nearest your line of sight in 4D,
## unlocked cores first: the radar circles it, the readout and the glow follow it.
##
## NO class_name (engine_gotchas.md).

const Kit := preload("res://ramon/QuantumRange/carried/kit/kit_style.gd")
const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")
const Crosshair := preload("res://ramon/QuantumRange/scripts/range_crosshair.gd")
const Radar := preload("res://ramon/QuantumRange/scripts/range_radar.gd")
const GlowShader := preload("res://ramon/QuantumRange/shaders/range_edge_glow.gdshader")

var player: CharacterBody4D
var weapon: Node
var w_limit: float = 2.0

## [[key, what], ...] for the key list.
var keys: Array = []
## The objective card: empty title hides it.
var card: Dictionary = {}

var crosshair: Control
var radar: Control
var _glow: ColorRect
var _glow_k: float = 0.0
## The moment the part you are going for comes into your slice, the edges flash; while it stays there
## they keep a quiet glow (a steady full glow, whenever anything was in your slice, was noise).
var _was_cut: bool = false
var _flash: float = 0.0
var _out_for: float = 0.0
var _toast: String = ""
var _toast_col: Color = Color.WHITE
var _toast_t: float = 0.0
var _stage_title: String = ""
var _stage_sub: String = ""
var _stage_t: float = 0.0
var _count: String = ""
var _count_t: float = 0.0
var _results: Dictionary = {}
var _current: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = ColorRect.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = GlowShader
	sm.set_shader_parameter("intensity", 0.0)
	sm.set_shader_parameter("edge_thickness", 0.12)
	_glow.material = sm
	add_child(_glow)
	radar = Control.new()
	radar.set_script(Radar)
	add_child(radar)
	crosshair = Control.new()
	crosshair.set_script(Crosshair)
	add_child(crosshair)


func toast(text: String, col: Color = Color.WHITE, seconds: float = 2.2) -> void:
	_toast = text
	_toast_col = col
	_toast_t = seconds


func stage_card(title: String, sub: String, seconds: float = 2.0) -> void:
	_stage_title = title
	_stage_sub = sub
	_stage_t = seconds


func countdown(text: String, seconds: float = 0.8) -> void:
	_count = text
	_count_t = seconds


func show_results(r: Dictionary) -> void:
	_results = r
	# The card stands alone: the radar, its readout and the crosshair step aside.
	radar.visible = false
	crosshair.visible = false


func hide_results() -> void:
	_results = {}
	radar.visible = true
	crosshair.visible = true


## The part you are going for: [target, world position, role, w reach], or [] when there is none.
func current() -> Array:
	return _current


func _pick_current() -> void:
	_current = []
	if player == null:
		return
	var cam: Camera4D = player.get("camera")
	if cam == null:
		return
	var eye: Vector4 = cam.global_position
	var fwd: Vector4 = -cam.global_basis.z
	var best: float = INF
	for t in get_tree().get_nodes_in_group("range_target"):
		if not is_instance_valid(t) or not bool(t.get("alive")):
			continue
		for p in t.get("parts"):
			if not bool(p["alive"]) or not bool(p["radar"]) or String(p["role"]) in ["w", "friend"]:
				continue
			var at: Vector4 = (p["node"] as Node4D).global_position
			var d: Vector4 = at - eye
			var l: float = d.length()
			if l < 0.01 or d.dot(fwd) <= 0.0:
				continue
			var ang: float = acos(clampf(d.dot(fwd) / l, -1.0, 1.0))
			# Unlocked cores first: a locked one is only what to go for when nothing else is left.
			if String(p["role"]) == "core" and bool(p["locked"]):
				ang += 1.0
			if ang < best:
				best = ang
				_current = [t, at, String(p["role"]), float(t.call("w_reach", p))]


## How far `at` lies off your slice (along your camera's W), metres.
func slice_offset(at: Vector4) -> float:
	var cam: Camera4D = player.get("camera") if player != null else null
	if cam == null:
		return 0.0
	return (at - cam.global_position).dot(cam.global_basis.w)


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want:
		position = Vector2.ZERO
		size = want
	_glow.position = Vector2.ZERO
	_glow.size = size
	crosshair.position = Vector2.ZERO
	crosshair.size = size
	crosshair.set("weapon", weapon)
	var rw: float = size.x * 0.32
	var rh: float = size.y * 0.40
	radar.position = Vector2((size.x - rw) * 0.5, size.y - rh)
	radar.size = Vector2(rw, rh)
	radar.set("player", player)
	_pick_current()
	radar.set("current_at", _current[1] if not _current.is_empty() else Vector4.INF)
	# The glow: full when the part is cut by your slice, rising as it nears it (within 30 degrees).
	var g: float = 0.0
	if not _current.is_empty():
		var off: float = absf(slice_offset(_current[1]))
		var reach: float = float(_current[3])
		var cam: Camera4D = player.get("camera")
		var dist: float = (_current[1] as Vector4).distance_to(cam.global_position)
		if off <= reach:
			g = 0.12
			# A flash only after a real search: the part was out of your slice for a moment first.
			if not _was_cut and _out_for > 0.4:
				_flash = 0.75
			_was_cut = true
			_out_for = 0.0
		else:
			_was_cut = false
			_out_for += delta
			var ang: float = rad_to_deg(asin(clampf((off - reach) / maxf(dist, 0.01), 0.0, 1.0)))
			var t: float = clampf((30.0 - ang) / 30.0, 0.0, 1.0)
			g = t * t * 0.55
	if _current.is_empty():
		_was_cut = false
	_flash = maxf(0.0, _flash - delta / 0.7)
	g = maxf(g, _flash)
	_glow_k = lerpf(_glow_k, g, 1.0 - exp(-14.0 * delta))
	(_glow.material as ShaderMaterial).set_shader_parameter("intensity", _glow_k)
	_toast_t = maxf(0.0, _toast_t - delta)
	_stage_t = maxf(0.0, _stage_t - delta)
	_count_t = maxf(0.0, _count_t - delta)
	queue_redraw()


func _glass(r: Rect2, radius: float, a: float = 1.0) -> void:
	draw_style_box(Kit.glass_box(radius, a), r)


func _draw() -> void:
	var u: float = size.y / 720.0
	if u <= 0.0:
		return
	_draw_card(u)
	if _results.is_empty():
		_draw_readout(u)
	_draw_keys(u)
	if _toast_t > 0.0:
		var a: float = clampf(_toast_t / 0.35, 0.0, 1.0)
		var f: Font = Kit.ui_font("heading")
		var px: int = Kit.type_px("lead", u)
		var w: float = f.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 44.0 * u
		var r := Rect2(Vector2((size.x - w) * 0.5, 22.0 * u), Vector2(w, 38.0 * u))
		_glass(r, 19.0 * u, a)
		draw_string(f, Vector2(r.position.x, r.get_center().y + 5.5 * u), _toast, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, Color(_toast_col, a))
	if _count_t > 0.0:
		var a2: float = clampf(_count_t / 0.25, 0.0, 1.0)
		var fb: Font = Kit.ui_font("title")
		var px2: int = Kit.type_px("hero", u) * 2
		draw_string(fb, Vector2(0.0, size.y * 0.42), _count, HORIZONTAL_ALIGNMENT_CENTER, size.x, px2, Color(1, 1, 1, a2))
	if _stage_t > 0.0 and _results.is_empty():
		_draw_stage_card(u)
	if not _results.is_empty():
		_draw_results(u)


func _draw_card(u: float) -> void:
	if card.is_empty() or String(card.get("title", "")).is_empty():
		return
	var ft: Font = Kit.ui_font("title")
	var fh: Font = Kit.ui_font("heading")
	var fb: Font = Kit.ui_font("text")
	var w: float = 380.0 * u
	var pad: float = 16.0 * u
	var lines: PackedStringArray = String(card.get("line", "")).split("\n")
	var h: float = pad * 2.0 + 18.0 * u + 26.0 * u + 18.0 * u * float(lines.size()) + 30.0 * u
	var r := Rect2(Vector2(22.0 * u, 20.0 * u), Vector2(w, h))
	_glass(r, 10.0 * u)
	var x: float = r.position.x + pad
	var y: float = r.position.y + pad + 11.0 * u
	draw_string(fh, Vector2(x, y), String(card.get("kicker", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.type_px("caption", u), Kit.UI_ACCENT)
	draw_string(fh, Vector2(x, y), String(card.get("clock", "")), HORIZONTAL_ALIGNMENT_RIGHT, w - pad * 2.0, Kit.type_px("caption", u), Kit.UI_INK_SOFT)
	y += 26.0 * u
	draw_string(ft, Vector2(x, y), String(card.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, Kit.type_px("subhead", u), Kit.UI_INK)
	y += 22.0 * u
	for ln in lines:
		draw_string(fb, Vector2(x, y), ln, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, Kit.type_px("body", u), Kit.UI_INK_SOFT)
		y += 18.0 * u
	# Progress: a bar and its count.
	var prog: Vector2 = card.get("progress", Vector2.ZERO)
	if prog.y > 0.0:
		var bar := Rect2(Vector2(x, y + 2.0 * u), Vector2(w - pad * 2.0 - 70.0 * u, 6.0 * u))
		draw_rect(bar, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(prog.x / prog.y, 0.0, 1.0), bar.size.y)), Kit.UI_ACCENT)
		draw_string(fh, Vector2(x, y + 9.0 * u), "%d / %d" % [int(prog.x), int(prog.y)], HORIZONTAL_ALIGNMENT_RIGHT, w - pad * 2.0, Kit.type_px("caption", u), Kit.UI_INK)
	var extra: String = String(card.get("note", ""))
	if not extra.is_empty():
		draw_string(fh, Vector2(x, r.end.y - 8.0 * u), extra, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, Kit.type_px("micro", u), Kit.UI_INK_DIM)


func _draw_readout(u: float) -> void:
	if player == null:
		return
	var f: Font = Kit.ui_font("heading")
	var px: int = Kit.type_px("caption", u)
	var w: float = player.global_position.w
	var parts: Array = ["W  %s%.2f m  of  ±%.1f" % ["+" if w >= 0.0 else "", w, w_limit], "SLICE  %d°" % int(round(float(player.call("slice_angle"))))]
	if not _current.is_empty():
		var off: float = slice_offset(_current[1])
		if absf(off) <= float(_current[3]):
			parts.append("IN YOUR SLICE")
		else:
			parts.append("TARGET  %.1f m %s" % [absf(off), "ANA  (E)" if off > 0.0 else "KATA  (Q)"])
	var text: String = "      ".join(parts)
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 32.0 * u
	var rr: Rect2 = Rect2(radar.position, radar.size)
	var r := Rect2(Vector2((size.x - tw) * 0.5, rr.position.y + rr.size.y * 0.12), Vector2(tw, 26.0 * u))
	_glass(r, 13.0 * u, 0.9)
	var col: Color = Kit.UI_INK
	draw_string(f, Vector2(r.position.x, r.get_center().y + 4.0 * u), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, col)
	# The W bar: where you stand in the bay's range through W.
	var bar := Rect2(Vector2(r.position.x + 16.0 * u, r.end.y + 4.0 * u), Vector2(tw - 32.0 * u, 3.0 * u))
	draw_rect(bar, Color(1, 1, 1, 0.18))
	var k: float = clampf((w + w_limit) / (2.0 * w_limit), 0.0, 1.0)
	draw_rect(Rect2(Vector2(bar.position.x + bar.size.x * k - 3.0 * u, bar.position.y - 3.0 * u), Vector2(6.0 * u, 9.0 * u)), Style.glow("w"))


func _draw_keys(u: float) -> void:
	if keys.is_empty():
		return
	var fk: Font = Kit.ui_font("key")
	var fl: Font = Kit.ui_font("text")
	var kpx: int = Kit.type_px("caption", u)
	var lpx: int = Kit.type_px("body", u)
	var row: float = 24.0 * u
	var kw_max: float = 0.0
	var lw_max: float = 0.0
	for it in keys:
		kw_max = maxf(kw_max, maxf(24.0 * u, fk.get_string_size(String(it[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, kpx).x + 14.0 * u))
		lw_max = maxf(lw_max, fl.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x)
	var w: float = kw_max + 10.0 * u + lw_max + 28.0 * u
	var h: float = row * float(keys.size()) + 16.0 * u
	var r := Rect2(Vector2(size.x - w - 22.0 * u, size.y - h - 22.0 * u), Vector2(w, h))
	_glass(r, 10.0 * u, 0.9)
	var y: float = r.position.y + 8.0 * u
	for it in keys:
		var kr := Rect2(Vector2(r.position.x + 14.0 * u, y + 2.0 * u), Vector2(kw_max, row - 4.0 * u))
		var kb := StyleBoxFlat.new()
		kb.draw_center = false
		kb.border_color = Color(1, 1, 1, 0.7)
		kb.set_border_width_all(int(maxf(1.0, 1.5 * u)))
		kb.set_corner_radius_all(int(5 * u))
		draw_style_box(kb, kr)
		draw_string(fk, Vector2(kr.position.x, kr.get_center().y + 4.0 * u), String(it[0]), HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, kpx, Kit.UI_INK)
		draw_string(fl, Vector2(kr.end.x + 10.0 * u, kr.get_center().y + 4.5 * u), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, Kit.UI_INK_SOFT)
		y += row


func _draw_stage_card(u: float) -> void:
	var a: float = clampf(_stage_t / 0.4, 0.0, 1.0) * clampf((2.0 - _stage_t) / 0.25 + 0.2, 0.0, 1.0)
	var ft: Font = Kit.ui_font("title")
	var fh: Font = Kit.ui_font("heading")
	var w: float = 520.0 * u
	var r := Rect2(Vector2((size.x - w) * 0.5, size.y * 0.30), Vector2(w, 86.0 * u))
	_glass(r, 12.0 * u, a)
	draw_string(fh, Vector2(r.position.x, r.position.y + 28.0 * u), _stage_sub, HORIZONTAL_ALIGNMENT_CENTER, w, Kit.type_px("caption", u), Color(Kit.UI_ACCENT, a))
	draw_string(ft, Vector2(r.position.x, r.position.y + 64.0 * u), _stage_title, HORIZONTAL_ALIGNMENT_CENTER, w, Kit.type_px("title", u), Color(1, 1, 1, a))


func _draw_results(u: float) -> void:
	var ft: Font = Kit.ui_font("title")
	var fh: Font = Kit.ui_font("heading")
	var fb: Font = Kit.ui_font("text")
	var fig: Font = Kit.ui_font("figure")
	var rows: Array = _results.get("rows", [])
	var w: float = 460.0 * u
	var h: float = 110.0 * u + 30.0 * u * float(rows.size()) + 40.0 * u
	var r := Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.42), Vector2(w, h))
	_glass(r, 14.0 * u)
	var x: float = r.position.x + 26.0 * u
	var y: float = r.position.y + 34.0 * u
	draw_string(fh, Vector2(x, y), String(_results.get("kicker", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.type_px("caption", u), Kit.UI_ACCENT)
	y += 34.0 * u
	draw_string(ft, Vector2(x, y), String(_results.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 52.0 * u, Kit.type_px("title", u), Kit.UI_INK)
	y += 34.0 * u
	for row in rows:
		draw_string(fb, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, Kit.type_px("body", u), Kit.UI_INK_SOFT)
		var vc: Color = Kit.UI_INK
		if row.size() > 2 and bool(row[2]):
			vc = Kit.UI_LIVE
		draw_string(fig, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, w - 52.0 * u, Kit.type_px("lead", u), vc)
		y += 30.0 * u
	draw_line(Vector2(x, y - 12.0 * u), Vector2(r.end.x - 26.0 * u, y - 12.0 * u), Color(1, 1, 1, 0.15), 1.0)
	draw_string(fh, Vector2(x, y + 10.0 * u), String(_results.get("hint", "")), HORIZONTAL_ALIGNMENT_LEFT, w - 52.0 * u, Kit.type_px("caption", u), Kit.UI_INK_SOFT)
