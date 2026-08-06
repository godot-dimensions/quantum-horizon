extends Control
## Level 2's HUD - same "static legend + externally-triggered win banner"
## split as maze_hud.gd, with wording that calls out this maze's actual
## branching structure (dead ends worth backing out of) instead of level 1's
## single corridor, and no further scene transition since this is currently
## the last built level.

const LINES := [
	"MOVE: WASD   ANA/KATA (4TH AXIS): Q/E   LOOK: MOUSE",
	"",
	"THIS MAZE ACTUALLY BRANCHES - SOME PATHS ARE DEAD ENDS, BACK OUT AND TRY ANOTHER",
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
const WIN_TEXT := "LEVEL 2 COMPLETE"
const WIN_FONT_SIZE := 64
const WIN_SUBTEXT := "THAT'S ALL FOR NOW, FOLKS!"
const WIN_SUBTEXT_FONT_SIZE := 20

## W-alignment gizmo: a "how close is my current w to this gate's hidden
## target" meter, active only near a gate wall (not full-time) and only
## showing magnitude, never direction - a hint about how hard you're
## searching, not a solve button. Reads phase_maze_2_builder.gd's own
## _gates data directly, same convention maze_hud.gd's own gizmo uses for
## level 1's gates.
const GIZMO_ACTIVATION_RADIUS := 4.5 # Meters in x/z - roughly "standing at a gated wall."
const GIZMO_MAX_W_DISTANCE := 10.0 # Beyond this w distance the meter reads empty.
const GIZMO_BAR_WIDTH := 340.0
const GIZMO_BAR_HEIGHT := 34.0
const GIZMO_BOTTOM_MARGIN := 90.0
const GIZMO_BORDER_COLOR := Color(1, 1, 1, 0.6)
const GIZMO_EMPTY_COLOR := Color(0.15, 0.15, 0.15, 0.55)
const GIZMO_FILL_COLOR_COLD := Color(0.5, 0.05, 0.05, 0.9)
const GIZMO_FILL_COLOR_HOT := Color(0.15, 0.9, 0.25, 1.0)
const GIZMO_LABEL := "W ALIGNMENT"
const GIZMO_LABEL_FONT_SIZE := 20

@onready var player: CharacterBody4D = $"../MazeWorld/Player"
@onready var builder: Node4D = $"../MazeWorld/MazeBuilder"

var _win_visible: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i in LINES.size():
		var pos := Vector2(LEFT_MARGIN, TOP_MARGIN + i * LINE_SPACING)
		draw_string(font, pos, LINES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)

	if not _win_visible:
		_draw_w_alignment_gizmo(font)

	if _win_visible:
		draw_rect(Rect2(Vector2.ZERO, size), WIN_OVERLAY_COLOR, true)
		var text_size: Vector2 = font.get_string_size(WIN_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, WIN_FONT_SIZE)
		var center_pos: Vector2 = size * 0.5 - text_size * 0.5
		draw_string(font, center_pos, WIN_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, WIN_FONT_SIZE, Color(1, 1, 1, 1))
		var subtext_size: Vector2 = font.get_string_size(WIN_SUBTEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, WIN_SUBTEXT_FONT_SIZE)
		var subtext_pos := Vector2(size.x * 0.5 - subtext_size.x * 0.5, center_pos.y + text_size.y + 12.0)
		draw_string(font, subtext_pos, WIN_SUBTEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, WIN_SUBTEXT_FONT_SIZE, Color(1, 1, 1, 0.85))


## Finds the nearest gate (by x/z distance only) and, if the player is
## standing close enough to it, draws a proximity bar for how near their
## current w is to that gate's gap_w - magnitude only, no sign, so it's a
## search aid rather than a direct answer.
func _draw_w_alignment_gizmo(font: Font) -> void:
	var gates: Array = builder._gates
	if gates.is_empty():
		return

	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var nearest: Dictionary = {}
	var nearest_dist: float = INF
	for gate in gates:
		var dist: float = player_xz.distance_to(gate.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = gate
	if nearest_dist > GIZMO_ACTIVATION_RADIUS:
		return

	var w_distance: float = absf(player.global_position.w - float(nearest.gap_w))
	var proximity: float = clampf(1.0 - w_distance / GIZMO_MAX_W_DISTANCE, 0.0, 1.0)

	var origin := Vector2(size.x * 0.5 - GIZMO_BAR_WIDTH * 0.5, size.y - GIZMO_BOTTOM_MARGIN)
	var bar_rect := Rect2(origin, Vector2(GIZMO_BAR_WIDTH, GIZMO_BAR_HEIGHT))
	draw_rect(bar_rect, GIZMO_EMPTY_COLOR, true)
	if proximity > 0.0:
		var fill_rect := Rect2(origin, Vector2(GIZMO_BAR_WIDTH * proximity, GIZMO_BAR_HEIGHT))
		draw_rect(fill_rect, GIZMO_FILL_COLOR_COLD.lerp(GIZMO_FILL_COLOR_HOT, proximity), true)
	draw_rect(bar_rect, GIZMO_BORDER_COLOR, false, 3.0)

	var label_size: Vector2 = font.get_string_size(GIZMO_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, GIZMO_LABEL_FONT_SIZE)
	var label_pos := Vector2(size.x * 0.5 - label_size.x * 0.5, origin.y - 10.0)
	draw_string(font, label_pos, GIZMO_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, GIZMO_LABEL_FONT_SIZE, Color(1, 1, 1, 0.85))


func show_goal_reached() -> void:
	if _win_visible:
		return
	_win_visible = true
	queue_redraw()
