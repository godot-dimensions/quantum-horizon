extends Control

## The Lookout's card in the pen's HUD: every way into the subgame, each on its own key, and
## the next thing to do (Ramon, 2 Oct: "it's better if all options to access stuff is already
## in the temporary hud, with keys to access that are previously unused").
##
##   Z  Camera         raise it on the deck, once Wren has given it to you
##   J  Field journal  pages and photos so far
##   B  Balloon        up by the tower once you have earned it; B takes you straight up
##   F  Climb          at the ladder (or down, at the gap in the deck's rail)
##
## A row you cannot use yet says why, dimmed. IN THE RIGHT COLUMN, UNDER THE CINEMATICS
## CARD, in the controls card's style (the same see-through fill, hairline border, key chips
## and text sizes as pen_cinematics_card_4d.gd), right-aligned under it and as wide; beside it
## when a small window at a big UI size leaves no room below. The camera picker hangs under
## this one (the inherited scene repoints its under_path).

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
const JOURNAL := preload("res://ramon/chickenpen/lookout/field_journal_4d.gd")

@export var lookout_path: NodePath = NodePath("../../Systems/Lookout")
@export var above_path: NodePath = NodePath("../Cinematics")
@export_range(9, 28, 1) var text_size: int = 13
@export_range(0.0, 1.0, 0.01) var panel_alpha: float = 0.34
@export_range(0.0, 40.0, 1.0) var gap: float = 10.0

var _panel: StyleBoxFlat
var _chip: StyleBoxFlat
var _lookout: Node
## A new page lights the card's accent bar for a while.
var _glow: float = 0.0
var _cached: Array = []
var _cached_at: int = -100000


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.04, 0.05, 0.08, panel_alpha)
	_panel.border_color = Color(1.0, 1.0, 1.0, 0.07)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(9)
	_chip = StyleBoxFlat.new()
	_chip.bg_color = Color(1.0, 1.0, 1.0, 0.11)
	_chip.border_color = Color(1.0, 1.0, 1.0, 0.20)
	_chip.set_border_width_all(1)
	_chip.set_corner_radius_all(4)
	_lookout = get_node_or_null(lookout_path)
	_hook.call_deferred()


func _hook() -> void:
	if _lookout == null:
		return
	var journal: Node = _lookout.get("journal")
	if journal != null:
		journal.connect("changed", func() -> void: _cached_at = -100000)
		journal.connect("page_found", func(_id: String) -> void: _glow = 6.0)


func glow() -> void:
	_glow = 6.0


func _process(delta: float) -> void:
	if _glow > 0.0:
		_glow = maxf(_glow - delta, 0.0)
	_place()
	queue_redraw()


func _step() -> float:
	return float(text_size) + 9.0


## [[key, label, status, usable], ...] and the next-thing line; worked out four times a second.
func _rows() -> Array:
	var now: int = Time.get_ticks_msec()
	if not _cached.is_empty() and now - _cached_at < 250:
		return _cached
	_cached_at = now
	_cached = _work_rows()
	return _cached


func _work_rows() -> Array:
	if _lookout == null or _lookout.get("journal") == null:
		return [[], ""]
	var journal: Node = _lookout.get("journal")
	var met: bool = bool(journal.call("flag", "met_wren"))
	var balloon: Node = _lookout.get("balloon")
	var balloon_up: bool = balloon != null and bool(balloon.get("ready_now"))
	var total: int = JOURNAL.PAGES.size()
	var climb: String = "at the ladder"
	var climb_now: bool = bool(_lookout.call("can_climb")) or bool(_lookout.call("can_climb_down"))
	if bool(_lookout.call("can_climb_down")):
		climb = "climb down, here"
	elif bool(_lookout.call("can_climb")):
		climb = "up the lookout, here"
	elif not met:
		climb = "meet Wren first"
	var rows: Array = [
		["Z", "Camera", ("up on the deck, Z" if bool(_lookout.get("station").call("can_raise")) else "on the deck, or in the balloon") if met else "Wren has it",
			met and bool(_lookout.get("station").call("can_raise"))],
		["J", "Field journal", "%d / %d pages, %d photos" % [int(journal.call("pages_found")), total, int(journal.call("star_count"))], true],
		["B", "Balloon", "up by the tower, B to go" if balloon_up else "not yet", balloon_up],
		["F", "Climb", climb, climb_now],
		["U", "Fly as the hawk", "the flock's own, any time on foot", true],
		["P", "Projection", "on: the cut, and a ghost of W" if bool(_lookout.get("projection")) else "off: the plain cut", true],
		["F4", "Developer overlay", "W depths, the slice, the numbers", true],
	]
	var next: String = String(_lookout.call("next_hint")) if _lookout.has_method("next_hint") else ""
	return [rows, next]


