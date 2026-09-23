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
	"found_gold": {
		"name": "Gold",
		"colour": Color(0.98, 0.78, 0.22),
		"icon": "nugget",
	},
	"found_pickaxe": {
		"name": "Pickaxe",
		"colour": Color(0.72, 0.78, 0.86),
		"icon": "pickaxe",
	},
	"rewatch_ticket": {
		"name": "Ticket",
		"colour": Color(0.86, 0.72, 0.98),
		"icon": "ticket",
	},
}

@export var dialogue_path: NodePath
## Everyone ELSE who can hand you something.
##
## ONE PATH WAS NOT ENOUGH, and the way it failed is the reason this is a list. The belt
## listened to the keeper alone, so his gauntlet arrived and the pickaxe arrived (that one
## is in starts_with, not a conversation at all) - and every other character on the farm
## could announce a gift, have the effect fire correctly, and hand you nothing. Trym's
## ticket did exactly that: the dialogue said he gave it to you and the belt never heard.
##
## Anything that hands items over should be in here. An effect naming an item this belt
## does not know is ignored, so adding a speaker who gives nothing costs nothing.
@export var dialogue_paths: Array[NodePath] = []
@export_range(1, 10, 1) var slot_count: int = 5
## Things you are carrying before anybody hands you anything. The pickaxe is one - it is a
## tool rather than a reward, so there is no conversation to earn it from, and hanging it
## off a dialogue effect would have meant inventing one.
@export var starts_with: Array[String] = []

enum Align { CENTRE, LEFT }

## Dead centre puts the belt under the character, where the eye is already looking and
## where a dialogue panel or a thrown chicken wants to be. Left gets it out of the way.
@export var align: Align = Align.LEFT
@export_range(0.0, 400.0, 1.0) var side_margin: float = 40.0

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
## Which slot is in hand, or -1 for none. A tool has to be CHOSEN before it does anything,
## or every tool in the belt fights over the same button the moment you own two.
var selected: int = -1

var _flash: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for effect_name in starts_with:
		add_item(effect_name)
	var heard: int = 0
	for path in ([dialogue_path] as Array[NodePath]) + dialogue_paths:
		if path.is_empty():
			continue
		var dialogue: Node = get_node_or_null(path)
		if dialogue == null or not dialogue.has_signal("effect"):
			continue
		if not dialogue.is_connected("effect", _on_effect):
			dialogue.connect("effect", _on_effect)
		heard += 1
	if heard == 0:
		push_warning("PenInventory: no dialogue to listen to, so nothing can ever be picked up (item 82).")


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


## CHOOSING A SLOT, by clicking it or by its number.
##
## IN `_input`, NOT `_unhandled_input`. The camera rig also takes a left click - it is
## what recaptures the mouse after Escape - and whichever of the two runs second never
## sees the press. `_input` runs before every `_unhandled_input` in the tree, so the belt
## gets first refusal and passes anything that is not a slot straight through.
##
## THE CLICK ONLY COUNTS WHILE THERE IS A POINTER. This scene captures the mouse on its
## first frame, and a captured mouse has no meaningful position - the click would land on
## whatever slot the last free cursor happened to be over. So clicking selects while the
## cursor is free, and the number keys do the same job while it is not; the keys are the
## in-play route and the click is there because a belt you can click is what a belt looks
## like.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var digit: int = (event as InputEventKey).keycode - KEY_1
		if digit >= 0 and digit < slot_count:
			_choose(digit)
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		return
	var where: Vector2 = get_viewport().get_mouse_position()
	for index in slot_count:
		if _slot_rect(index).has_point(where):
			_choose(index)
			get_viewport().set_input_as_handled()
			return


## Clicking the slot you are already holding puts it away, which is the only way to stop
## holding something without picking up something else.
func _choose(index: int) -> void:
	if index >= items.size():
		return
	selected = -1 if selected == index else index
	_flash = 0.0


## What is in your hand, as an effect name, or "" for an empty hand. The tools ask this
## rather than being told, so a second tool is a row in ITEMS and a node of its own.
func selected_effect() -> String:
	if selected < 0 or selected >= items.size():
		return ""
	return items[selected]


## Where a slot sits on screen. ONE source for this, because the click test and the
## drawing have to agree exactly - computed twice they drift the moment either moves.
func _slot_rect(index: int) -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var total: float = float(slot_count) * slot_size + float(slot_count - 1) * slot_gap
	var left: float = side_margin if align == Align.LEFT else (screen.x - total) * 0.5
	var top: float = screen.y - bottom_margin - slot_size
	return Rect2(Vector2(left + float(index) * (slot_size + slot_gap), top),
		Vector2(slot_size, slot_size))


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


## Handing something back to its owner has to empty the slot, or the belt keeps claiming
## you are carrying a coin that is now in somebody else's pocket.
func remove_item(effect_name: String) -> void:
	var was: String = selected_effect()
	items.erase(effect_name)
	# Slots shuffle down when one is removed, so the index that was in hand now points at
	# somebody else's item. Follow the THING, not the number.
	selected = items.find(was) if was != "" and was != effect_name else -1


func has_item(effect_name: String) -> bool:
	return items.has(effect_name)


