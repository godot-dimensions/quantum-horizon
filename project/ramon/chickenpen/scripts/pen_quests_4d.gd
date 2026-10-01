extends Control
class_name PenQuests4D

## The checklist in the top left: what there is to do, and what you have done.
##
## TRYM, 25 SEPT: "Might be worth with a very simple check list quest tracker thing in the
## top left corner." The objective line only ever named the chickens; everything else the
## field offers - Mithra's watch, a trough for Nike, the presentation - was something you
## found by walking into it or did not find at all.
##
## THE STATE IS READ, NEVER KEPT. Every line asks the system that owns the fact - the flock
## for the count, the inventory and Mithra's driver for the watch, the upgrades for the
## trough, Trym's driver for the presentation - so a restart, a debug key or a runner that
## pokes the game directly can never leave the tracker saying something the world does
## not. A second record of a fact is a second thing to get out of step.
##
## POLLED, four times a second, not wired to signals. Half of these facts have no signal,
## and a list that is a quarter of a second late is indistinguishable from one that is not.
##
## SAME PANEL AS THE OTHER TWO CORNERS. Colour, alpha, border and radius match
## pen_controls_4d and pen_info_card_4d, and it hangs from the bottom of the info card
## rather than sitting at a height typed in by hand - that card grows and shrinks as its
## rows come and go, and a fixed position would sit on top of it half the time.

## The card above this one, whose bottom edge it follows.
@export var above_path: NodePath = NodePath("../InfoCard")
@export var flock_path: NodePath = NodePath("../../Chickens")
@export var inventory_path: NodePath = NodePath("../Inventory")
@export var mithra_path: NodePath = NodePath("../../Systems/MithraDriver")
@export var upgrades_path: NodePath = NodePath("../../Pen/Upgrades")
@export var trym_path: NodePath = NodePath("../../Systems/TrymDriver")

@export_range(9, 28, 1) var text_size: int = 13
## The controls card's (top right) - Ramon, 1 Oct: "all of these info brackets should
## match the style of top right menu". It was 0.62.
@export_range(0.0, 1.0, 0.01) var panel_alpha: float = 0.34
@export_range(0.0, 40.0, 1.0) var gap_below: float = 8.0
## Bottom left, sitting on the inventory row - Ramon, 1 Oct, when the murmuration's stats
## took the place under the info card. Off, it follows the card above as it used to.
@export var at_bottom_left: bool = true
@export_range(0.05, 2.0, 0.05) var poll_seconds: float = 0.25

## The places beyond the field you have been to this run. STATIC, and that is the point:
## the shooting range is a real scene change, which frees the pen and everything in it, so
## anything the pen held would be gone by the time you walked back. A static on the class
## outlives the scene. A full restart clears it (see reset), because a restart is meant to
## put the whole run back, not just the chickens.
static var _visited: Dictionary = {}


## Called by the cave and the range when you arrive.
static func mark_visited(place: String) -> void:
	_visited[place] = true


## Part of the full restart - chickenpen_game_4d resets everything on its list.
func reset() -> void:
	_visited.clear()
	_rows = []
	_poll()


var _panel: StyleBoxFlat
var _rows: Array = []   # [text, done]
var _clock: float = 0.0


func _ready() -> void:
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.04, 0.05, 0.08, panel_alpha)
	_panel.border_color = Color(1.0, 1.0, 1.0, 0.07)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(9)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poll()


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= poll_seconds:
		_clock = 0.0
		_poll()
	_follow()


## Everything there is to do, asked of whoever knows.
func _poll() -> void:
	var rows: Array = []
	var flock: Node = get_node_or_null(flock_path)
	if flock != null and flock.has_method("returned_count"):
		var home: int = int(flock.call("returned_count"))
		var total: int = (flock.get("agents") as Array).size()
		rows.append(["Bring all %d chickens home   %d/%d" % [total, home, total], total > 0 and home >= total])
	var mithra: Node = get_node_or_null(mithra_path)
	var inventory: Node = get_node_or_null(inventory_path)
	if mithra != null:
		var gave: bool = bool(mithra.get("_gave_watch"))
		var holding: bool = inventory != null and bool(inventory.call("has_item", "found_watch"))
		rows.append(["Find Mithra's pocket watch", gave or holding])
		rows.append(["Give it back to her", gave])
	var upgrades: Node = get_node_or_null(upgrades_path)
	if upgrades != null and upgrades.has_method("feeder_count"):
		rows.append(["Buy Nike a trough", int(upgrades.call("feeder_count")) > 0])
	var trym: Node = get_node_or_null(trym_path)
	if trym != null:
		rows.append(["See Trym's presentation", bool(trym.get("_shown_it"))])
	for place in _places():
		rows.append([place[0], _been(place[1])])
	if rows != _rows:
		_rows = rows
		_measure()
		queue_redraw()


## The two places beyond the field, once they exist. Listed here, checked by group.
func _places() -> Array:
	return [
		["Find the way into the hill", "cave"],
		["Try the shooting range", "range"],
	]


func _been(place: String) -> bool:
	return bool(_visited.get(place, false))


func _step() -> float:
	return float(text_size) + 9.0


func _measure() -> void:
	var font: Font = get_theme_default_font()
	var widest: float = font.get_string_size("To do", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	for row in _rows:
		widest = maxf(widest, font.get_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	size = Vector2(14.0 + 20.0 + widest + 16.0, 12.0 + _step() * float(_rows.size() + 1) + 6.0)


func _follow() -> void:
	var above := get_node_or_null(above_path) as Control
	if above == null:
		return
	# The drawn panel, not the Control's rect - see pen_info_card_4d.drawn_rect.
	var r: Rect2 = above.call("drawn_rect") if above.has_method("drawn_rect") else Rect2(above.position, above.size)
	if at_bottom_left:
		var bottom: float = get_viewport_rect().size.y - gap_below
		var inventory: Node = get_node_or_null(inventory_path)
		if inventory != null and inventory.has_method("_slot_rect"):
			bottom = (inventory.call("_slot_rect", 0) as Rect2).position.y - gap_below * 1.5
		position = Vector2(r.position.x, bottom - size.y)
		return
	position = Vector2(r.position.x, r.position.y + r.size.y + gap_below)


func _draw() -> void:
	if _rows.is_empty():
		return
	var font: Font = get_theme_default_font()
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var y: float = 12.0
	draw_string(font, Vector2(14.0, y + font.get_ascent(text_size)), "To do",
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, 0.55))
	y += _step()
	for row in _rows:
		var done: bool = bool(row[1])
		var box := Rect2(Vector2(14.0, y + 2.0), Vector2(float(text_size), float(text_size)))
		draw_rect(box, Color(1.0, 1.0, 1.0, 0.45 if not done else 0.0), false, 1.5)
		if done:
			# A tick rather than a filled box: "done" reads from shape, not just colour.
			var a: Vector2 = box.position + Vector2(box.size.x * 0.12, box.size.y * 0.55)
			var b: Vector2 = box.position + Vector2(box.size.x * 0.40, box.size.y * 0.85)
			var c: Vector2 = box.position + Vector2(box.size.x * 0.95, box.size.y * 0.12)
			var tick := Color(0.55, 0.95, 0.60)
			draw_line(a, b, tick, 2.2, true)
			draw_line(b, c, tick, 2.2, true)
		draw_string(font, Vector2(14.0 + float(text_size) + 8.0, y + font.get_ascent(text_size)),
			String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			Color(1.0, 1.0, 1.0, 0.45 if done else 0.90))
		y += _step()
