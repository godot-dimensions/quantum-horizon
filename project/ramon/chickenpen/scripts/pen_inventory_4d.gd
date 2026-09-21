extends Control

## Five slots along the bottom of the screen. One of them ends up holding the gauntlet.
##
## IT LISTENS; IT IS NOT TOLD. The keeper's conversation announces what it did - the
## dialogue player emits `effect("give_gauntlet")` and has no idea what a gauntlet is - so
## this connects to that signal and fills a slot. Nothing in `ramon/dialogue/` and nothing
## in pen_talk_4d.gd needs a line added for the inventory to exist, which is the same seam
## the locator already hangs off. A second item means a second row in ITEMS and a second
## effect name in the script, and no code anywhere else.
##
## DRAWN, NOT BUILT FROM NODES. Five squares and a label is less code as five draw calls
## than as fifteen Controls with their own anchors, and it sizes itself to the viewport
## without a container fighting it. It is also why the empty slots can be genuinely cheap:
## an empty slot is a rectangle, not a scene.
##
## EMPTY SLOTS ARE SHOWN, NOT HIDDEN. Four empty frames say "there are four more things"
## far better than an inventory that grows a slot each time it gains one, and the shape of
## the bar stops moving under the player's eye.

## What each known item looks like. The key is the effect name the dialogue emits.
const ITEMS := {
	"give_gauntlet": {
		"name": "Gauntlet",
		"colour": Color(0.36, 0.98, 0.46),
		"icon": "gauntlet",
	},
	"found_coin": {
		"name": "ADA",
		"colour": Color(0.42, 0.58, 0.98),
		"icon": "coin",
	},
	"found_egg": {
		"name": "Golden Egg",
		"colour": Color(0.98, 0.82, 0.30),
		"icon": "egg",
	},
}

@export var dialogue_path: NodePath
@export_range(1, 10, 1) var slot_count: int = 5

@export_group("Look")
@export_range(24.0, 140.0, 1.0) var slot_size: float = 54.0
@export_range(0.0, 40.0, 1.0) var slot_gap: float = 10.0
## Leaves room under the row for the name of whatever is in a slot.
@export_range(0.0, 200.0, 1.0) var bottom_margin: float = 46.0
@export var empty_fill: Color = Color(0.0, 0.0, 0.0, 0.34)
@export var empty_border: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var filled_border: Color = Color(1.0, 1.0, 1.0, 0.72)
## How long a newly gained item pulses, so gaining one is visible without a popup.
@export_range(0.0, 6.0, 0.1) var flash_seconds: float = 2.5

## Effect names, in the order they were gained. Empty strings are never stored - a slot is
## empty because the list is shorter than the bar.
var items: Array[String] = []

var _flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dialogue: Node = get_node_or_null(dialogue_path)
	if dialogue == null:
		push_warning("PenInventory: dialogue_path resolves to nothing, so nothing can ever be picked up (item 82).")
		return
	if not dialogue.is_connected("effect", _on_effect):
		dialogue.connect("effect", _on_effect)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


## Anything the dialogue announces that names a known item lands in a slot. Unknown effects
## are somebody else's business and pass without comment.
func _on_effect(effect_name: String) -> void:
	if not ITEMS.has(effect_name):
		return
	add_item(effect_name)


func add_item(effect_name: String) -> void:
	if items.has(effect_name) or items.size() >= slot_count:
		return
	items.append(effect_name)
	_flash = flash_seconds


func has_item(effect_name: String) -> bool:
	return items.has(effect_name)


## Item 73's restart should empty your pockets too, or a second run starts with the reward
## of the first still on your wrist.
func reset() -> void:
	items.clear()
	_flash = 0.0


