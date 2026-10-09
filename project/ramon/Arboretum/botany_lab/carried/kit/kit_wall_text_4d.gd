@tool
extends Node

## Kit: text painted on a wall of the KitRoom it is a child of (kit_room_4d.gd). The room does the
## painting; this says what and where. Change anything here and the room repaints.
##
##   kind "lesson"  number, title, a line under it, a paragraph, and a row of control icons, left
##                  aligned, the concept frames' wall of type
##   kind "sign"    a title and a line under it, centred: the CREATION LAB over a doorway
##
## `along` is where it runs along the wall (from the room's centre, in metres; for "n"/"s" walls
## along x, for "w"/"e" along z) and `up` how high (from the floor). `outside` paints the wall's
## outer face instead (a sign seen from the room next door).
##
## LIVE (Ramon, 4 Oct: "is the 4D basics wall dynamic, the text? if not make it"): `live` prints it
## through a viewport of its own instead of a picture rendered once, redrawn whenever what it says
## changes, so the paragraph can name the animal on the plinth: {name} and {balls} in the body, and
## {action} in an icon's label (the exhibit's E key), are filled in from `showcase`.
##
## SIZES are steps on the lab's type ladder (kit_style.gd), in metres: the title a poster, the line
## under it a hero, the paragraph a headline, the icons' labels a subhead.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")
const RD := preload("res://ramon/Arboretum/botany_lab/carried/scripts/rd_build.gd")
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")
const PPM := 160.0

@export_enum("n", "s", "w", "e") var side: String = "w":
	set(v):
		side = v
		_changed()
## For a polygon room (KitRoom `outline`): which edge it is painted on (-1: use `side`).
@export var edge: int = -1:
	set(v):
		edge = v
		_changed()
@export var along: Vector2 = Vector2(-2.0, 6.0):
	set(v):
		along = v
		_changed()
@export var up: Vector2 = Vector2(1.4, 7.4):
	set(v):
		up = v
		_changed()
@export var outside: bool = false:
	set(v):
		outside = v
		_changed()
@export_enum("lesson", "sign") var kind: String = "lesson":
	set(v):
		kind = v
		_changed()
@export var number: int = 1:
	set(v):
		number = v
		_changed()
@export var title: String = "4D Basics":
	set(v):
		title = v
		_changed()
@export var subtitle: String = "":
	set(v):
		subtitle = v
		_changed()
@export_multiline var body: String = "":
	set(v):
		body = v
		_changed()
## Control icons under a lesson: [icon kind, label] (rd_build.gd icon()).
@export var icons: Array = []:
	set(v):
		icons = v
		_changed()
## A colour code for the wall it is painted on (kit_style.gd CODES): "blue" paints that whole wall
## blue and the text white; the text and its layout stay as they are.
@export_enum("none", "blue") var code: String = "none":
	set(v):
		code = v
		_changed()
## Printed live (a viewport redrawn when it changes) rather than rendered once; see the note above.
@export var live: bool = false:
	set(v):
		live = v
		_changed()
## The showcase whose animal fills in {name}, {balls} and {action}.
@export var showcase: NodePath
## Pixels a metre for the live print.
@export_range(80.0, 400.0, 10.0) var live_ppm: float = 200.0
## How much the paint glows (0 is plain paint, lit by the room).
@export_range(0.0, 1.0, 0.01) var glow: float = 0.15
## Off: the room paints nothing of it, and its wall goes back to the room's own (a wall panel,
## kit_wall_panel_4d.gd, has taken its place; creation_lab_4d.gd set_walls flips between them).
@export var enabled: bool = true:
	set(v):
		enabled = v
		_changed()


var _said: String = ""


func _process(_delta: float) -> void:
	if not live or not enabled or Engine.is_editor_hint():
		return
	# Redrawn only when what it would say has changed: a new animal, or its numbers arriving.
	var now: String = _filled(body) + "|" + _filled(str(icons))
	if now != _said:
		_said = now
		var room: Node = get_parent()
		if room != null and room.has_method("refresh_text"):
			room.call("refresh_text", self)


## `text` with the animal on the plinth filled in; missing numbers read naturally.
func _filled(text: String) -> String:
	if not text.contains("{"):
		return text
	var sc: Node = get_node_or_null(showcase) if not showcase.is_empty() else null
	var d: Dictionary = sc.call("data") if sc != null and sc.has_method("data") else {}
	var nm: String = String(d.get("name", "")).to_lower()
	var balls: int = int((d.get("stats", {}) as Dictionary).get("balls", 0))
	var act: String = String(sc.call("action_label")) if sc != null and sc.has_method("action_label") else ""
	return text.replace("{name}", nm if not nm.is_empty() else "animal").replace("{balls}", str(balls) if balls > 0 else "a handful of") \
		.replace("{action}", act if not act.is_empty() else "Add a ball")


func _changed() -> void:
	var room: Node = get_parent()
	if room != null and room.has_method("_later"):
		room.call("_later")


func _px(m: float) -> int:
	return int(round(m * PPM))


func paint(c: Control, ink: Dictionary) -> void:
	if kind == "sign":
		var f: Font = LabPrint.font("black")
		var px: int = _px(minf(0.9, (up.y - up.x) * 0.42))
		c.draw_string(f, Vector2(0.0, c.size.y * 0.52), title, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, px, ink["text"])
		if not subtitle.is_empty():
			c.draw_string(LabPrint.font("bold"), Vector2(0.0, c.size.y * 0.52 + px * 0.62), subtitle, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, int(px * 0.26), ink["accent"])
		return
	var w: float = c.size.x
	var k: float = c.size.x / maxf(absf(along.y - along.x), 0.01)
	var m := func(role: Variant) -> int: return int(round(Style.type_m(role) * k))
	var icon_band: float = 1.55 * k if not icons.is_empty() else 0.0
	LabPrint.block_fit(c, Vector2(0.0, 0.0), w, c.size.y - icon_band, [
		["%02d" % number, "bold", m.call(7), ink["accent"], 0.0],
		[title, "black", m.call("poster"), ink["text"], 0.2 * k],
		[subtitle, "body", m.call("hero"), ink["text"], 0.4 * k],
		[_filled(body), "body", m.call("headline"), ink["dim"], 0.0],
	])
	if not icons.is_empty():
		var filled_icons: Array = []
		for it in icons:
			filled_icons.append([it[0], _filled(String(it[1]))])
		# A label is centred under its icon, so a label wider than the first icon would run off the
		# left edge: the row starts far enough in for it.
		var first_w: float = LabPrint.font("bold").get_string_size(String(filled_icons[0][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, m.call("subhead")).x
		RD.icon_row(c, Vector2(maxf(0.0, (first_w - 0.7 * k) * 0.5), c.size.y - 1.45 * k), 0.7 * k, 0.5 * k, filled_icons, ink["text"], m.call("subhead"))
