extends Control
## v3 "you win" banner for miegakure_look_3.tscn. Unchanged from
## goal_banner_2.gd - kept as a separate local copy rather than a cross-scene
## reference, matching how PhaseMaze's maze_hud.gd and ImpossibleBypass's
## bypass_hud.gd are already separate despite doing the same kind of thing.

const OVERLAY_COLOR := Color(0.0, 0.35, 0.0, 0.45)
const TEXT := "GOAL REACHED"
const SUBTEXT := "YOU WALKED THROUGH THE FOURTH DIMENSION."
const FONT_SIZE := 64
const SUBTEXT_FONT_SIZE := 20
const FOOTER_FONT_SIZE := 24

var _visible: bool = false
## What happens next, e.g. "LEVEL 2 OF 3 NEXT...". Empty when this scene is played
## standalone and nothing follows - which is the case for the older one-off
## miegakure_look_*.tscn scenes, so they keep working unchanged.
var _footer: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not _visible:
		return
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), OVERLAY_COLOR, true)
	var text_size: Vector2 = font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var center_pos: Vector2 = size * 0.5 - text_size * 0.5
	draw_string(font, center_pos, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1, 1, 1, 1))
	var subtext_size: Vector2 = font.get_string_size(SUBTEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SUBTEXT_FONT_SIZE)
	var subtext_pos := Vector2(size.x * 0.5 - subtext_size.x * 0.5, center_pos.y + text_size.y + 12.0)
	draw_string(font, subtext_pos, SUBTEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SUBTEXT_FONT_SIZE, Color(1, 1, 1, 0.85))

	if _footer.is_empty():
		return
	var footer_size: Vector2 = font.get_string_size(_footer, HORIZONTAL_ALIGNMENT_LEFT, -1, FOOTER_FONT_SIZE)
	var footer_pos := Vector2(size.x * 0.5 - footer_size.x * 0.5, subtext_pos.y + subtext_size.y + 34.0)
	draw_string(font, footer_pos, _footer, HORIZONTAL_ALIGNMENT_LEFT, -1, FOOTER_FONT_SIZE, Color(1, 1, 1, 1))


func _is_shown() -> bool:
	return _visible


## [param footer] is optional so the older miegakure_look_*.tscn builders, which
## call this with no arguments, keep working exactly as before.
func show_goal_reached(footer: String = "") -> void:
	if _visible:
		return
	_visible = true
	_footer = footer
	queue_redraw()
