extends Control
## Ramon-only: vertical charge power bar for the hold-to-charge fire
## mechanic (see hitscan_weapon_ramon.gd). Reads the weapon's own
## _charge_fraction/_is_expired every frame rather than owning any charge
## state itself - same "dumb readout reading a sibling's own state" split
## slice_radar.gd already uses for the spawners it displays.

const BAR_WIDTH := 40.0
const BAR_HEIGHT := 280.0
const LEFT_MARGIN := 36.0
const BORDER_COLOR := Color(1, 1, 1, 0.6)
const EMPTY_COLOR := Color(0.15, 0.05, 0.05, 0.55)
const FILL_COLOR_LOW := Color(0.5, 0.05, 0.05, 0.9)
const FILL_COLOR_FULL := Color(1.0, 0.15, 0.1, 1.0)
const EXPIRED_COLOR := Color(0.55, 0.55, 0.55, 0.85)
const FULL_CAP_COLOR := Color(1, 1, 1, 0.9)
const HINT_TEXT := "HOLD LEFT CLICK TO CHARGE - RELEASE TO FIRE"
const HINT_COLOR := Color(1, 1, 1, 0.75)
const HINT_FONT_SIZE := 15

@onready var weapon: Node = $"../HitscanWeapon"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var origin := Vector2(LEFT_MARGIN, size.y * 0.5 - BAR_HEIGHT * 0.5)
	var bar_rect := Rect2(origin, Vector2(BAR_WIDTH, BAR_HEIGHT))
	draw_rect(bar_rect, EMPTY_COLOR, true)

	var fraction: float = weapon._charge_fraction
	var expired: bool = weapon._is_expired
	if fraction > 0.0:
		var fill_height: float = BAR_HEIGHT * fraction
		var fill_rect := Rect2(Vector2(origin.x, origin.y + BAR_HEIGHT - fill_height), Vector2(BAR_WIDTH, fill_height))
		var color: Color = EXPIRED_COLOR if expired else FILL_COLOR_LOW.lerp(FILL_COLOR_FULL, fraction)
		draw_rect(fill_rect, color, true)

	draw_rect(bar_rect, BORDER_COLOR, false, 2.0)
	# A bright cap line at the top once truly full (and not yet expired) - a
	# clear "release now" cue distinct from the fill color alone.
	if fraction >= 0.999 and not expired:
		draw_rect(Rect2(origin.x - 2.0, origin.y - 4.0, BAR_WIDTH + 4.0, 3.0), FULL_CAP_COLOR, true)

	var font: Font = ThemeDB.fallback_font
	var text_pos := Vector2(origin.x, origin.y + BAR_HEIGHT + 22.0)
	draw_string(font, text_pos, HINT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_FONT_SIZE, HINT_COLOR)
