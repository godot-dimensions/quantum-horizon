extends Label

## Frames per second, top left, permanently on.
##
## THIS IS AN R&D PROTOTYPE AND THE FRAME RATE IS THE RESULT. Everything in here that is
## interesting is also expensive - lofted creatures, a dual-contoured rock you can mine, a
## 4D slice you can rotate, a whole second scene held in memory beside the first - and the
## question the October gate actually asks is whether it RUNS. A number on screen the whole
## time means every playtest is also a measurement, and it costs one Label.
##
## AVERAGED, BECAUSE AN INSTANT READING IS NOISE. Engine.get_frames_per_second() is already
## smoothed but still jumps about; this holds a short window so the number is readable
## rather than a blur, and the worst frame in that window is kept beside it - which is the
## one that matters. A steady 60 with one 180 ms spike in it is not a steady 60, and the
## average alone would never show you the spike.
##
## IT READS LIKE THE REST OF THE COLUMN. It was briefly green-amber-red, which made it the
## loudest thing on the screen and the only element of the HUD not in the house style - a
## traffic light sitting on top of a card that is deliberately quiet. Same white as the
## objective and the locator underneath it, just set larger, because it is the one number
## you glance at rather than read.

@export_range(0.1, 3.0, 0.1) var window_seconds: float = 0.5
@export var show_worst: bool = true
## Bigger than the rows below it. The info card sets those to 14 and restyles everything
## in its list, so this is re-applied here - sibling _readys run in tree order and this
## node sits after the card, which is what makes it stick.
@export_range(10, 40, 1) var text_size: int = 20
@export var text_color: Color = Color(1.0, 1.0, 1.0, 0.86)

var _elapsed: float = 0.0
var _frames: int = 0
var _worst: float = 0.0


func _ready() -> void:
	# Keeps counting while everything else is switched off - the crossing disables whole
	# branches of the farm, and the frame rate inside the theatre is the half of the
	# measurement that is hardest to get any other way.
	process_mode = Node.PROCESS_MODE_ALWAYS
	text = ""
	_dress()


## Re-applied after the info card has had its go at the whole column.
func _dress() -> void:
	add_theme_font_size_override("font_size", text_size)
	add_theme_color_override("font_color", text_color)
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	add_theme_constant_override("shadow_offset_y", 1)


func _process(delta: float) -> void:
	_elapsed += delta
	_frames += 1
	_worst = maxf(_worst, delta)
	if _elapsed < window_seconds:
		return
	var fps: float = float(_frames) / _elapsed
	# The slowest single frame in the window, in milliseconds. A spike is the thing you
	# are looking for and an average is what hides it.
	var spike: float = _worst * 1000.0
	# BOTH NUMBERS PADDED. "worst 9 ms" and "worst 184 ms" are different widths, and the
	# frame counter is the widest line on the card - so an unpadded number moved the right
	# hand edge of the panel twice a second for as long as you looked at it.
	text = "%3.0f fps    worst %3.0f ms" % [fps, spike] if show_worst else "%3.0f fps" % fps
	if get_theme_font_size("font_size") != text_size:
		# The card restyles its whole list on load; if it ever does so again this puts the
		# size back rather than leaving one row of the column silently shrunk.
		_dress()
	_elapsed = 0.0
	_frames = 0
	_worst = 0.0
