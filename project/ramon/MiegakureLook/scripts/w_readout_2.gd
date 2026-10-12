extends Control
## Slice-navigation gauge - grew out of a bare "W: 0.00" number (see git
## history/chat) once it became clear a raw number doesn't actually help you
## judge progress toward the wall's gap at a glance. Deliberately NOT a port
## of ShootingGalleryRamon's slice_radar_ramon.gd - that widget solves a
## much bigger problem (projecting several external tracked objects onto an
## oblique ellipse); this only ever needs to show one live position against
## one target zone, so a vertical gauge reads faster than a radar would.
##
## Draws:
## - A vertical bar spanning the platform's full w range (STRUCTURE_W_HALF_
##   EXTENT either side of 0), top = +w, bottom = -w.
## - The wall's gap window highlighted directly on the bar (in the wall's
##   own yellow) - the thing to actually aim for, not something to infer
##   from two separate numbers.
## - The ball's current w as a marker (in the ball's own orange).
## - A mode label ("Z-SLICE" / "W-SLICE" / "ROTATING...") - which world axis
##   "forward" currently means isn't otherwise obvious from the world
##   deformation alone, especially the first time you see this.

const BAR_WIDTH := 14.0
const BAR_HEIGHT := 180.0
const TOP_MARGIN := 24.0
const LEFT_MARGIN := 24.0
const FONT_SIZE := 20
const LABEL_FONT_SIZE := 16

const TRACK_COLOR := Color(1, 1, 1, 0.15)
const GAP_COLOR := Color(0.886, 0.949, 0.322, 0.85) # Matches ramdev_yellow, the wall's own color.
const BALL_COLOR := Color(1, 0.55, 0.1, 1) # Matches the ball's own albedo_color.
const TEXT_COLOR := Color(1, 1, 1, 0.9)

@onready var ball: CharacterBody4D = $"../Ball"
@onready var camera: MiegakureCamera2 = $"../CameraRig"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Maps a world w value to a screen y within the bar - top of the bar is
## +STRUCTURE_W_HALF_EXTENT, bottom is -STRUCTURE_W_HALF_EXTENT.
func _w_to_screen_y(world_w: float, bar_top: float, bar_bottom: float) -> float:
	var half_extent: float = MiegakureLookBuilder2.STRUCTURE_W_HALF_EXTENT
	var t: float = clampf((world_w + half_extent) / (half_extent * 2.0), 0.0, 1.0)
	return lerp(bar_bottom, bar_top, t)


func _mode_label() -> String:
	if camera.is_transitioning():
		return "ROTATING..."
	var angle: float = camera.get_current_angle_degrees()
	return "W-SLICE" if absf(angle - 90.0) < absf(angle) else "Z-SLICE"


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var bar_top: float = TOP_MARGIN + LABEL_FONT_SIZE + 6.0
	var bar_bottom: float = bar_top + BAR_HEIGHT
	var bar_rect := Rect2(LEFT_MARGIN, bar_top, BAR_WIDTH, BAR_HEIGHT)

	draw_string(font, Vector2(LEFT_MARGIN, TOP_MARGIN + LABEL_FONT_SIZE), _mode_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, TEXT_COLOR)
	draw_rect(bar_rect, TRACK_COLOR, true)

	# The gap window, highlighted directly on the bar - lower w maps to a
	# higher screen y, so the window's own min/max w don't map to min/max y
	# in the same order.
	var gap_w: float = MiegakureLookBuilder2.GATE_GAP_W
	var gap_half: float = MiegakureLookBuilder2.GATE_GAP_HALF_WIDTH
	var gap_y_a: float = _w_to_screen_y(gap_w - gap_half, bar_top, bar_bottom)
	var gap_y_b: float = _w_to_screen_y(gap_w + gap_half, bar_top, bar_bottom)
	var gap_rect := Rect2(LEFT_MARGIN, minf(gap_y_a, gap_y_b), BAR_WIDTH, absf(gap_y_a - gap_y_b))
	draw_rect(gap_rect, GAP_COLOR, true)

	# The ball's current position as a marker, plus its live numeric value.
	var ball_w: float = ball.global_position.w
	var ball_y: float = _w_to_screen_y(ball_w, bar_top, bar_bottom)
	draw_rect(Rect2(LEFT_MARGIN - 4.0, ball_y - 2.0, BAR_WIDTH + 8.0, 4.0), BALL_COLOR, true)
	draw_string(font, Vector2(LEFT_MARGIN + BAR_WIDTH + 12.0, ball_y + FONT_SIZE * 0.35), "%.2f" % ball_w, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)

	draw_string(font, Vector2(LEFT_MARGIN + BAR_WIDTH + 4.0, bar_top - 4.0), "+W", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, TEXT_COLOR)
	draw_string(font, Vector2(LEFT_MARGIN + BAR_WIDTH + 4.0, bar_bottom + LABEL_FONT_SIZE), "-W", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, TEXT_COLOR)
