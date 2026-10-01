extends Control

## The pen's CINEMATICS menu - Ramon, 1 Oct: "in the chicken pen Hud, i want there to be a
## small bracket called cinematics, with a simple listing"; then "press k and then enter on
## the right one to start. no more numbers"; then "place the menu, as its own menu, under
## the ui size dial size ... make it match style".
##
## ITS OWN CARD, UNDER THE CONTROLS CARD, in that card's style: the same see-through fill,
## hairline border and corner, the same key chips and text, right-aligned under it and as
## wide. If the controls card is hidden (its H), this moves up under the little hint that
## replaces it.
##
## ALWAYS SHOWN; K STEPS IN AND OUT. In it - the card lit, the accent bar above it - the
## up and down arrows move the highlight and Enter plays the highlighted cinematic, or says
## the placeholder is not made yet. K or Escape steps out, and Escape then means only that,
## not the camera rig's "free the cursor, then quit". No number keys: those stay the
## inventory belt's (1 is the pickaxe).
##
## The cinematic plays here in the pen (pen_cinematics_4d.gd) and hands the pen back where
## you were when it ends or Escape skips it. K does nothing mid-conversation, or away in the
## cave or the cinema, where the farm and its flock are asleep.
##
## AFTER THE INVENTORY UNDER UI, on purpose: _input reaches later nodes first, so while you
## are in it this hears the arrows and Enter before the belt and the cards before it do.

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
## [title, cinematic name - "" for a placeholder]
const LISTING := [
	["Flight of the 4D Starlings", "murmuration"],
	["Mountain Range", ""],
]
const OPEN_HINT := "Up / Down choose  ·  Enter plays  ·  Esc leaves"

@export var cinematics_path: NodePath = NodePath("../../Cinematics")
@export var flock_path: NodePath = NodePath("../../World/Flock")
@export var player_path: NodePath = NodePath("../../Player")
@export var controls_path: NodePath = NodePath("../Controls")
@export var toggle_key: Key = KEY_K
## The controls card's, so the two read as one set.
@export_range(9, 28, 1) var text_size: int = 13
@export_range(0.0, 1.0, 0.01) var panel_alpha: float = 0.34
@export_range(0.0, 80.0, 1.0) var right_margin: float = 22.0
@export_range(0.0, 40.0, 1.0) var gap: float = 10.0
## How long "not made yet" shows after Enter on a placeholder.
@export_range(0.5, 5.0, 0.1, "suffix:s") var note_seconds: float = 2.0

var _open: bool = false
var _chosen: int = 0
var _note: float = 0.0
var _panel: StyleBoxFlat
var _chip: StyleBoxFlat
var _lit: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.04, 0.05, 0.08, panel_alpha)
	_panel.border_color = Color(1.0, 1.0, 1.0, 0.07)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(9)
	# pen_controls_4d.gd's key chip.
	_chip = StyleBoxFlat.new()
	_chip.bg_color = Color(1.0, 1.0, 1.0, 0.11)
	_chip.border_color = Color(1.0, 1.0, 1.0, 0.20)
	_chip.set_border_width_all(1)
	_chip.set_corner_radius_all(4)
	# The highlighted row, while you are in the card.
	_lit = StyleBoxFlat.new()
	_lit.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	_lit.set_corner_radius_all(4)


func is_open() -> bool:
	return _open


func chosen() -> int:
	return _chosen


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == toggle_key:
		if _open:
			_set_open(false)
			get_viewport().set_input_as_handled()
		elif _can_open():
			_set_open(true)
			get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	match key.keycode:
		KEY_ESCAPE:
			_set_open(false)
		KEY_UP:
			_chosen = posmod(_chosen - 1, LISTING.size())
			_note = 0.0
			queue_redraw()
		KEY_DOWN:
			_chosen = posmod(_chosen + 1, LISTING.size())
			_note = 0.0
			queue_redraw()
		KEY_ENTER, KEY_KP_ENTER:
			_play(String(LISTING[_chosen][1]))
		_:
			return
	get_viewport().set_input_as_handled()


func _play(id: String) -> void:
	if id == "":
		_note = note_seconds
		queue_redraw()
		return
	var cinematics: Node = get_node_or_null(cinematics_path)
	if cinematics == null or bool(cinematics.call("is_playing")):
		return
	_set_open(false)
	cinematics.call("play", id)


func _set_open(value: bool) -> void:
	_open = value
	_note = 0.0
	queue_redraw()


