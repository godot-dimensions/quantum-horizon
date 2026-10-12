extends Control
## Static control legend for Impossible Bypass, plus a "you win" banner shown
## once impossible_bypass_builder.gd's goal Area4D reports the player has
## arrived. Same split as PhaseMaze's maze_hud.gd - the HUD only reacts to a
## trigger() called externally by the thing that detects the event.

const LINES := [
	"MOVE: WASD   ANA/KATA (4TH AXIS): Q/E   LOOK: MOUSE",
	"",
	"THE WALL AHEAD ONLY BLOCKS YOU AT YOUR CURRENT W",
	"SHIFT W (Q/E) UNTIL THE YELLOW WALL HAS A GAP, THEN WALK THROUGH",
	"WATCH THE PLAYER POSITION LABEL (TOP-LEFT) FOR YOUR CURRENT W",
	"REACH THE RED PAD TO FINISH",
]

const FONT_SIZE := 20
const LINE_SPACING := 26.0
const TEXT_COLOR := Color(1, 1, 1, 0.8)
const TOP_MARGIN := 46.0 # Below player.tscn's own PositionLabel, so they don't overlap.
const LEFT_MARGIN := 24.0

const WIN_OVERLAY_COLOR := Color(0.0, 0.35, 0.0, 0.45)
const WIN_TEXT := "BYPASS COMPLETE"
const WIN_SUBTEXT := "THE FOURTH DIRECTION IS REAL."
const WIN_FONT_SIZE := 64
const WIN_SUBTEXT_FONT_SIZE := 20

var _win_visible: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i in LINES.size():
		var pos := Vector2(LEFT_MARGIN, TOP_MARGIN + i * LINE_SPACING)
		draw_string(font, pos, LINES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)

	if _win_visible:
		draw_rect(Rect2(Vector2.ZERO, size), WIN_OVERLAY_COLOR, true)
		var text_size: Vector2 = font.get_string_size(WIN_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, WIN_FONT_SIZE)
		var center_pos: Vector2 = size * 0.5 - text_size * 0.5
		draw_string(font, center_pos, WIN_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, WIN_FONT_SIZE, Color(1, 1, 1, 1))
		var subtext_size: Vector2 = font.get_string_size(WIN_SUBTEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, WIN_SUBTEXT_FONT_SIZE)
		var subtext_pos := Vector2(size.x * 0.5 - subtext_size.x * 0.5, center_pos.y + text_size.y + 12.0)
		draw_string(font, subtext_pos, WIN_SUBTEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, WIN_SUBTEXT_FONT_SIZE, Color(1, 1, 1, 0.85))


func show_goal_reached() -> void:
	if _win_visible:
		return
	_win_visible = true
	queue_redraw()
