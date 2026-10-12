extends Control
class_name DialogueBox4D

## The panel: a name tab, a line that reveals itself, and a list of replies.
##
## Presentation only. It knows nothing about who is speaking or what a choice means - it
## shows what it is handed and reports what was picked. The script lives in
## keeper_script.gd and the walking of it in dialogue_player_4d.gd.
##
## A BAND ALONG THE BOTTOM, NOT A BOX OVER HIS HEAD. Persona puts long dialogue in a wide
## short band and that is the right shape for three reasons. Wide means three sentences
## land in two lines, and two lines are read in one movement of the eye. Fixed to the
## screen means an orbiting camera and a slice rotation cannot drag it anywhere. And it
## leaves the middle of the frame - where the speaker actually is - completely clear.
##
## Above the head is still the right place for two words, which is what WorldTag4D does.
## The split is deliberate: short and diegetic up there, long and stable down here.
## LEFT_PANEL is kept for the case where the bottom of the screen is spoken for.
##
## WORD BY WORD, NOT LETTER BY LETTER. Letters arriving singly is a machine typing; whole
## words arriving is closer to someone speaking, because reading happens in words anyway
## and a half-drawn word is a small obstacle repeated forty times a line.
##
## VISIBLE_CHARACTERS, NOT STRING SLICING. Revealing by slicing re-wraps the paragraph on
## almost every frame, so words hop between lines as the ones after them arrive. Hiding
## characters from text that has already been shaped (VC_CHARS_AFTER_SHAPING) lays the
## whole thing out once and uncovers it, so nothing moves.

signal line_finished
signal chose(index: int)

enum Reveal { WORD, LETTER }
enum Layout { BOTTOM_BAND, LEFT_PANEL, OVER_HEAD, CINEMA }
enum ChoiceSide { RIGHT, LEFT }

@export var layout: Layout = Layout.OVER_HEAD
@export var reveal_mode: Reveal = Reveal.WORD

## Medium fast. Around 8 is an unhurried talker; 14 is someone in a hurry.
@export_range(1.0, 40.0, 0.5) var words_per_second: float = 8.0
## Only used in LETTER mode.
@export_range(5.0, 200.0, 1.0) var chars_per_second: float = 42.0
## How much faster the reveal runs while the advance key is held. Not a skip - the words
## still go past in order.
@export_range(1.5, 10.0, 0.5) var fast_multiplier: float = 4.0
## Whoever speaks under this name gets the player's panel colour, so your own echoed reply
## is never mistaken for his answer.
@export var player_name: String = "You"

@export_group("Band layout")
@export_range(0.0, 400.0, 1.0) var side_margin: float = 70.0
@export_range(0.0, 400.0, 1.0) var bottom_margin: float = 34.0
## Replies sit above the band in their own narrower panel. Which end they hug depends on
## what else the HUD has put in that corner - chickenpen keeps its slice radar bottom
## right, so there they go left.
@export var choice_side: ChoiceSide = ChoiceSide.RIGHT
@export_range(200.0, 1000.0, 10.0) var choice_width: float = 620.0
@export_range(0.0, 60.0, 1.0) var choice_gap: float = 12.0
## Minimum height of the text area. Two lines across a full-width band; it grows to three
## when a line needs it, upward, so the bottom edge never moves.
@export_range(30.0, 240.0, 2.0) var band_text_height: float = 66.0

@export_group("Over head")
## OVER_HEAD floats the whole panel above the speaker, the way a comic balloon would. It
## needs a camera and something at head height to project; without either it falls back to
## the band rather than drawing in a corner and looking broken.
@export var camera_path: NodePath
@export var head_anchor_path: NodePath
@export_range(200.0, 1000.0, 10.0) var over_head_width: float = 440.0
## Pixels between the top of his head and the bottom of the panel.
@export_range(0.0, 500.0, 1.0) var over_head_lift: float = 10.0
## Sideways from centred on him. Negative is left.
##
## Pushed a long way over, so the column of speech-and-replies hangs in clear air down the
## left of the frame rather than on top of whoever is talking. It still rides with his
## head vertically, which is what ties the words to the speaker; horizontally it has given
## up on being centred over him, because a column tall enough to hold four replies cannot
## be centred over a character without covering them.
@export_range(-900.0, 900.0, 5.0) var over_head_nudge_x: float = -450.0
@export_range(0.0, 200.0, 1.0) var over_head_margin: float = 24.0

