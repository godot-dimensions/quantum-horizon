extends Control

## THE LOOK PROMPT AND ITS PRAISE (discovery/dream_shifter/pen_look_guide_4d.gd shows them).
##
## THE PROMPT. Ramon, 9 Oct: "a super obvious, entirely impossible to miss prompt in the main scene that tells you to
## click the toggle button between the different views, currently it's a suggestion that's entirely drowned out by all
## the stuff on screen considering how important it is." Until then the only mention was the Look row's two small
## chips on the left-hand panel and one line of the controls card. So this one does not wait to be noticed:
## - it arrives in the middle of the screen, big (the key, "Switch the view", what the two modes are);
## - after a moment it flies to the Look row and docks beside it, an arrow pointing at the Dev and Art buttons, which
##   get a pulsing ring, so you learn where the button lives as well as the key;
## - docked, it keeps breathing (a slow pulse of its edge and the ring) until you switch, by the key or a click;
## - switching ticks it off and it goes.
## It steps aside (fades) while you talk to someone or a film plays, and comes back after.
##
## THE PRAISE. "the first time the player manually presses I themselves, give them a short reinforcing prompt ... 'Well
## done. Now you're starting to understand how we work.' 'This is a prototype world: one part discovery, one part
## construction.'" A card where the prompt was docked, a ring with a tick, for a few seconds.
##
## Drawn in _draw, on the guide's own layer; sizes in 1080p units (u), so it follows the HUD's UI size (the window's
## content scale). NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")

## The look's key, for the keycap.
var key: String = "I"
## The Dev and Art buttons on the left-hand panel (their union rect is what the docked card points at), or empty.
var buttons: Array = []
## Seconds in the middle before it flies to the panel.
var stage_seconds: float = 2.6
var praise_seconds: float = 6.0

var _on: bool = false
var _a: float = 0.0
var _quiet: float = 0.0
var _hush: bool = false
var _t: float = 0.0
var _done: float = -1.0
var _praise: float = -1.0
var _intro: bool = true
var _drew: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Shows the prompt: [param intro] true arrives in the middle first, false appears docked.
func show_prompt(intro: bool = true) -> void:
	if _on and _done < 0.0:
		return
	_on = true
	_intro = intro
	_t = 0.0 if intro else stage_seconds + 1.0
	_done = -1.0


## Takes it down: [param ticked] true when the player switched (it ticks off first).
func hide_prompt(ticked: bool) -> void:
	if not _on:
		return
	if ticked:
		_done = 0.9
	else:
		_on = false


func showing() -> bool:
	return _on


## Steps aside while something else has the screen (talk, a film), and comes back after.
func set_hush(on: bool) -> void:
	_hush = on


func praise() -> void:
	_praise = praise_seconds


func praising() -> bool:
	return _praise > 0.0


func _process(delta: float) -> void:
	size = get_viewport_rect().size
	_t += delta
	_quiet = move_toward(_quiet, 1.0 if _hush else 0.0, delta * 4.0)
	if _done >= 0.0:
		_done -= delta
		if _done <= 0.0:
			_done = -1.0
			_on = false
	_a = move_toward(_a, 1.0 if _on else 0.0, delta * 3.0)
	if _praise > -1.0:
		_praise -= delta
	# Redrawn while anything shows, and once more after it has gone (a canvas keeps its last drawing).
	var showing_now: bool = _a > 0.0 or _praise > -0.5
	if showing_now or _drew:
		queue_redraw()
	_drew = showing_now


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The Dev and Art buttons' rect on screen, or an empty one.
func _row() -> Rect2:
	var out := Rect2()
	for b in buttons:
		var c := b as Control
		if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		out = r if out.size == Vector2.ZERO else out.merge(r)
	return out


func _draw() -> void:
	if size.y < 100.0:
		return
	var u: float = size.y / 1080.0
	if _a > 0.001:
		_draw_prompt(u, _a * (1.0 - _quiet))
	if _praise > -0.5:
		_draw_praise(u)


