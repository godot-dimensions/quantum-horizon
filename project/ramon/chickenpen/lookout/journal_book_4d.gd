extends Control

## Wren's field journal, open: J, on the ground or up in the cab.
##
## A PAGE AT A TIME. The pages down the left, with a star for every photo on each; the open
## page on the right, its four behaviours as four frames - the best photo of each, or, for a
## slot not filled yet, Wren's hint for it. Secret pages are a question mark until something
## is on them. Up and Down turn the pages; J or Escape closes it.
##
## IT PAUSES NOTHING. The farm goes on behind it, as a real notebook would let it; the
## player just stands still (input off) while it is open, and in the cab the camera holds.
##
## A FRESH BOOK: Ctrl+Backspace twice wipes it, for a first-time playthrough.

const STYLE := preload("res://ramon/Menu/style/menu_final_style.tres")
const VIEWFINDER := preload("res://ramon/chickenpen/lookout/lookout_viewfinder_4d.gd")
const JOURNAL := preload("res://ramon/chickenpen/lookout/field_journal_4d.gd")

var lookout: Node

var _page: int = 0
var _open: bool = false
var _wipe_armed: float = 0.0
var _player_input: Variant = null
var _font: Font
var _layer: CanvasLayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_default_font()
	visible = false


func is_open() -> bool:
	return _open


func open_book(page_id: String = "") -> void:
	if _open:
		return
	_open = true
	visible = true
	if page_id != "":
		_page = _index_of(page_id)
	var player: Node = lookout.get("player")
	# Still while reading, camera up or not.
	if player != null:
		_player_input = player.get("input_enabled")
		player.set("input_enabled", false)
	lookout.call("sound", &"page")
	queue_redraw()


func close_book() -> void:
	if not _open:
		return
	_open = false
	visible = false
	_wipe_armed = 0.0
	var player: Node = lookout.get("player")
	if _player_input != null and player != null:
		player.set("input_enabled", _player_input)
	_player_input = null


func _index_of(id: String) -> int:
	var pages: Array = JOURNAL.PAGES
	for i in pages.size():
		if pages[i]["id"] == id:
			return i
	return 0


## Whether J may open the book now: not mid-climb, not mid-conversation, not in the cave or
## the cinema (the farm asleep), not while a film plays.
func can_open() -> bool:
	var station: Node = lookout.get("station")
	var mode: int = int(station.get("mode"))
	if mode == 1 or mode == 3:
		return false
	if mode == 0:
		var player: Node4D = lookout.get("player")
		if player == null or not player.is_visible_in_tree() or player.get("input_enabled") == false:
			return false
		var world := lookout.get("room").get_node_or_null("World") as Node4D
		if world == null or not world.is_visible_in_tree() or not world.can_process():
			return false
		var cinematics: Node = lookout.get("room").get_node_or_null("Cinematics")
		if cinematics != null and bool(cinematics.call("is_playing")):
			return false
	return not bool(lookout.call("story_busy"))


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if not _open:
		if key.keycode == KEY_J and can_open():
			open_book()
			get_viewport().set_input_as_handled()
		return
	# One more page than the journal has: the roll, last in the book.
	var count: int = JOURNAL.PAGES.size() + 1
	match key.keycode:
		KEY_J, KEY_ESCAPE:
			close_book()
		KEY_UP, KEY_W:
			_page = posmod(_page - 1, count)
			_wipe_armed = 0.0
			lookout.call("sound", &"page")
		KEY_DOWN, KEY_S:
			_page = posmod(_page + 1, count)
			_wipe_armed = 0.0
			lookout.call("sound", &"page")
		KEY_BACKSPACE:
			if key.ctrl_pressed:
				if _wipe_armed > 0.0:
					lookout.get("journal").call("wipe")
					lookout.call("on_journal_wiped")
					_wipe_armed = 0.0
				else:
					_wipe_armed = 3.0
		_:
			pass
	# Everything is the book's while it is open: the camera and the player wait.
	get_viewport().set_input_as_handled()
	queue_redraw()