@export_group("Panel layout")
@export_range(0.0, 900.0, 1.0) var margin_left: float = 40.0
@export_range(-600.0, 600.0, 1.0) var offset_from_middle: float = -110.0
@export_range(200.0, 1200.0, 10.0) var box_width: float = 640.0
@export_range(40.0, 300.0, 2.0) var text_height: float = 92.0

@export_group("Look")
@export var plate_color: Color = Color(0.93, 0.94, 0.95, 0.97)
@export var plate_text_color: Color = Color(0.09, 0.11, 0.14)
@export var body_color: Color = Color(0.13, 0.28, 0.42, 0.88)
@export var body_text_color: Color = Color(0.96, 0.98, 1.0)
## The player's own echoed line, tinted apart from his.
@export var player_body_color: Color = Color(0.20, 0.22, 0.28, 0.90)
@export var choice_color: Color = Color(0.74, 0.81, 0.88)
@export var choice_picked_color: Color = Color(1.0, 0.93, 0.62)
@export_range(10, 48, 1) var name_size: int = 20
@export_range(10, 48, 1) var text_size: int = 24
@export_range(10, 40, 1) var choice_size: int = 20

@export_group("Cinema")
## CINEMA is a film's subtitles rather than a game's dialogue box (Ramon, 29 Sept, of the
## dreamer: "more cinematic, like watching a movie. bigger text, 80 percent white text, so
## not super popping bright"). What it takes from film and TV subtitling - the Netflix and
## BBC style guides agree on nearly all of it - is: no box and no name plate, centred at the
## bottom of the picture, never more than two lines if it can help it, off-white rather than
## white, and a soft shadow instead of a background so it reads over a bright shot without
## a panel sitting on the image. Here it sits on the lower letterbox bar, where a film puts
## its subtitles when it has bars to put them on. Your own lines are in italics, as a
## subtitle marks a voice that is not the one on screen, and the replies are a quiet list in
## the left third rather than a menu. Sizes are shares of the screen's height, so it looks the same on
## every monitor.
@export_range(0.015, 0.08, 0.001) var cinema_text_ratio: float = 0.032
@export_range(0.3, 0.95, 0.01) var cinema_width_ratio: float = 0.72
## Where the top of the words sits, as a share of the screen's height from its top: just
## under the top edge of the lower letterbox bar (Ramon, 29 Sept: "a little bit higher ...
## align right under the top of the bottom letterbox bar"), so more lines grow down into
## the bar rather than off the screen.
@export_range(0.5, 1.0, 0.005) var cinema_top_ratio: float = 0.912
@export var cinema_text_color: Color = Color(0.96, 0.95, 0.92, 0.8)
@export var cinema_player_color: Color = Color(0.80, 0.86, 0.95, 0.72)
@export var cinema_choice_color: Color = Color(0.92, 0.92, 0.92, 0.5)
@export var cinema_choice_picked_color: Color = Color(1.0, 0.98, 0.94, 0.92)
@export_file("*.ttf") var cinema_font_path: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Regular.ttf"
@export_file("*.ttf") var cinema_player_font_path: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Italic.ttf"

@export_group("Font")
## Montserrat, and specifically the STATIC faces. The variable file's wght axis is inert in
## this build, and a variable font's default instance is its axis minimum - which for
## Montserrat is Thin. Assign the variable file and you silently get Thin.
@export_file("*.ttf") var name_font_path: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"
@export_file("*.ttf") var body_font_path: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Medium.ttf"
@export_file("*.ttf") var choice_font_path: String = "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Regular.ttf"

@export_group("Audio")
## Off until the real sounds arrive.
@export var audio_enabled: bool = false
@export_range(-60.0, 0.0, 1.0) var volume_db: float = -14.0
@export_range(1, 8, 1) var sound_every: int = 1

## Set from outside, every frame, while the advance key is held down.
var fast_forward: bool = false

var _speech: VBoxContainer
var _plate: PanelContainer
var _plate_label: Label
var _body_panel: PanelContainer
var _body_label: Label
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer
var _choice_labels: Array[Label] = []
var _choice_font: Font
var _camera: Camera4D
var _head: Node4D
var _rasp: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _cinema_font: Font
var _cinema_player_font: Font
var _cinema_size: int = 0

