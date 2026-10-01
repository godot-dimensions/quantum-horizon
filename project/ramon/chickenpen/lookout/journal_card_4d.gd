extends Control

## The Lookout's card in the pen's HUD: the field journal at a glance - pages found, photos
## in it, and the next thing to do - with J to open the book.
##
## IN THE RIGHT COLUMN, UNDER THE CINEMATICS CARD, in the controls card's style (the same
## see-through fill, hairline border, key chip and text sizes as pen_cinematics_card_4d.gd),
## right-aligned under it and as wide. The camera picker moves down under this one (the
## inherited scene repoints its under_path), so the column stays one stack.
##
## The card draws only; the book is journal_book_4d.gd, and J is its key.

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
		journal.connect("changed", queue_redraw)
		journal.connect("page_found", func(_id: String) -> void: _glow = 6.0)


func glow() -> void:
	_glow = 6.0


func _process(delta: float) -> void:
	if _glow > 0.0:
		_glow = maxf(_glow - delta, 0.0)
		queue_redraw()
	_place()


func _step() -> float:
	return float(text_size) + 9.0


func _lines() -> Array:
	if _lookout == null or _lookout.get("journal") == null:
		return ["", ""]
	var journal: Node = _lookout.get("journal")
	var pages: int = int(journal.call("pages_found"))
	var photos: int = int(journal.call("star_count"))
	var total: int = JOURNAL.PAGES.size()
	var first: String = "Pages  %d / %d     Photos  %d / %d" % [pages, total, photos, total * 4]
	var next: String = String(_lookout.call("next_hint")) if _lookout.has_method("next_hint") else ""
	return [first, next]


func _place() -> void:
	var font: Font = get_theme_default_font()
	var lines: Array = _lines()
	var widest: float = 22.0 + 8.0 + font.get_string_size("Field journal", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	for line in lines:
		widest = maxf(widest, 10.0 + font.get_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	var width: float = 14.0 + widest + 16.0
	var screen: Vector2 = get_viewport_rect().size
	var top: float = 18.0
	var right: float = screen.x - 22.0
	var above := get_node_or_null(above_path) as Control
	if above != null and above.visible:
		top = above.position.y + above.size.y + gap
		right = above.position.x + above.size.x
		width = maxf(width, above.size.x)
	var want := Vector2(width, 12.0 + _step() * 3.0 + 2.0)
	# The right column runs out of room on a small window at a big UI size: then the card
	# sits to the left of the one above, top edges level, rather than off the bottom.
	if above != null and above.visible and top + want.y > screen.y - 6.0:
		want.x = maxf(14.0 + widest + 16.0, 260.0)
		top = above.position.y
		right = above.position.x - gap
	if want != size:
		size = want
		queue_redraw()
	var at := Vector2(right - size.x, top)
	if at != position:
		position = at
		queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var ascent: float = font.get_ascent(text_size)
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	if _glow > 0.0:
		var a: float = clampf(_glow, 0.0, 1.0)
		draw_rect(Rect2(Vector2(14.0, -6.0), Vector2(34.0, 3.0)), STYLE.accent.lightened(0.3) * Color(1, 1, 1, a))
	var y: float = 12.0
	var key_size: int = maxi(text_size - 1, 8)
	var chip := Rect2(Vector2(14.0, y - 1.0), Vector2(22.0, float(text_size) + 5.0))
	draw_style_box(_chip, chip)
	var kw: float = font.get_string_size("J", HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x
	draw_string(font, Vector2(chip.position.x + (chip.size.x - kw) * 0.5, y + ascent), "J", HORIZONTAL_ALIGNMENT_LEFT, -1, key_size, Color(1, 1, 1, 0.9))
	draw_string(font, Vector2(chip.end.x + 8.0, y + ascent), "Field journal", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1, 1, 1, 0.72))
	y += _step()
	var lines: Array = _lines()
	draw_string(font, Vector2(24.0, y + ascent), String(lines[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1, 1, 1, 0.85))
	y += _step()
	draw_string(font, Vector2(24.0, y + ascent), String(lines[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
		STYLE.accent.lightened(0.45) * Color(1, 1, 1, 0.9))