func _process(delta: float) -> void:
	if _wipe_armed > 0.0:
		_wipe_armed = maxf(_wipe_armed - delta, 0.0)
		queue_redraw()
	# Something took the farm away (a trip, a film): close.
	if _open and int(lookout.get("station").get("mode")) == 0 and not can_open() and not bool(lookout.call("story_busy")):
		var player: Node = lookout.get("player")
		if player == null or not player.is_visible_in_tree():
			close_book()


func _draw() -> void:
	if not _open:
		return
	var s: Vector2 = get_viewport_rect().size
	var journal: Node = lookout.get("journal")
	var pages: Array = JOURNAL.PAGES
	var accent: Color = STYLE.accent.lightened(0.35)
	var panel := Rect2(s * Vector2(0.07, 0.08), s * Vector2(0.86, 0.84))
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.0, 0.35))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.08, 0.9)
	box.border_color = Color(1, 1, 1, 0.08)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	draw_style_box(box, panel)
	draw_rect(Rect2(panel.position + Vector2(22.0, -6.0), Vector2(46.0, 3.0)), accent)
	var x0: float = panel.position.x + 26.0
	var y: float = panel.position.y + 40.0
	draw_string(_font, Vector2(x0, y), "FIELD JOURNAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.92))
	var summary: String = "Pages %d / %d    ·    Photos %d / %d" % [int(journal.call("pages_found")), pages.size(), int(journal.call("star_count")), pages.size() * 4]
	var sw: float = _font.get_string_size(summary, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(_font, Vector2(panel.end.x - 26.0 - sw, y), summary, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.7))
	y += 18.0
	draw_string(_font, Vector2(x0, y + 8.0), "Wren's, from the Lookout", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.45))
	# The pages, down the left.
	var list_w: float = panel.size.x * 0.27
	var row_h: float = minf(34.0, (panel.size.y - 140.0) / float(pages.size() + 1))
	var ly: float = y + 36.0
	for i in pages.size():
		var p: Dictionary = pages[i]
		var found: bool = bool(journal.call("found", p["id"]))
		var label: String = "? ? ?" if bool(p["secret"]) and not found else String(p["title"])
		var lit: bool = i == _page
		if lit:
			draw_rect(Rect2(Vector2(x0 - 8.0, ly - 4.0), Vector2(list_w, row_h - 4.0)), Color(1, 1, 1, 0.08))
			draw_rect(Rect2(Vector2(x0 - 8.0, ly - 4.0), Vector2(3.0, row_h - 4.0)), accent)
		draw_string(_font, Vector2(x0, ly + row_h * 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, list_w - 90.0, 16,
			Color(1, 1, 1, 0.92 if lit else (0.75 if found else 0.42)))
		for k in 4:
			var full: bool = bool(journal.call("filled", p["id"], k + 1))
			VIEWFINDER.star(self, Vector2(x0 + list_w - 78.0 + float(k) * 15.0, ly + row_h * 0.5 - 5.0), 5.5, full, Color(1, 1, 1, 0.9), accent)
		ly += row_h
	# The roll, last in the list.
	var roll_lit: bool = _page >= pages.size()
	if roll_lit:
		draw_rect(Rect2(Vector2(x0 - 8.0, ly - 4.0), Vector2(list_w, row_h - 4.0)), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(Vector2(x0 - 8.0, ly - 4.0), Vector2(3.0, row_h - 4.0)), accent)
	var recent: Array = journal.get("recent")
	draw_string(_font, Vector2(x0, ly + row_h * 0.5), "The roll  ·  %d this time out" % recent.size(), HORIZONTAL_ALIGNMENT_LEFT, list_w - 20.0, 16,
		Color(1, 1, 1, 0.92 if roll_lit else 0.75))
	if roll_lit:
		var px0: float = x0 + list_w + 24.0
		_draw_roll(Rect2(px0, y + 40.0, panel.end.x - 26.0 - px0, panel.end.y - 52.0 - (y + 40.0)), recent, accent)
		_draw_foot(panel, accent)
		return
	# The open page.
	var page: Dictionary = pages[_page]
	var found_page: bool = bool(journal.call("found", page["id"]))
	var px: float = x0 + list_w + 24.0
	var pw: float = panel.end.x - 26.0 - px
	var py: float = y + 40.0
	var title: String = "? ? ?" if bool(page["secret"]) and not found_page else String(page["title"])
	draw_string(_font, Vector2(px, py + 8.0), title, HORIZONTAL_ALIGNMENT_LEFT, pw, 24, Color(1, 1, 1, 0.95))
	if found_page or not bool(page["secret"]):
		draw_string(_font, Vector2(px, py + 32.0), String(page["latin"]), HORIZONTAL_ALIGNMENT_LEFT, pw, 14, Color(1, 1, 1, 0.5))
	var grid_top: float = py + 52.0
	var cell := Vector2((pw - 18.0) * 0.5, (panel.end.y - 52.0 - grid_top - 18.0) * 0.5)
	for k in 4:
		var cx: float = px + float(k % 2) * (cell.x + 18.0)
		var cy: float = grid_top + float(k / 2) * (cell.y + 18.0)
		var frame := Rect2(cx, cy, cell.x, cell.y - 44.0)
		var filled: bool = bool(journal.call("filled", page["id"], k + 1))
		var behaviour: String = String(page["slots"][k])
		if filled:
			var tex: Texture2D = journal.call("thumb", page["id"], k + 1)
			if tex != null:
				var fit: Rect2 = _fit(tex.get_size(), frame)
				draw_rect(fit.grow(3.0), Color(0.92, 0.9, 0.84, 0.95))
				draw_texture_rect(tex, fit, false)
			else:
				draw_rect(frame, Color(1, 1, 1, 0.1))
			var slot: Dictionary = journal.get("slots")[page["id"]][k]
			draw_string(_font, Vector2(cx, frame.end.y + 22.0), behaviour, HORIZONTAL_ALIGNMENT_LEFT, cell.x - 110.0, 15, Color(1, 1, 1, 0.9))
			var pts: String = "%s pts" % VIEWFINDER._thousands(int(slot.get("points", 0)))
			if String(slot.get("from", "tower")) == "balloon":
				pts += "  ·  from the balloon"
			draw_string(_font, Vector2(cx, frame.end.y + 40.0), pts, HORIZONTAL_ALIGNMENT_LEFT, cell.x, 13, accent)
		else:
			_dashed(frame, Color(1, 1, 1, 0.22))
			var secret_hidden: bool = bool(page["secret"]) and not found_page and k > 0
			var hint: String = "" if secret_hidden else String(page["hints"][k])
			_wrapped(hint, Rect2(frame.position + Vector2(16.0, 18.0), frame.size - Vector2(32.0, 30.0)), 14, Color(1, 1, 1, 0.55))
			var name_text: String = "? ? ?" if secret_hidden else behaviour
			draw_string(_font, Vector2(cx, frame.end.y + 22.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, cell.x - 110.0, 15, Color(1, 1, 1, 0.45))
		for st in 4:
			VIEWFINDER.star(self, Vector2(cx + cell.x - 74.0 + float(st) * 17.0, frame.end.y + 17.0), 6.5, st <= k and filled, Color(1, 1, 1, 0.6 if st <= k else 0.15), accent)
	_draw_foot(panel, accent)


## Every shot this time out, newest first, each with how it was judged - the four bars the toast
## showed - including the ones that did not make the journal, and why.
func _draw_roll(area: Rect2, recent: Array, accent: Color) -> void:
	draw_string(_font, Vector2(area.position.x, area.position.y + 8.0), "The roll", HORIZONTAL_ALIGNMENT_LEFT, area.size.x, 24, Color(1, 1, 1, 0.95))
	draw_string(_font, Vector2(area.position.x, area.position.y + 32.0), "Every shot this time out, and how each was judged: from the game's state, not the pixels",
		HORIZONTAL_ALIGNMENT_LEFT, area.size.x, 14, Color(1, 1, 1, 0.5))
	if recent.is_empty():
		draw_string(_font, Vector2(area.position.x, area.position.y + 80.0), "Nothing yet. Z raises the camera, click takes a photo.", HORIZONTAL_ALIGNMENT_LEFT, area.size.x, 15, Color(1, 1, 1, 0.55))
		return
	var cols: int = 3
	var top: float = area.position.y + 52.0
	var cw: float = (area.size.x - 16.0 * float(cols - 1)) / float(cols)
	var ch: float = 150.0
	var shown: int = mini(recent.size(), cols * int(maxf(floor((area.end.y - top) / (ch + 12.0)), 1.0)))
	for i in shown:
		var r: Dictionary = recent[recent.size() - 1 - i]
		var cx: float = area.position.x + float(i % cols) * (cw + 16.0)
		var cy: float = top + float(i / cols) * (ch + 12.0)
		var frame := Rect2(cx, cy, cw, ch - 62.0)
		var tex: Texture2D = r.get("thumb") as Texture2D
		if tex != null:
			draw_texture_rect(tex, _fit(tex.get_size(), frame), false)
		else:
			draw_rect(frame, Color(1, 1, 1, 0.08))
		var verdict: String = String(r.get("verdict", ""))
		var name_text: String = String(r.get("name", "")) if verdict != "nothing" else "Nothing in it"
		var why: String = {"good": "%s pts" % VIEWFINDER._thousands(int(r.get("points", 0))), "soft": "out of focus", "small": "too far away"}.get(verdict, "")
		draw_string(_font, Vector2(cx, frame.end.y + 16.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, cw - 70.0, 13, Color(1, 1, 1, 0.88))
		var ww: float = _font.get_string_size(why, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(_font, Vector2(cx + cw - ww, frame.end.y + 16.0), why, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent if verdict == "good" else Color(1, 1, 1, 0.5))
		if verdict != "nothing":
			VIEWFINDER.bars(self, _font, Vector2(cx, frame.end.y + 36.0), cw, r, 1.0, accent)


func _draw_foot(panel: Rect2, accent: Color) -> void:
	var foot: String = "Up / Down  pages     ·     J or Esc  closes     ·     Ctrl+Backspace twice  a fresh journal"
	if _wipe_armed > 0.0:
		foot = "Press Ctrl+Backspace again to wipe the journal and every photo in it"
	var fw: float = _font.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(_font, Vector2(panel.position.x + (panel.size.x - fw) * 0.5, panel.end.y - 18.0), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		accent if _wipe_armed > 0.0 else Color(1, 1, 1, 0.42))


func _fit(image: Vector2, into: Rect2) -> Rect2:
	var k: float = minf(into.size.x / maxf(image.x, 1.0), into.size.y / maxf(image.y, 1.0))
	var size_fit: Vector2 = image * k
	return Rect2(into.position + (into.size - size_fit) * 0.5, size_fit)


func _dashed(r: Rect2, c: Color) -> void:
	var dash: float = 8.0
	for side in 4:
		var a: Vector2 = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][side]
		var b: Vector2 = [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position][side]
		var length: float = a.distance_to(b)
		var t: float = 0.0
		while t < length:
			draw_line(a.lerp(b, t / length), a.lerp(b, minf(t + dash, length) / length), c, 1.0)
			t += dash * 2.0


func _wrapped(text: String, r: Rect2, font_size: int, c: Color) -> void:
	var words: PackedStringArray = text.split(" ")
	var line: String = ""
	var y: float = r.position.y + float(font_size)
	for word in words:
		var trial: String = word if line == "" else line + " " + word
		if _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > r.size.x and line != "":
			draw_string(_font, Vector2(r.position.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)
			y += float(font_size) + 6.0
			line = word
		else:
			line = trial
	if line != "":
		draw_string(_font, Vector2(r.position.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)
