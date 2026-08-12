extends Control
## Static control legend for Phase Maze, plus a "you win" banner shown once
## phase_maze_builder.gd's goal Area4D reports the player has arrived - same
## "trigger() called externally by the thing that detects the event" split
## game_over_overlay_ramon.gd uses in the shooting gallery.

const LINES := [
	"MOVE: WASD   ANA/KATA (4TH AXIS): Q/E   LOOK: MOUSE",
	"",
	"WALLS ONLY BLOCK YOU AT YOUR CURRENT W - SHIFT W (Q/E) TO FIND THE GAP",
	"GREY/DARK WALLS ARE PERMANENT. YELLOW WALLS HAVE A HIDDEN GAP SOMEWHERE IN W",
	"WATCH THE PLAYER POSITION LABEL (TOP-LEFT) FOR YOUR CURRENT W",
	"REACH THE RED PAD TO FINISH",
]

const FONT_SIZE := 20
const LINE_SPACING := 26.0
const TEXT_COLOR := Color(1, 1, 1, 0.8)
const TOP_MARGIN := 46.0 # Below player.tscn's own PositionLabel, so they don't overlap.
const LEFT_MARGIN := 24.0

const WIN_OVERLAY_COLOR := Color(0.0, 0.35, 0.0, 0.45)
const WIN_TEXT := "MAZE COMPLETE"
const WIN_FONT_SIZE := 64
const WIN_SUBTEXT := "LOADING LEVEL 2..."
const WIN_SUBTEXT_FONT_SIZE := 20

## Level 1 always leads into level 2 once its goal is reached - long enough
## to read the banner, not so long it feels like waiting.
const NEXT_LEVEL_SCENE_PATH := "res://ramon/PhaseMaze/phase_maze_2.tscn"
const TRANSITION_DELAY_SEC := 2.5

var _win_visible: bool = false
var _transition_timer_sec: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _transition_timer_sec < 0.0:
		return
	_transition_timer_sec -= delta
	if _transition_timer_sec <= 0.0:
		get_tree().change_scene_to_file(NEXT_LEVEL_SCENE_PATH)


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
	_transition_timer_sec = TRANSITION_DELAY_SEC
	queue_redraw()
