extends Control
## v3 of the slice-navigation gauge. Draws the same thing w_readout_2.gd drew:
## a vertical bar spanning the platform's w range, the wall's gap window
## highlighted on it in the wall's own yellow, the ball's current w as a marker,
## and a mode label saying which world axis "forward" currently means.
##
## THE ACTUAL FIX IN v3, and the reason this file exists at all: v2's version
## NEVER RENDERED. It failed to parse with `Identifier "MiegakureLookBuilder2"
## not declared in the current scope` three times over, so the node got no
## script and the whole gauge was silently absent from every play session.
##
## Cause was not the code, it was the cache. Global class names resolve from
## .godot/global_script_class_cache.cfg, which ONLY the editor regenerates on a
## project scan. `class_name MiegakureLookBuilder2` was added with the editor
## closed, so it was never registered - measured directly: MiegakureCamera2 was
## in that file and MiegakureLookBuilder2 was not. Reading
## `MiegakureLookBuilder2.STRUCTURE_W_HALF_EXTENT` is a PARSE-time identifier
## lookup, so it takes the whole script down, and no runtime guard can catch it.
##
## So v3 reads the same three numbers off the builder NODE at runtime instead.
## An editor rescan would also have fixed v2, but this version cannot break that
## way again - and it survives the builder script being renamed or moved, which
## is the more common way this bites.

const BAR_WIDTH := 14.0
const BAR_HEIGHT := 180.0
const TOP_MARGIN := 24.0
const LEFT_MARGIN := 24.0
const FONT_SIZE := 20
const LABEL_FONT_SIZE := 16

const TRACK_COLOR := Color(1, 1, 1, 0.15)
const BALL_COLOR := Color(1, 0.55, 0.1, 1) # Matches the ball's own albedo_color.
const TEXT_COLOR := Color(1, 1, 1, 0.9)

@onready var ball: CharacterBody4D = $"../Ball"
@onready var camera: Camera4D = $"../CameraRig"
@onready var builder: Node4D = $"../Builder"

var _w_half_extent: float = 8.0
var _gap_w: float = 0.0
var _gap_half_width: float = 0.0
var _gap_color: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cached once rather than re-read every frame in _draw: these are level
	# constants, and an unsafe call per frame per value is pointless churn.
	_w_half_extent = builder.get_w_half_extent()
	_gap_w = builder.get_gap_w()
	_gap_half_width = builder.get_gap_half_width()
	# Asked for rather than hard-coded, so this one gauge serves both levels: the
	# wall level highlights its gap in the wall's yellow, the chasm level
	# highlights the bridge band in the bridge's cyan.
	_gap_color = builder.get_gap_color()


func _process(_delta: float) -> void:
	queue_redraw()


## Maps a world w value to a screen y within the bar - top of the bar is
## +_w_half_extent, bottom is -_w_half_extent.
func _w_to_screen_y(world_w: float, bar_top: float, bar_bottom: float) -> float:
	var t: float = clampf((world_w + _w_half_extent) / (_w_half_extent * 2.0), 0.0, 1.0)
	return lerp(bar_bottom, bar_top, t)


func _mode_label() -> String:
	if camera.is_transitioning():
		return "ROTATING..."
	var angle: float = camera.get_current_angle_degrees()
	return "W-SLICE" if absf(angle - 90.0) < absf(angle) else "Z-SLICE"


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# 26, not v2's 6. The "+W" cap sits just right of the bar's top, and at 6 it
	# landed on the same line as the mode label - "W-SLICE" is wide enough at 16px
	# to run underneath it, which rendered as "W-SWCE". Only visible now that the
	# gauge draws at all.
	var bar_top: float = TOP_MARGIN + LABEL_FONT_SIZE + 26.0
	var bar_bottom: float = bar_top + BAR_HEIGHT
	var bar_rect := Rect2(LEFT_MARGIN, bar_top, BAR_WIDTH, BAR_HEIGHT)

	draw_string(font, Vector2(LEFT_MARGIN, TOP_MARGIN + LABEL_FONT_SIZE), _mode_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, TEXT_COLOR)
	draw_rect(bar_rect, TRACK_COLOR, true)

	# The gap window, highlighted directly on the bar - lower w maps to a higher
	# screen y, so the window's own min/max w don't map to min/max y in the same
	# order.
	var gap_y_a: float = _w_to_screen_y(_gap_w - _gap_half_width, bar_top, bar_bottom)
	var gap_y_b: float = _w_to_screen_y(_gap_w + _gap_half_width, bar_top, bar_bottom)
	var gap_rect := Rect2(LEFT_MARGIN, minf(gap_y_a, gap_y_b), BAR_WIDTH, absf(gap_y_a - gap_y_b))
	draw_rect(gap_rect, _gap_color, true)

	# The ball's current position as a marker, plus its live numeric value.
	var ball_w: float = ball.global_position.w
	var ball_y: float = _w_to_screen_y(ball_w, bar_top, bar_bottom)
	draw_rect(Rect2(LEFT_MARGIN - 4.0, ball_y - 2.0, BAR_WIDTH + 8.0, 4.0), BALL_COLOR, true)
	draw_string(font, Vector2(LEFT_MARGIN + BAR_WIDTH + 12.0, ball_y + FONT_SIZE * 0.35), "%.2f" % ball_w, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)

	draw_string(font, Vector2(LEFT_MARGIN + BAR_WIDTH + 4.0, bar_top - 4.0), "+W", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, TEXT_COLOR)
	draw_string(font, Vector2(LEFT_MARGIN + BAR_WIDTH + 4.0, bar_bottom + LABEL_FONT_SIZE), "-W", HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, TEXT_COLOR)
