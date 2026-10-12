extends Control

## The end of the talk, said in the middle of the screen.
##
## Ramon, 1 Oct: when Trym says "that's it" it "feels very empty, maybe it should have a
## prompt, end of presentation, floating in the middle". A line in the caption band is the
## presenter talking; this is the room saying the show is over, the way the house lights
## coming up do in a real theatre - which they also do now (theatre_show_4d.curtain), with
## Trym taking a small bow.
##
## IT ALSO SAYS WHAT YOU CAN DO NOW, because the end of a talk is the moment a player
## stops being told what to do: sit down again to watch it over, talk to Trym, or leave.
## One quiet line, under a rule, so the title is still the thing being read.
##
## Drawn in screen space, centred a little above the middle so it clears the caption band,
## sized from the viewport height like everything else in this room's UI.

@export_file("*.ttf") var title_font_file: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"
@export var title: String = "END OF PRESENTATION"
@export_range(0.1, 4.0, 0.1) var fade_seconds: float = 1.2
@export var title_color: Color = Color(0.86, 0.94, 1.0)
@export var rule_color: Color = Color(0.25, 0.85, 1.0, 0.85)
@export var line_color: Color = Color(0.72, 0.82, 0.92)
@export var band_color: Color = Color(0.02, 0.03, 0.06, 0.45)

var _font: Font
var _showing: bool = false
var _fade: float = 0.0
var _line: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(title_font_file) as Font if ResourceLoader.exists(title_font_file) else ThemeDB.fallback_font


func show_card(line: String) -> void:
	_line = line
	_showing = true


func hide_card() -> void:
	_showing = false


func is_showing() -> bool:
	return _showing


func _process(delta: float) -> void:
	var was: float = _fade
	_fade = move_toward(_fade, 1.0 if _showing else 0.0, delta / maxf(fade_seconds, 0.01))
	# One more redraw on the way to nothing, or the last faint frame stays on screen.
	if _fade > 0.0 or was > 0.0:
		queue_redraw()


func _draw() -> void:
	if _fade <= 0.01:
		return
	var screen: Vector2 = get_viewport_rect().size
	var a: float = _fade * _fade * (3.0 - 2.0 * _fade)
	var title_size: int = int(screen.y * 0.052)
	var line_size: int = int(screen.y * 0.021)
	var centre_y: float = screen.y * 0.38
	# A soft band behind it, so it reads against whatever the stage is doing.
	var band_h: float = title_size * 3.2
	draw_rect(Rect2(0.0, centre_y - band_h * 0.55, screen.x, band_h), Color(band_color, band_color.a * a))
	# Letter-spaced, the way a title card is set; the font has no tracking of its own.
	var spaced: String = ""
	for i in title.length():
		spaced += title[i] + (" " if i < title.length() - 1 else "")
	var wide: float = _font.get_string_size(spaced, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(_font, Vector2((screen.x - wide) * 0.5, centre_y), spaced,
		HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color(title_color, a))
	var rule_w: float = wide * 0.42
	var rule_y: float = centre_y + title_size * 0.42
	draw_line(Vector2((screen.x - rule_w) * 0.5, rule_y), Vector2((screen.x + rule_w) * 0.5, rule_y),
		Color(rule_color, rule_color.a * a), maxf(1.0, screen.y / 720.0))
	if _line != "":
		var fallback: Font = ThemeDB.fallback_font
		var line_w: float = fallback.get_string_size(_line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_size).x
		draw_string(fallback, Vector2((screen.x - line_w) * 0.5, rule_y + line_size * 2.0), _line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, line_size, Color(line_color, 0.9 * a))