var _full: String = ""
var _speaker: String = ""
## Character index at the end of each word, so a word reveal is a lookup rather than a scan
## through the string every frame.
var _stops: PackedInt32Array = PackedInt32Array()
var _revealed: float = 0.0
var _sounded: int = 0
var _fade: float = 0.0
var _choices: Array = []
var _picked: int = 0
var _announced: bool = false


func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_camera = get_node_or_null(camera_path) as Camera4D
	_head = get_node_or_null(head_anchor_path) as Node4D
	_build()
	modulate.a = 0.0
	visible = false


## Swap which camera the over-head layout projects through.
##
## A staged conversation runs on a second camera standing in the world, and projecting a
## speaker's head through the orbit camera instead put the panel in the corner of the
## screen - correct arithmetic, wrong point of view. Passing null restores whatever the
## scene wired.
func use_camera(cam: Camera4D) -> void:
	_camera = cam if cam != null else get_node_or_null(camera_path) as Camera4D


# ------------------------------------------------------------------ public API

## Show a line. Calling this with what is already up does nothing, so a caller that
## recomputes its state every frame cannot make the speaker stammer.
func say(speaker: String, line: String) -> void:
	if speaker == _speaker and line == _full and visible:
		return
	_speaker = speaker
	_full = line
	_plate_label.text = speaker
	if layout == Layout.CINEMA:
		var own: bool = speaker == player_name
		_body_label.add_theme_color_override("font_color", cinema_player_color if own else cinema_text_color)
		_apply_font(_body_label, _cinema_player_font if own else _cinema_font)
	else:
		_body_panel.add_theme_stylebox_override("panel", _body_style(speaker == player_name))
	_body_label.text = line
	_body_label.visible_characters = 0
	_stops = _word_stops(line)
	_revealed = 0.0
	_sounded = 0
	_announced = false
	_clear_choices()
	visible = true


## Reveal the rest of the line at once.
func finish_line() -> void:
	_revealed = float(_total_steps())


func is_typing() -> bool:
	return _full != "" and _revealed < float(_total_steps())


## Offer replies. Nothing is shown while the line is still arriving, so reading and
## choosing never compete for the same moment.
func offer(choices: Array) -> void:
	_clear_choices()
	_choices = choices
	_picked = 0
	for i in _choices.size():
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", choice_size)
		_apply_font(label, _choice_font)
		if layout == Layout.CINEMA:
			_cinema_label(label, _cinema_font, maxi(int(round(float(_cinema_size) * 0.82)), 10))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_choice_box.add_child(label)
		_choice_labels.append(label)
	_paint_choices()
	_choice_panel.visible = not is_typing()


func has_choices() -> bool:
	return not _choices.is_empty()


func move_choice(step: int) -> void:
	if _choices.is_empty():
		return
	_picked = wrapi(_picked + step, 0, _choices.size())
	_paint_choices()


func confirm_choice() -> void:
	if _choices.is_empty() or not _choice_panel.visible:
		return
	var index: int = _picked
	_clear_choices()
	chose.emit(index)


func pick_index(index: int) -> void:
	if index < 0 or index >= _choices.size() or not _choice_panel.visible:
		return
	_picked = index
	confirm_choice()


func close() -> void:
	_full = ""
	_speaker = ""
	_clear_choices()


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	if _body_label == null:
		return

	# Faded by hand rather than with a Tween, because say() and close() can both land in
	# the same frame as a state change and a Tween would queue rather than replace.
	var want: float = 1.0 if _full != "" else 0.0
	_fade = move_toward(_fade, want, delta / 0.16)
	modulate.a = _fade
	visible = _fade > 0.001
	if _full == "":
		return

	var total: int = _total_steps()
	if _revealed < float(total):
		var rate: float = words_per_second if reveal_mode == Reveal.WORD else chars_per_second
		if fast_forward:
			rate *= fast_multiplier
		_revealed = minf(_revealed + rate * delta, float(total))
		_apply_reveal()
	elif not _announced:
		_announced = true
		_apply_reveal()
		_choice_panel.visible = not _choices.is_empty()
		line_finished.emit()
	_place()


func _total_steps() -> int:
	return _stops.size() if reveal_mode == Reveal.WORD else _full.length()


func _apply_reveal() -> void:
	var step: int = int(_revealed)
	var chars: int = step
	if reveal_mode == Reveal.WORD:
		chars = 0 if step <= 0 else _stops[mini(step, _stops.size()) - 1]
	_body_label.visible_characters = chars
	if _rasp != null and step - _sounded >= sound_every:
		_sounded = step
		_rasp.pitch_scale = _rng.randf_range(0.92, 1.12)
		_rasp.play()