func _place() -> void:
	var font: Font = get_theme_default_font()
	var data: Array = _rows()
	var rows: Array = data[0]
	var widest: float = font.get_string_size("Lookout", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	for row in rows:
		var line: String = "%s    %s" % [row[1], row[2]]
		widest = maxf(widest, 22.0 + 10.0 + font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	widest = maxf(widest, font.get_string_size(String(data[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	var width: float = 14.0 + widest + 18.0
	var screen: Vector2 = get_viewport_rect().size
	var top: float = 18.0
	var right: float = screen.x - 22.0
	var above := get_node_or_null(above_path) as Control
	if above != null and above.visible:
		top = above.position.y + above.size.y + gap
		right = above.position.x + above.size.x
		width = maxf(width, above.size.x)
	var want := Vector2(width, 12.0 + _step() * float(rows.size() + 2) + 2.0)
	# The right column runs out of room on a small window at a big UI size: then the card
	# sits to the left of the one above, top edges level, rather than off the bottom.
	if above != null and above.visible and top + want.y > screen.y - 6.0:
		want.x = maxf(14.0 + widest + 18.0, 260.0)
		top = above.position.y
		right = above.position.x - gap
	# And never off the bottom: taller than the room beside it too (seven rows since round
	# three), it rises until it fits.
	top = minf(top, screen.y - 6.0 - want.y)
	if want != size:
		size = want
	var at := Vector2(right - size.x, top)
	if at != position:
		position = at


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var ascent: float = font.get_ascent(text_size)
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var accent: Color = STYLE.accent.lightened(0.35)
	if _glow > 0.0:
		draw_rect(Rect2(Vector2(14.0, -6.0), Vector2(34.0, 3.0)), accent * Color(1, 1, 1, clampf(_glow, 0.0, 1.0)))
	var data: Array = _rows()
	var y: float = 12.0
	draw_string(font, Vector2(14.0, y + ascent), "Lookout  ·  photography in W", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1, 1, 1, 0.72))
	y += _step()
	var key_size: int = maxi(text_size - 1, 8)
	for row in data[0]:
		var usable: bool = bool(row[3])
		var chip := Rect2(Vector2(14.0, y - 1.0), Vector2(22.0, float(text_size) + 5.0))
		draw_style_box(_chip, chip)
		var kw: float = font.get_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x
		draw_string(font, Vector2(chip.position.x + (chip.size.x - kw) * 0.5, y + ascent), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, key_size,
			Color(1, 1, 1, 0.9 if usable else 0.4))
		draw_string(font, Vector2(chip.end.x + 10.0, y + ascent), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1, 1, 1, 0.85 if usable else 0.42))
		var status: String = String(row[2])
		var sw: float = font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(font, Vector2(size.x - 16.0 - sw, y + ascent), status, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			(accent if usable and (String(row[0]) == "B" or String(row[0]) == "F") else Color(1, 1, 1, 0.5 if usable else 0.32)))
		y += _step()
	draw_string(font, Vector2(14.0, y + ascent), String(data[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, accent * Color(1, 1, 1, 0.9))