func _draw_prompt(u: float, a: float) -> void:
	if a <= 0.001:
		return
	var screen: Vector2 = size
	var row: Rect2 = _row()
	var card_size := Vector2(430.0, 132.0) * u
	var centre_pos := Vector2((screen.x - card_size.x) * 0.5, screen.y * 0.12)
	var dock_pos: Vector2
	if row.size != Vector2.ZERO:
		dock_pos = Vector2(row.end.x + 30.0 * u, row.get_center().y - card_size.y * 0.5 * 0.86)
	else:
		dock_pos = Vector2(screen.x * 0.03, screen.y * 0.30)
	# In the middle for stage_seconds (scale 1.15), then flying 0.8 s to the dock (scale 0.86).
	var fly: float = _ease((_t - stage_seconds) / 0.8) if _intro else 1.0
	var s: float = lerpf(1.15, 0.86, fly)
	var pos: Vector2 = centre_pos.lerp(dock_pos, fly)
	var grow: float = 1.0 + 0.035 * sin(_t * TAU * 0.8) * fly
	var cs: Vector2 = card_size * s * grow
	var card := Rect2(pos - (cs - card_size * s) * 0.5, cs)
	# Arriving: a soft pop.
	var pop: float = _ease(_t / 0.35) if _intro else 1.0
	a *= pop
	var accent := Style.UI_ACCENT
	var beat: float = 0.5 + 0.5 * sin(_t * TAU * 0.8)
	# The glow behind it, and the card.
	for k in 3:
		var g: float = (3.0 - float(k)) * 7.0 * u
		var halo := StyleBoxFlat.new()
		halo.bg_color = Color(accent, (0.05 + 0.05 * beat) * a)
		halo.set_corner_radius_all(int(20.0 * u + g))
		draw_style_box(halo, card.grow(g))
	var glass := Style.glass_box(16.0 * u * s, a, 0.92)
	glass.border_color = Color(accent, (0.55 + 0.45 * beat) * a)
	glass.set_border_width_all(int(maxf(2.0, 2.5 * u)))
	draw_style_box(glass, card)
	# The key, big, on the left; the words on the right.
	var k_size: Vector2 = Vector2(78.0, 78.0) * u * s
	var k_rect := Rect2(card.position + Vector2(24.0 * u * s, (card.size.y - k_size.y) * 0.5 - 4.0 * u * s), k_size)
	_keycap(k_rect, key, int(44.0 * u * s), a)
	var tx: float = k_rect.end.x + 22.0 * u * s
	var tw: float = card.end.x - tx - 16.0 * u * s
	var fb: Font = LabPrint.font("black")
	var fbo: Font = LabPrint.font("bold")
	var fs: Font = LabPrint.font("body")
	draw_string(fb, Vector2(tx, card.position.y + 44.0 * u * s), "Switch the view", HORIZONTAL_ALIGNMENT_LEFT, tw, int(28.0 * u * s), Color(1, 1, 1, a))
	draw_string(fbo, Vector2(tx, card.position.y + 76.0 * u * s), "Dev Mode  /  Art Mode", HORIZONTAL_ALIGNMENT_LEFT, tw, int(18.0 * u * s), Color(accent, a))
	var how: String = "Press %s, or click Dev or Art here." % key if row.size != Vector2.ZERO else "Press %s to see the world both ways." % key
	draw_string(fs, Vector2(tx, card.position.y + 104.0 * u * s), how, HORIZONTAL_ALIGNMENT_LEFT, tw, int(15.0 * u * s), Color(1, 1, 1, 0.80 * a))
	# Docked: the arrow at the buttons and the ring round them.
	if row.size != Vector2.ZERO and fly > 0.0:
		var ra: float = a * fly
		var tip := Vector2(row.end.x + 8.0 * u, row.get_center().y)
		var base_x: float = card.position.x - 2.0 * u
		var nudge: float = sin(_t * TAU * 1.2) * 4.0 * u
		var pts := PackedVector2Array([tip + Vector2(nudge, 0.0), Vector2(base_x + nudge, tip.y - 13.0 * u), Vector2(base_x + nudge, tip.y + 13.0 * u)])
		draw_colored_polygon(pts, Color(accent, ra))
		var ring := StyleBoxFlat.new()
		ring.bg_color = Color(accent, 0.10 * ra * beat)
		ring.border_color = Color(accent, (0.6 + 0.4 * beat) * ra)
		ring.set_border_width_all(int(maxf(2.0, 3.0 * u)))
		ring.set_corner_radius_all(int(8.0 * u))
		ring.anti_aliasing = true
		draw_style_box(ring, row.grow(6.0 * u + 3.0 * u * beat))
	# Ticked: a white flash over the card.
	if _done >= 0.0:
		var flash: float = clampf(_done / 0.9, 0.0, 1.0)
		var tick := StyleBoxFlat.new()
		tick.bg_color = Color(Style.UI_LIVE, 0.35 * flash * a)
		tick.set_corner_radius_all(int(16.0 * u * s))
		draw_style_box(tick, card)