## Character index at the end of each word. Trailing whitespace is swallowed into the word
## before it, so the gap appears with the word rather than a frame later.
func _word_stops(text: String) -> PackedInt32Array:
	var stops := PackedInt32Array()
	var n: int = text.length()
	var i: int = 0
	while i < n:
		while i < n and _is_gap(text[i]):
			i += 1
		if i >= n:
			break
		while i < n and not _is_gap(text[i]):
			i += 1
		while i < n and _is_gap(text[i]):
			i += 1
		stops.append(i)
	return stops


func _is_gap(c: String) -> bool:
	return c == " " or c == "\n" or c == "\t"


# ------------------------------------------------------------------ placement

## Laid out by hand every frame rather than by anchors, because the band grows upward from
## a fixed bottom edge as the text wraps to a third line, and the replies have to sit on
## top of whatever height it ended up at.
func _place() -> void:
	if _speech == null:
		return
	var screen: Vector2 = get_viewport_rect().size

	if layout == Layout.CINEMA:
		var size_now: int = maxi(int(round(screen.y * cinema_text_ratio)), 12)
		if size_now != _cinema_size:
			_cinema_size = size_now
			_body_label.add_theme_font_size_override("font_size", size_now)
			for label in _choice_labels:
				label.add_theme_font_size_override("font_size", maxi(int(round(float(size_now) * 0.82)), 10))
		var w: float = screen.x * cinema_width_ratio
		var h: float = _wrapped(_body_label, w)
		_speech.size = Vector2(w, h)
		# Hung from just under the top of the bar; a line too many to fit rises into the
		# picture rather than going off the screen.
		_speech.position = Vector2((screen.x - w) * 0.5, minf(screen.y * cinema_top_ratio, screen.y - h - 4.0))
		# The replies hang in the left third, clear of the middle of the frame, where the
		# shot puts whoever is talking and, over your shoulder, you.
		var cw: float = screen.x * 0.34
		var ch: float = _choice_height(cw)
		_choice_panel.size = Vector2(cw, ch)
		_choice_panel.position = Vector2(screen.x * 0.07, _speech.position.y - ch - screen.y * 0.04)

	elif layout == Layout.BOTTOM_BAND:
		var band_w: float = maxf(screen.x - side_margin * 2.0, 200.0)
		var speech_h: float = maxf(_speech_height(band_w), _plate_height() + BODY_PAD_Y + band_text_height)
		var choice_h: float = _choice_height(minf(choice_width, band_w))
		_speech.position = Vector2(side_margin, screen.y - bottom_margin - speech_h)
		_speech.size = Vector2(band_w, speech_h)

		var cw: float = minf(choice_width, band_w)
		var cx: float = side_margin if choice_side == ChoiceSide.LEFT else screen.x - side_margin - cw
		_choice_panel.size = Vector2(cw, choice_h)
		_choice_panel.position = Vector2(cx, _speech.position.y - choice_gap - choice_h)

	elif layout == Layout.OVER_HEAD and _camera != null and _head != null and _facing_camera():
		var w: float = minf(over_head_width, screen.x - over_head_margin * 2.0)
		var h: float = _speech_height(w)
		var ch: float = _choice_height(w)
		# Window pixels to canvas units - they differ when the window's content is scaled.
		var point: Vector2 = _camera.world_to_viewport(_head.global_position) * screen / Vector2(get_viewport().get_size())
		var x: float = clampf(point.x - w * 0.5 + over_head_nudge_x,
			over_head_margin, screen.x - w - over_head_margin)
		# Replies underneath, reading downward. What keeps them off the speaker is the
		# sideways nudge, not the stacking order. The speech's BOTTOM edge is what gets
		# pinned, not its top: the reply list appears and clears on every beat, and
		# pinning the top would make his line hop down and back up each time it did.
		var y: float = clampf(point.y - h - over_head_lift, over_head_margin,
			maxf(screen.y - h - ch - choice_gap - over_head_margin, over_head_margin))
		_speech.position = Vector2(x, y)
		_speech.size = Vector2(w, h)
		_choice_panel.size = Vector2(w, ch)
		_choice_panel.position = Vector2(x, y + h + choice_gap)

	else:
		var tall: float = maxf(_speech_height(box_width), _plate_height() + BODY_PAD_Y + text_height)
		_speech.position = Vector2(margin_left, screen.y * 0.5 + offset_from_middle)
		_speech.size = Vector2(box_width, tall)
		_choice_panel.size = Vector2(box_width, _choice_height(box_width))
		_choice_panel.position = Vector2(margin_left, _speech.position.y + tall + 8.0)