## Item icons, drawn rather than imported.
##
## A slot is 54 pixels. At that size an imported sprite is mostly guesswork about which
## pixels survive, whereas four rectangles are exactly as legible as they were designed to
## be at every resolution - and the shape can match the model it stands for, which is what
## makes the thing in the slot recognisably the thing that just turned over your head.
func _draw_icon(kind: String, box: Rect2, colour: Color) -> void:
	var unit: float = box.size.x
	var mid: Vector2 = box.position + box.size * 0.5
	var dim := Color(colour.r, colour.g, colour.b, 0.55)

	if kind == "coin":
		# A ring with the mark's dot field inside it, the same rings the model is built
		# from, so the slot and the thing you picked up are recognisably one object.
		draw_arc(mid, unit * 0.30, 0.0, TAU, 28, colour, maxf(unit * 0.05, 1.5), true)
		draw_circle(mid, unit * 0.045, colour)
		for ring in [[6, 0.11, 0.032], [6, 0.19, 0.024], [10, 0.26, 0.017]]:
			var count: int = int(ring[0])
			for i in count:
				var angle: float = TAU * float(i) / float(count)
				draw_circle(mid + Vector2(cos(angle), sin(angle)) * unit * float(ring[1]),
					unit * float(ring[2]), colour)
		return

	if kind == "egg":
		# Drawn as stacked chords rather than an ellipse call, because an egg is wider
		# below its middle and a circle primitive cannot say that.
		var rows := [[-0.26, 0.10], [-0.19, 0.15], [-0.10, 0.19], [0.00, 0.20],
			[0.10, 0.185], [0.19, 0.145], [0.26, 0.085]]
		for row in rows:
			var half: float = unit * float(row[1])
			draw_rect(Rect2(mid + Vector2(-half, unit * float(row[0]) - unit * 0.05),
				Vector2(half * 2.0, unit * 0.075)), colour, true)
		return

	if kind != "gauntlet":
		return

	# The cuff, as a band across the slot, with the strap edges darker at top and bottom.
	var cuff := Rect2(mid - Vector2(unit * 0.30, unit * 0.26), Vector2(unit * 0.60, unit * 0.52))
	draw_rect(cuff, dim, false, maxf(unit * 0.045, 1.5))
	draw_rect(Rect2(cuff.position + Vector2(0.0, -unit * 0.07),
		Vector2(cuff.size.x, unit * 0.06)), dim, true)
	draw_rect(Rect2(cuff.position + Vector2(0.0, cuff.size.y + unit * 0.01),
		Vector2(cuff.size.x, unit * 0.06)), dim, true)

	# The screen, filled, because it is the lit part and the thing the eye lands on.
	draw_rect(Rect2(mid - Vector2(unit * 0.19, unit * 0.19),
		Vector2(unit * 0.38, unit * 0.27)), colour, true)

	# The dial on the inboard edge and the button row under the screen: the two details
	# that stop it reading as a plain rectangle.
	draw_rect(Rect2(mid + Vector2(-unit * 0.38, -unit * 0.08),
		Vector2(unit * 0.08, unit * 0.16)), dim, true)
	for i in 3:
		draw_rect(Rect2(mid + Vector2((float(i) - 1.0) * unit * 0.11 - unit * 0.03, unit * 0.12),
			Vector2(unit * 0.06, unit * 0.06)), colour, true)


func _draw() -> void:
	var screen: Vector2 = get_viewport_rect().size
	var total: float = float(slot_count) * slot_size + float(slot_count - 1) * slot_gap
	var left: float = (screen.x - total) * 0.5
	var top: float = screen.y - bottom_margin - slot_size
	var font: Font = ThemeDB.fallback_font

	for index in slot_count:
		var at := Vector2(left + float(index) * (slot_size + slot_gap), top)
		var box := Rect2(at, Vector2(slot_size, slot_size))
		var filled: bool = index < items.size()
		draw_rect(box, empty_fill, true)

		if not filled:
			draw_rect(box, empty_border, false, 2.0)
			continue

		var item: Dictionary = ITEMS[items[index]]
		var colour: Color = item["colour"]
		# The newest item pulses its border rather than flashing the whole slot, so the
		# glyph stays readable while it is drawing attention to itself.
		var edge: Color = filled_border
		if _flash > 0.0 and index == items.size() - 1:
			var pulse: float = (sin(_flash * 9.0) + 1.0) * 0.5
			edge = filled_border.lerp(colour, pulse)
		draw_rect(box.grow(-4.0), Color(colour.r, colour.g, colour.b, 0.22), true)
		draw_rect(box, edge, false, 2.0)

		_draw_icon(str(item.get("icon", "")), box, colour)

		var label: String = str(item["name"])
		var label_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, at + Vector2((slot_size - label_width) * 0.5, slot_size + 17.0),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 1.0, 1.0, 0.8))