## Not mid-conversation, not mid-film, and not with the farm asleep for the cave or the
## cinema.
func _can_open() -> bool:
	if not is_visible_in_tree():
		return false
	var flock := get_node_or_null(flock_path) as Node4D
	if flock == null or not flock.is_visible_in_tree() or not flock.can_process():
		return false
	var player: Node = get_node_or_null(player_path)
	if player != null and player.get("input_enabled") == false:
		return false
	var cinematics: Node = get_node_or_null(cinematics_path)
	return cinematics == null or not bool(cinematics.call("is_playing"))


func _process(delta: float) -> void:
	if _note > 0.0:
		_note -= delta
		if _note <= 0.0:
			queue_redraw()
	# A conversation, a trip or a film that starts while you are in it steps you out.
	if _open and not _can_open():
		_set_open(false)
	_place()


func _step() -> float:
	return float(text_size) + 9.0


func _footer() -> String:
	if _note > 0.0:
		return "Not made yet"
	return OPEN_HINT if _open else "%s to choose" % OS.get_keycode_string(toggle_key)


func _place() -> void:
	var font: Font = get_theme_default_font()
	var widest: float = 22.0 + 8.0 + font.get_string_size("Cinematics", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	for row in LISTING:
		var extra: String = "    soon" if String(row[1]) == "" else ""
		widest = maxf(widest, 10.0 + font.get_string_size(String(row[0]) + extra, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	widest = maxf(widest, font.get_string_size(OPEN_HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 2).x)
	var width: float = 14.0 + widest + 16.0
	var screen: Vector2 = get_viewport_rect().size
	var top: float = 18.0
	var right: float = screen.x - right_margin
	var controls := get_node_or_null(controls_path) as Control
	if controls != null:
		var hint := controls.get_node_or_null("../ControlsHint") as Control
		if controls.visible:
			# Right-aligned under it and as wide, so the two read as one column.
			top = controls.position.y + controls.size.y + gap
			right = controls.position.x + controls.size.x
			width = maxf(width, controls.size.x)
		elif hint != null and hint.visible:
			top = hint.position.y + hint.size.y + gap
	var want := Vector2(width, 12.0 + _step() * float(LISTING.size() + 2) + 2.0)
	if want != size:
		size = want
		queue_redraw()
	var at := Vector2(right - size.x, top)
	if at != position:
		position = at


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var ascent: float = font.get_ascent(text_size)
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	# In it: the HUD's one colour, a short accent bar above the card.
	if _open:
		draw_rect(Rect2(Vector2(14.0, -6.0), Vector2(34.0, 3.0)), STYLE.accent.lightened(0.3))
	var y: float = 12.0
	# The heading, with the key that steps in, on the controls card's chip.
	var key_size: int = maxi(text_size - 1, 8)
	var k: String = OS.get_keycode_string(toggle_key)
	var chip := Rect2(Vector2(14.0, y - 1.0), Vector2(22.0, float(text_size) + 5.0))
	draw_style_box(_chip, chip)
	var k_w: float = font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x
	draw_string(font, Vector2(chip.position.x + (chip.size.x - k_w) * 0.5, y + ascent), k, HORIZONTAL_ALIGNMENT_LEFT, -1, key_size, Color(1.0, 1.0, 1.0, 0.9))
	draw_string(font, Vector2(chip.end.x + 8.0, y + ascent), "Cinematics", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
		Color(1.0, 1.0, 1.0, 0.9 if _open else 0.72))
	y += _step()
	for i in LISTING.size():
		var row: Array = LISTING[i]
		var ready: bool = String(row[1]) != ""
		if _open and i == _chosen:
			draw_style_box(_lit, Rect2(Vector2(8.0, y - 3.0), Vector2(size.x - 16.0, float(text_size) + 7.0)))
		var alpha: float = (0.9 if ready else 0.44) * (1.0 if _open else 0.85)
		draw_string(font, Vector2(24.0, y + ascent), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, alpha))
		if not ready:
			var after: float = 24.0 + font.get_string_size(String(row[0]) + "    ", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
			draw_string(font, Vector2(after, y + ascent), "soon", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, 0.3))
		y += _step()
	var hint_alpha: float = 0.72 if _note > 0.0 else (0.5 if _open else 0.34)
	draw_string(font, Vector2(14.0, y + font.get_ascent(text_size - 2)), _footer(), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 2, Color(1.0, 1.0, 1.0, hint_alpha))