func _draw_praise(u: float) -> void:
	var into: float = praise_seconds - _praise
	var a: float = _ease(into / 0.35) * _ease((_praise + 0.5) / 0.6)
	if a <= 0.001:
		return
	var screen: Vector2 = size
	# Where the prompt was docked, beside the Look row (the prompt ticks off and becomes this), clear of the player
	# and the to-do list; without the row, high on the left.
	var cs := Vector2(780.0, 150.0) * u
	var rise: float = (1.0 - _ease(into / 0.45)) * 18.0 * u
	var row: Rect2 = _row()
	var at := Vector2(screen.x * 0.16, screen.y * 0.19)
	if row.size != Vector2.ZERO:
		at = Vector2(row.end.x + 30.0 * u, row.get_center().y - cs.y * 0.5)
	var card := Rect2(at + Vector2(0.0, rise), cs)
	var glass := Style.glass_box(18.0 * u, a, 0.9)
	glass.border_color = Color(Style.UI_LIVE, 0.55 * a)
	glass.set_border_width_all(int(maxf(1.0, 2.0 * u)))
	draw_style_box(glass, card)
	# The tick in a ring, drawn on as it arrives.
	var c := card.position + Vector2(68.0 * u, cs.y * 0.5)
	var draw_on: float = _ease((into - 0.15) / 0.5)
	draw_arc(c, 30.0 * u, -PI * 0.5, -PI * 0.5 + TAU * draw_on, 64, Color(Style.UI_LIVE, a), 4.0 * u, true)
	if draw_on > 0.4:
		var tk: float = _ease((draw_on - 0.4) / 0.6)
		var p0 := c + Vector2(-13.0, 1.0) * u
		var p1 := c + Vector2(-4.0, 10.0) * u
		var p2 := c + Vector2(14.0, -9.0) * u
		draw_line(p0, p0.lerp(p1, minf(tk * 2.0, 1.0)), Color(Style.UI_LIVE, a), 4.5 * u, true)
		if tk > 0.5:
			draw_line(p1, p1.lerp(p2, (tk - 0.5) * 2.0), Color(Style.UI_LIVE, a), 4.5 * u, true)
	var tx: float = card.position.x + 122.0 * u
	var tw: float = card.end.x - tx - 24.0 * u
	draw_string(LabPrint.font("black"), Vector2(tx, card.position.y + 48.0 * u), "Well done.", HORIZONTAL_ALIGNMENT_LEFT, tw, int(30 * u), Color(1, 1, 1, a))
	draw_string(LabPrint.font("bold"), Vector2(tx, card.position.y + 82.0 * u), "Now you are starting to understand how we work.", HORIZONTAL_ALIGNMENT_LEFT, tw, int(18 * u), Color(1, 1, 1, a))
	draw_string(LabPrint.font("body"), Vector2(tx, card.position.y + 114.0 * u), "This is a prototype world: one part discovery, one part construction.", HORIZONTAL_ALIGNMENT_LEFT, tw, int(15 * u), Color(1, 1, 1, 0.72 * a))


func _keycap(rect: Rect2, label: String, px: int, alpha: float) -> void:
	var r: int = int(rect.size.y * 0.14)
	var lip := StyleBoxFlat.new()
	lip.bg_color = Color(0.20, 0.21, 0.23, alpha)
	lip.set_corner_radius_all(r)
	lip.anti_aliasing = true
	draw_style_box(lip, Rect2(rect.position + Vector2(0.0, rect.size.y * 0.09), rect.size))
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.96, 0.96, 0.95, alpha)
	face.set_corner_radius_all(r)
	face.anti_aliasing = true
	draw_style_box(face, rect)
	var f: Font = LabPrint.font("black")
	draw_string(f, Vector2(rect.position.x, rect.get_center().y + f.get_ascent(px) * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, px, Color(0.12, 0.12, 0.13, alpha))