## Heights are measured from the FONT, not from get_combined_minimum_size().
##
## A container's minimum size is only right once it has been laid out at its new width,
## and _place sets that width in the same frame it reads it back. The result lagged by a
## frame and was wildly wrong on the frame the text changed: once as a panel tall enough
## to fill the screen, once as a four-reply list 28 pixels high. Asking the font how tall
## the wrapped string is answers now, exactly, and cannot disagree with what gets drawn.
const BODY_PAD_X: float = 40.0
const BODY_PAD_Y: float = 28.0
const CHOICE_PAD_X: float = 36.0
const CHOICE_PAD_Y: float = 28.0
const CHOICE_GAP_Y: float = 4.0


func _speech_height(width: float) -> float:
	return _plate_height() + BODY_PAD_Y + _wrapped(_body_label, width - BODY_PAD_X)


func _plate_height() -> float:
	return _plate.get_combined_minimum_size().y if _plate != null else 0.0


func _choice_height(width: float) -> float:
	if _choice_labels.is_empty():
		return 0.0
	var total: float = CHOICE_PAD_Y + CHOICE_GAP_Y * float(_choice_labels.size() - 1)
	for label in _choice_labels:
		total += _wrapped(label, width - CHOICE_PAD_X)
	return total


func _wrapped(label: Label, width: float) -> float:
	if label == null or label.text == "":
		return 0.0
	var font: Font = label.get_theme_font("font")
	if font == null:
		return float(label.get_theme_font_size("font_size")) * 1.4
	return font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
		maxf(width, 40.0), label.get_theme_font_size("font_size")).y


## Behind the camera projects to nonsense, so OVER_HEAD drops back to the band when the
## speaker is not in front of you. Better a panel in the usual place than one flung to a
## corner of the screen.
func _facing_camera() -> bool:
	var gap: Vector4 = _head.global_position - _camera.global_position
	return (-_camera.global_basis.z).dot(gap) > 0.05


# ------------------------------------------------------------------ building

