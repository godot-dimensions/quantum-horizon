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
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")
const PPM := 160.0

@export_enum("n", "s", "w", "e") var side: String = "w":
	set(v):
		side = v
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
## How much the paint glows (0 is plain paint, lit by the room).
@export_range(0.0, 1.0, 0.01) var glow: float = 0.15


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
	var icon_band: float = _px(1.55) if not icons.is_empty() else 0.0
	LabPrint.block_fit(c, Vector2(0.0, 0.0), w, c.size.y - icon_band, [
		["%02d" % number, "bold", _px(0.6), ink["accent"], 0.0],
		[title, "black", _px(1.45), ink["text"], _px(0.2)],
		[subtitle, "bold", _px(0.46), ink["text"], _px(0.4)],
		[body, "body", _px(0.3), ink["dim"], 0.0],
	])
	if not icons.is_empty():
		RD.icon_row(c, Vector2(0.0, c.size.y - _px(1.45)), _px(0.7), _px(0.5), icons, ink["text"], _px(0.19))
