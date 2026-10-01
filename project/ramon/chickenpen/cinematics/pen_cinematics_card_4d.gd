extends Control

## The pen's CINEMATICS card - Ramon, 1 Oct: "in the chicken pen Hud, i want there to be a
## small bracket called cinematics, with a simple listing. add cinematic 1, and a second one
## just as placeholder", then "press K, and then it toggles, and to leave the toggle esc".
##
## ALWAYS SHOWN, ENTERED WITH K, LEFT WITH ESCAPE - so the number keys stay the belt's.
## Ramon: "i dont want the card closed as in hidden, just that you exit it with esc". The
## listing is always on screen; normally the number row selects the pickaxe and the rest of
## the inventory as always. K steps into the card - it lights up, the accent bar above it -
## and while you are in it, and only then, 1 plays cinematic 1 and 2 says the placeholder is
## not made yet. Escape (or K again) steps out, and Escape then means only that - not the
## camera rig's "free the cursor, then quit".
##
## ONE OF THE HUD'S CARDS: the to-do card's translucent fill, hairline border, corner, font
## and sizes. On the bottom row, right of the belt - the one place free of the other cards
## at both 1280x720 and 1920x1080.
##
## The cinematic plays here in the pen (pen_cinematics_4d.gd) and hands the pen back where
## you were when it ends or Escape skips it. K does nothing mid-conversation, or away in the
## cave or the cinema, where the farm and its flock are asleep.
##
## THE LAST NODE UNDER UI, on purpose: _input reaches later nodes first, so while you are in
## it this hears the number keys before the inventory belt does, and can keep them.

## [number key, title, cinematic name - "" for a placeholder]
const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
const LISTING := [
	[KEY_1, "Flight of the 4D Starlings", "murmuration"],
	[KEY_2, "Mountain Range", ""],
]

@export var cinematics_path: NodePath = NodePath("../../Cinematics")
@export var flock_path: NodePath = NodePath("../../World/Flock")
@export var player_path: NodePath = NodePath("../../Player")
@export var inventory_path: NodePath = NodePath("../Inventory")
@export var toggle_key: Key = KEY_K
@export_range(9, 28, 1) var text_size: int = 13
@export_range(0.0, 1.0, 0.05) var panel_alpha: float = 0.62
@export_range(0.0, 60.0, 1.0) var gap: float = 24.0
## How long "not made yet" shows after pressing a placeholder's key.
@export_range(0.5, 5.0, 0.1, "suffix:s") var note_seconds: float = 2.0

var _open: bool = false
var _note: float = 0.0
var _panel: StyleBoxFlat
var _cap: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.04, 0.05, 0.08, panel_alpha)
	_panel.border_color = Color(1.0, 1.0, 1.0, 0.07)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(9)
	_cap = StyleBoxFlat.new()
	_cap.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	_cap.border_color = Color(1.0, 1.0, 1.0, 0.45)
	_cap.set_border_width_all(1)
	_cap.set_corner_radius_all(4)


func is_open() -> bool:
	return _open


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
	if key.keycode == KEY_ESCAPE:
		_set_open(false)
		get_viewport().set_input_as_handled()
		return
	for row in LISTING:
		if key.keycode == int(row[0]):
			get_viewport().set_input_as_handled()
			_play(String(row[2]))
			return


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
	# A conversation, a trip or a film that starts while it is open closes it.
	if _open and not _can_open():
		_set_open(false)
	_place()


func _step() -> float:
	return float(text_size) + 9.0


func _row_text(row: Array) -> String:
	return "%s    %s" % [OS.get_keycode_string(int(row[0])), row[1]]


func _place() -> void:
	var font: Font = get_theme_default_font()
	var widest: float = 22.0 + 8.0 + font.get_string_size("Cinematics", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	for row in LISTING:
		var extra: String = "    soon" if String(row[2]) == "" else ""
		widest = maxf(widest, font.get_string_size(_row_text(row) + extra, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	var want := Vector2(14.0 + widest + 18.0, 12.0 + _step() * float(LISTING.size() + 2) + 4.0)
	if want != size:
		size = want
		queue_redraw()
	var inventory: Node = get_node_or_null(inventory_path)
	var screen: Vector2 = get_viewport_rect().size
	var at := Vector2(screen.x * 0.5, screen.y - size.y - 52.0)
	if inventory != null and inventory.has_method("_slot_rect"):
		var slots: int = int(inventory.get("slot_count"))
		var last: Rect2 = inventory.call("_slot_rect", maxi(slots - 1, 0))
		# Right of the belt, its bottom on the slots' bottom.
		at = Vector2(last.end.x + gap, last.end.y - size.y)
	if at != position:
		position = at


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var ascent: float = font.get_ascent(text_size)
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	# In it: the HUD's one colour, a short accent bar above the card, as on the stats panel.
	if _open:
		draw_rect(Rect2(Vector2(14.0, -6.0), Vector2(34.0, 3.0)), STYLE.accent.lightened(0.3))
	var y: float = 12.0
	# The heading, with the toggle's key cap in front of it.
	var cap := Rect2(Vector2(14.0, y - 1.0), Vector2(22.0, float(text_size) + 4.0))
	draw_style_box(_cap, cap)
	var k: String = OS.get_keycode_string(toggle_key)
	var k_w: float = font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 1).x
	draw_string(font, Vector2(cap.position.x + (cap.size.x - k_w) * 0.5, y + ascent), k, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 1, Color(1.0, 1.0, 1.0, 0.85))
	draw_string(font, Vector2(cap.end.x + 8.0, y + ascent), "Cinematics", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
		Color(1.0, 1.0, 1.0, 0.9 if _open else 0.55))
	y += _step()
	for row in LISTING:
		var ready: bool = String(row[2]) != ""
		var alpha: float = (0.9 if ready else 0.4) * (1.0 if _open else 0.75)
		var number: String = OS.get_keycode_string(int(row[0]))
		draw_string(font, Vector2(14.0, y + ascent), number, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, alpha * 0.6))
		var title_x: float = 14.0 + font.get_string_size(number + "    ", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(font, Vector2(title_x, y + ascent), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, alpha))
		if not ready:
			var after: float = title_x + font.get_string_size(String(row[1]) + "    ", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
			draw_string(font, Vector2(after, y + ascent), "soon", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, 0.3))
		y += _step()
	# The footer: how to get in or out - or, just after a placeholder's key, that it is not
	# made yet.
	var hint: String = "Not made yet" if _note > 0.0 else ("Esc to leave" if _open else "%s to choose" % k)
	var hint_alpha: float = 0.7 if _note > 0.0 else (0.45 if _open else 0.3)
	draw_string(font, Vector2(14.0, y + font.get_ascent(text_size - 2)), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 2, Color(1.0, 1.0, 1.0, hint_alpha))