## Item 73's restart should empty your pockets too, or a second run starts with the reward
## of the first still on your wrist.
func reset() -> void:
	items.clear()
	selected = -1
	_flash = 0.0
	for effect_name in starts_with:
		add_item(effect_name)


## Item icons, drawn rather than imported.
##
## A slot is 54 pixels. At that size an imported sprite is mostly guesswork about which
## pixels survive, whereas four rectangles are exactly as legible as they were designed to
## be at every resolution - and the shape can match the model it stands for, which is what
## makes the thing in the slot recognisably the thing that just turned over your head.
## The same ring of points with the first repeated, for outlining a filled polygon.
func _closed_loop(points: PackedVector2Array) -> PackedVector2Array:
	var loop := PackedVector2Array(points)
	loop.append(loop[0])
	return loop


func _draw_icon(kind: String, box: Rect2, colour: Color) -> void:
	var unit: float = box.size.x
	var mid: Vector2 = box.position + box.size * 0.5
	var dim := Color(colour.r, colour.g, colour.b, 0.55)

	if kind == "nugget":
		# A lump rather than a disc: the ADA piece is already a circle, and two round yellow
		# things in one belt is one too many.
		var lump := PackedVector2Array()
		for i in 9:
			var a: float = TAU * float(i) / 9.0
			var wobble: float = 0.20 + 0.055 * sin(float(i) * 2.3)
			lump.append(mid + Vector2(cos(a), sin(a) * 0.82) * unit * wobble)
		draw_colored_polygon(lump, colour)
		draw_polyline(_closed_loop(lump), Color(1.0, 0.94, 0.66, 0.85),
			maxf(unit * 0.03, 1.0), true)
		return

	if kind == "ticket":
		# A stub with a torn edge. Two rectangles and a row of notches reads as a ticket at
		# fifty pixels, where anything more literal reads as a grey smudge.
		var w: float = unit * 0.34
		var h: float = unit * 0.22
		draw_rect(Rect2(mid - Vector2(w, h), Vector2(w * 2.0, h * 2.0)), colour)
		draw_rect(Rect2(mid - Vector2(w, h), Vector2(w * 2.0, h * 2.0)), dim,
			false, maxf(unit * 0.03, 1.0))
		# The perforation, a third of the way along.
		var tear: float = mid.x - w * 0.34
		for i in 5:
			var y: float = mid.y - h + h * 2.0 * (float(i) + 0.5) / 5.0
			draw_line(Vector2(tear, y - h * 0.10), Vector2(tear, y + h * 0.10),
				Color(0.12, 0.10, 0.14, 0.9), maxf(unit * 0.035, 1.0))
		return

	if kind == "pickaxe":
		# A SILHOUETTE, not a line drawing. Upright haft, a collar, and a head that sweeps
		# out to a point either side and droops as it goes - which is the one shape that
		# separates a pickaxe from a hammer at fifty pixels.
		var half: float = unit * 0.34
		var haft := Rect2(mid + Vector2(-unit * 0.045, -unit * 0.14),
			Vector2(unit * 0.09, unit * 0.46))
		draw_rect(haft, Color(0.58, 0.40, 0.24, 0.95), true)
		draw_rect(Rect2(mid + Vector2(-unit * 0.075, -unit * 0.21),
			Vector2(unit * 0.15, unit * 0.11)), colour, true)
		draw_rect(Rect2(mid + Vector2(-unit * 0.05, -unit * 0.27),
			Vector2(unit * 0.10, unit * 0.06)), Color(0.58, 0.40, 0.24, 0.95), true)
		# Top edge out from the middle, then back along the underside - the two meet at
		# each tip, which is what makes the point rather than a blunt end.
		var head := PackedVector2Array()
		for i in 13:
			var x: float = lerpf(-half, half, float(i) / 12.0)
			var k: float = (x / half) * (x / half)
			head.append(mid + Vector2(x, -unit * 0.30 + unit * 0.17 * k))
		for i in 13:
			var x: float = lerpf(half, -half, float(i) / 12.0)
			var k: float = (x / half) * (x / half)
			head.append(mid + Vector2(x, -unit * 0.19 + unit * 0.11 * k))
		draw_colored_polygon(head, colour)
		return

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
	var left: float = side_margin if align == Align.LEFT else (screen.x - total) * 0.5
	var top: float = screen.y - bottom_margin - slot_size
	var font: Font = ThemeDB.fallback_font

	for index in slot_count:
		var box: Rect2 = _slot_rect(index)
		var at: Vector2 = box.position
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
		if index == selected:
			# In hand: brighter inside and a second frame outside, so which one is chosen
			# survives being glanced at rather than read.
			draw_rect(box.grow(-4.0), Color(colour.r, colour.g, colour.b, 0.30), true)
			draw_rect(box.grow(3.0), colour, false, 2.0)
			edge = colour
		draw_rect(box, edge, false, 2.0)

		_draw_icon(str(item.get("icon", "")), box, colour)

		var label: String = str(item["name"])
		var label_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, at + Vector2((slot_size - label_width) * 0.5, slot_size + 17.0),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 1.0, 1.0, 0.8))