func _build() -> void:
	var name_font: Font = _face(name_font_path, "name plate")
	var body_font: Font = _face(body_font_path, "body")
	_choice_font = _face(choice_font_path, "choices")

	_speech = VBoxContainer.new()
	_speech.name = "Speech"
	_speech.add_theme_constant_override("separation", 0)
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speech)

	# The name is a tab hugging the left edge, not a full-width header. Persona's does the
	# same and it matters: a plate as wide as the band reads as a second panel.
	var plate_row := HBoxContainer.new()
	plate_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.add_child(plate_row)

	_plate = PanelContainer.new()
	_plate.name = "Plate"
	_plate.add_theme_stylebox_override("panel", _plate_style())
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_row.add_child(_plate)

	_plate_label = Label.new()
	_plate_label.name = "Speaker"
	_plate_label.add_theme_font_size_override("font_size", name_size)
	_plate_label.add_theme_color_override("font_color", plate_text_color)
	_apply_font(_plate_label, name_font)
	_plate.add_child(_plate_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_row.add_child(spacer)

	_body_panel = PanelContainer.new()
	_body_panel.name = "Body"
	_body_panel.add_theme_stylebox_override("panel", _body_style(false))
	_body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.add_child(_body_panel)

	_body_label = Label.new()
	_body_label.name = "Line"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_body_label.add_theme_font_size_override("font_size", text_size)
	_body_label.add_theme_color_override("font_color", body_text_color)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(_body_label, body_font)
	_body_panel.add_child(_body_label)

	_choice_panel = PanelContainer.new()
	_choice_panel.name = "Choices"
	_choice_panel.add_theme_stylebox_override("panel", _choice_style())
	_choice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_panel.visible = false
	add_child(_choice_panel)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	_choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_panel.add_child(_choice_box)

	if layout == Layout.CINEMA:
		_cinema_font = _face(cinema_font_path, "cinema")
		_cinema_player_font = _face(cinema_player_font_path, "cinema player")
		_plate.visible = false
		var none := StyleBoxEmpty.new()
		_body_panel.add_theme_stylebox_override("panel", none)
		_choice_panel.add_theme_stylebox_override("panel", none)
		_choice_box.add_theme_constant_override("separation", 6)
		_cinema_size = maxi(int(round(get_viewport_rect().size.y * cinema_text_ratio)), 12)
		_cinema_label(_body_label, _cinema_font, _cinema_size)

	_place()

	if audio_enabled:
		_rasp = AudioStreamPlayer.new()
		_rasp.name = "Rasp"
		_rasp.stream = _make_drr()
		_rasp.volume_db = volume_db
		add_child(_rasp)


func _clear_choices() -> void:
	_choices = []
	for label in _choice_labels:
		label.queue_free()
	_choice_labels.clear()
	if _choice_panel != null:
		_choice_panel.visible = false


## A label dressed as a subtitle: centred, off-white, with a soft shadow and a faint dark
## edge in place of a box behind it.
func _cinema_label(label: Label, font: Font, size_px: int) -> void:
	_apply_font(label, font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", cinema_text_color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.35))
	label.add_theme_constant_override("outline_size", 2)


func _paint_choices() -> void:
	if layout == Layout.CINEMA:
		for i in _choice_labels.size():
			var on: bool = i == _picked
			_choice_labels[i].text = ("›  %s" if on else "    %s") % _choices[i]
			_choice_labels[i].add_theme_color_override("font_color", cinema_choice_picked_color if on else cinema_choice_color)
		return
	for i in _choice_labels.size():
		var on: bool = i == _picked
		_choice_labels[i].text = "%s %d. %s" % [">" if on else " ", i + 1, _choices[i]]
		_choice_labels[i].add_theme_color_override("font_color", choice_picked_color if on else choice_color)


## Loads a face, and says so loudly if it is missing rather than falling back to the theme
## font in silence - a panel that quietly stops being Montserrat is the kind of thing
## nobody notices until a capture is already in a deck.
func _face(path: String, what: String) -> Font:
	if path == "" or not ResourceLoader.exists(path):
		push_warning("DialogueBox4D: %s font not found at '%s' - falling back to the theme font." % [what, path])
		return null
	return load(path) as Font


func _apply_font(label: Label, font: Font) -> void:
	if font != null:
		label.add_theme_font_override("font", font)


func _plate_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = plate_color
	box.content_margin_left = 16.0
	box.content_margin_right = 20.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	return box


func _body_style(is_player: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = player_body_color if is_player else body_color
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	# The bright underline. It is what stops a translucent panel dissolving into a pale
	# field behind it.
	box.border_width_bottom = 3
	box.border_color = Color(0.82, 0.93, 1.0, 0.9)
	return box


## The replies: same family, darker, no underline, so they read as subordinate to the line
## rather than as a second speaker.
func _choice_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(body_color.r * 0.5, body_color.g * 0.5, body_color.b * 0.58, 0.92)
	# Matched to the speech panel's padding. Different insets made the two read as separate
	# widgets that happened to be near each other rather than as one thing being said.
	box.content_margin_left = 20.0
	box.content_margin_right = 20.0
	box.content_margin_top = 14.0
	box.content_margin_bottom = 14.0
	box.corner_radius_top_left = 3
	box.corner_radius_top_right = 3
	box.corner_radius_bottom_left = 3
	box.corner_radius_bottom_right = 3
	return box


# ------------------------------------------------------------------ placeholder sound

const RATE: int = 22050


## A short buzzing rasp. Off by default - a stand-in until the real voice sounds exist,
## kept only so the timing can be heard while tuning the reveal rate.
func _make_drr() -> AudioStreamWAV:
	return _render(0.05, func(u: float, rng: RandomNumberGenerator, phase: float) -> Array:
		var hz: float = 168.0 - 30.0 * u
		var next: float = phase + TAU * hz / float(RATE)
		var carrier: float = signf(sin(next)) * 0.34 + sin(next) * 0.22
		var rattle: float = 0.62 + 0.38 * sin(TAU * 4.5 * u)
		var sample: float = (carrier + rng.randf_range(-1.0, 1.0) * 0.09) * rattle
		return [sample * clampf(u / 0.03, 0.0, 1.0) * exp(-5.5 * u), next])


func _render(seconds: float, voice: Callable) -> AudioStreamWAV:
	var count: int = int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	var phase: float = 0.0
	for i in count:
		var result: Array = voice.call(float(i) / float(count), rng, phase)
		phase = float(result[1])
		data.encode_s16(i * 2, int(clampf(float(result[0]), -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
