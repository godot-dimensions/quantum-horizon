extends Control

## The titles: act name, the finding, and the measured figure, across the bottom of the
## screen like a documentary lower third.
##
## SCREEN SPACE, NOT A SIGN IN THE ROOM. Text built as geometry has to be legible from
## wherever the player has wandered, which means either enormous letters or a sign that
## turns to follow you - and both look like a museum placard. A lower third is read the
## way titles are read, without anyone having to stand in the right place.
##
## IT FADES RATHER THAN CUTS. A caption that snaps in on the frame the act changes reads
## as a bug in the caption; the same words arriving over half a second read as direction.
##
## AND IT IS DRAWN, not built from Labels. Three lines of type with their own sizes and a
## rule between them is less code as four draw calls than as four Controls with anchors
## fighting a container, and it sizes itself to any viewport for free - which is the same
## argument the inventory belt makes.
##
## THE BAND IS MEASURED, NOT GUESSED. It was a fixed fraction of the screen height, and the
## longest act's third line fell off the bottom of it - the band has to be whatever the
## wrapped text actually needs, worked out before anything is drawn.

@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.45
## The least the band can be, as a fraction of screen height. It grows past this whenever
## the text needs the room.
@export_range(0.0, 0.6, 0.01) var band_height: float = 0.22
@export var band_color: Color = Color(0.03, 0.05, 0.09, 0.82)
@export var rule_color: Color = Color(0.30, 0.82, 1.0, 0.9)
@export var title_color: Color = Color(0.72, 0.93, 1.0)
@export var body_color: Color = Color(0.92, 0.94, 0.98)
@export var figure_color: Color = Color(1.0, 0.85, 0.42)
## The evidence tier, drawn as a small pill above the title. The deck this is drawn from
## tiers every claim and shows the tier, and the accent marks the GAP rather than the
## achievement - so a NOT YET MEASURED pill is the loudest thing on the slide, on purpose.
@export var tier_color: Color = Color(1.0, 0.82, 0.40)

var _title: String = ""
var _body: String = ""
var _figure: String = ""
var _tier: String = ""
var _fade: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_act(title: String, body: String, figure: String, tier: String = "") -> void:
	_title = title
	_body = body
	_figure = figure
	_tier = tier
	_fade = 0.0


func _process(delta: float) -> void:
	if _fade < 1.0:
		_fade = minf(_fade + delta / maxf(fade_seconds, 0.01), 1.0)
	queue_redraw()


func _draw() -> void:
	if _body == "" and _title == "":
		return
	var screen: Vector2 = get_viewport_rect().size
	var alpha: float = _fade
	var font: Font = ThemeDB.fallback_font
	var pad: float = screen.x * 0.07

	# Measure first. Every size is a fraction of screen height so the whole thing scales
	# with the window, and the band is then whatever those lines add up to.
	var title_size: int = int(screen.y * 0.030)
	var body_size: int = int(screen.y * 0.024)
	var figure_size: int = int(screen.y * 0.022)
	var lines: PackedStringArray = _wrap(font, _body, body_size, screen.x - pad * 2.0)
	# THE FIGURE WRAPS TOO. It used to be drawn as one unwrapped line, which was fine for
	# as long as every figure happened to be short enough - and then the walking creature
	# arrived with a two-clause one and the slide cut it off mid-word at the right edge.
	# Nothing measures a string against the window for you.
	var tail: PackedStringArray = _wrap(font, _figure, figure_size, screen.x - pad * 2.0)
	var lead: float = screen.y * 0.036
	var needs: float = screen.y * 0.030
	if _title != "":
		needs += lead * 1.15
	needs += lead * float(lines.size())
	if _tier != "":
		needs += lead * 0.78
	if _figure != "":
		needs += lead * (0.1 + float(tail.size()))
	var band: float = maxf(needs, screen.y * band_height)
	var top: float = screen.y - band

	draw_rect(Rect2(Vector2(0.0, top), Vector2(screen.x, band)),
		Color(band_color, band_color.a * alpha), true)
	draw_line(Vector2(pad, top), Vector2(screen.x - pad, top),
		Color(rule_color, rule_color.a * alpha), 2.0, true)

	# draw_string places a BASELINE, not a top edge, so the first line starts a line-height
	# down from the rule rather than level with it.
	var y: float = top + lead
	if _tier != "":
		# A pill, so it reads as a stamp on the claim rather than as more sentence.
		var pill_size: int = int(screen.y * 0.017)
		var wide: float = font.get_string_size(_tier, HORIZONTAL_ALIGNMENT_LEFT, -1,
			pill_size).x
		var box := Rect2(Vector2(pad, y - lead * 0.82),
			Vector2(wide + pad * 0.5, lead * 0.72))
		draw_rect(box, Color(tier_color, 0.16 * alpha), true)
		draw_rect(box, Color(tier_color, 0.75 * alpha), false, 1.0)
		draw_string(font, Vector2(pad + pad * 0.25, y - lead * 0.3), _tier,
			HORIZONTAL_ALIGNMENT_LEFT, -1, pill_size, Color(tier_color, alpha))
		y += lead * 0.78
	if _title != "":
		draw_string(font, Vector2(pad, y), _title, HORIZONTAL_ALIGNMENT_LEFT, -1,
			title_size, Color(title_color, alpha))
		y += lead * 1.15
	for line in lines:
		draw_string(font, Vector2(pad, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1,
			body_size, Color(body_color, alpha * 0.95))
		y += lead
	if _figure != "":
		y += lead * 0.2
		for line in tail:
			draw_string(font, Vector2(pad, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1,
				figure_size, Color(figure_color, alpha))
			y += lead


## Greedy wrap. Enough for three lines of a caption, and it never needs to be more.
func _wrap(font: Font, text: String, size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	if text == "":
		return out
	var line: String = ""
	for word in text.split(" ", false):
		var tryout: String = word if line == "" else line + " " + word
		if font.get_string_size(tryout, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width \
				and line != "":
			out.append(line)
			line = word
		else:
			line = tryout
	if line != "":
		out.append(line)
	return out
