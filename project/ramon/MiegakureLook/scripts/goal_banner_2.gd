extends Control
## Minimal "you win" banner for miegakure_look_2.tscn - the goal previously
## only printed to the debug console, which is invisible during normal play
## ("i hit the red pad but nothing changed"). Same pattern as
## ImpossibleBypass's bypass_hud.gd, kept as a separate local copy rather
## than a cross-folder reference - each prototype folder owns its own HUD
## script, matching how PhaseMaze's maze_hud.gd and ImpossibleBypass's
## bypass_hud.gd are already separate despite doing the same kind of thing.

const OVERLAY_COLOR := Color(0.0, 0.35, 0.0, 0.45)
const TEXT := "GOAL REACHED"
const SUBTEXT := "YOU WALKED THROUGH THE FOURTH DIMENSION."
const FONT_SIZE := 64
const SUBTEXT_FONT_SIZE := 20

var _visible: bool = false


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


func show_goal_reached() -> void:
	if _visible:
		return
	_visible = true
	queue_redraw()
