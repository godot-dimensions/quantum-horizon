extends Control

## Ten slots in the bottom-left corner, two rows of five. One of them ends up holding the gauntlet.
##
## TWO CONNECTED ROWS, FLAT ICONS (10 Oct 2026, Ramon's walkthrough items 6, 7 and 15: "Arrange the inventory into two
## rows of five slots. Keep the slots tightly connected ... simple, recognizable silhouettes ... a restrained, mostly
## single-color treatment, with specific colors reserved for items where color communicates identity ... more like a
## polished gameplay interface and less like a developer tool"). The slots touch, on one dark glass panel; each icon
## is one flat silhouette in its item's colour (purple azoth, pale grey egg, gold egg; the rest restrained); the count
## sits in the corner in the lab's type; the name of what is in hand (or just gained) is one line under the grid
## instead of a caption under every slot. Keys 1 to 5 still choose the top row (6 to 8 stay the debug keys').
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

const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")

## What each known item looks like. The key is the effect name the dialogue emits.
const ITEMS := {
	"give_gauntlet": {
		"name": "Gauntlet",
		"colour": Color(0.36, 0.98, 0.46),
		"icon": "gauntlet",
	},
	"found_watch": {
		"name": "Pocket Watch",
		"colour": Color(0.88, 0.72, 0.42),
		"icon": "watch",
	},
	"found_egg": {
		"name": "Golden Egg",
		"colour": Color(0.90, 0.70, 0.28),
		"icon": "egg",
		"stacks": true,
	},
	## The strange clock from the meadow's edge (10 Oct, item 27), for Mithra.
	"found_clock": {
		"name": "Strange Clock",
		"colour": Color(0.56, 0.74, 0.70),
		"icon": "watch",
	},
	## The pen's eggs (10 Oct, Ramon's walkthrough item 14: "Two regular white eggs. One golden egg"), pale grey.
	"found_egg_white": {
		"name": "Egg",
		"colour": Color(0.86, 0.85, 0.82),
		"icon": "egg",
		"stacks": true,
	},
	## THE ONLY THING YOU CAN HOLD MORE THAN ONE OF. There are six pieces in the rock and
	## six troughs to spend them on, so a belt that refuses the second one makes five of
	## them unreachable - and it refused silently, which is worse: you swung the pick, the
	## rock gave up a piece, and nothing happened.
	##
	## AZOTH, NOT GOLD (Ramon, 29 Sept: "replace the gold in the lore with a ... purple ore
	## that is related to azatoth and his interdimensional powers"). The alchemists' first
	## matter; the white suits' word for it. Its count is always shown, one included - it
	## is cumulative, and how much you have is the point of it.
	"found_azoth": {
		"name": "Azoth",
		"colour": Color(0.68, 0.40, 1.0),
		"icon": "azoth",
		"stacks": true,
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

## Something landed in a slot. `pen_sfx_4d` listens for this and blips; nothing in here
## knows what a blip is. It fires for the thing that arrived, not for the attempt - a
## duplicate or a full belt returns above without a sound, which is right: the confirm
## has to mean "you have it now", or it stops meaning anything.
signal picked_up(effect_name: String)

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
@export_range(1, 10, 1) var slot_count: int = 10
## Slots to a row (two rows of five).
@export_range(1, 10, 1) var per_row: int = 5
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
## Bigger than it was. Fifty-four was sized against a windowed prototype and reads as a
## row of stamps on a full screen, where it is the one piece of UI you have to pick things
## out of at a glance.
## 10 Oct: smaller and joined (two rows of five, no gaps; Ramon: "Maintain consistent slot dimensions").
@export_range(24.0, 140.0, 1.0) var slot_size: float = 56.0
@export_range(0.0, 40.0, 1.0) var slot_gap: float = 0.0
## Leaves room under the grid for the name of what is in hand.
@export_range(0.0, 200.0, 1.0) var bottom_margin: float = 46.0
@export var empty_fill: Color = Color(0.0, 0.0, 0.0, 0.34)
@export var empty_border: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var filled_border: Color = Color(1.0, 1.0, 1.0, 0.72)
## How long a newly gained item pulses, so gaining one is visible without a popup.
@export_range(0.0, 6.0, 0.1) var flash_seconds: float = 2.5

## Effect names, in the order they were gained. Empty strings are never stored - a slot is
## empty because the list is shorter than the bar.
var items: Array[String] = []
## How many of each, for the ones that stack. Absent means one.
var counts: Dictionary = {}
## Which slot is in hand, or -1 for none. A tool has to be CHOSEN before it does anything,
## or every tool in the belt fights over the same button the moment you own two.
var selected: int = -1

var _flash: float = 0.0
## True only while the belt is being stocked from `starts_with`. You did not pick the
## pickaxe up, it was in your hand when the level loaded - so it does not get the sound.
var _filling: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_filling = true
	for effect_name in starts_with:
		add_item(effect_name)
	_filling = false
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
		# The top row only (1 to 5): 6, 7 and 8 are the debug keys (scripts/pen_debug_4d.gd).
		if digit >= 0 and digit < mini(slot_count, per_row):
			# Mid-conversation the numbers are the answers' (dialogue_player_4d.gd), not the
			# belt's: the belt hears input first, so it has to step aside or no answer is ever
			# picked by its number.
			if _in_conversation():
				return
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


## Whether anyone is talking (every conversation is a PenNpcTalk4D in the group "npc_talk",
## its DialoguePlayer4D as `_talk`).
func _in_conversation() -> bool:
	for talker in get_tree().get_nodes_in_group(&"npc_talk"):
		var talk: Node = talker.get("_talk")
		if talk != null and talk.has_method("is_running") and bool(talk.call("is_running")):
			return true
	return false


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


## Where the belt is on the screen (its slots and the name under the chosen one), for panels that keep clear of
## it (pen_hud_spot_4d.gd counts no full-screen control, and this one is full-screen).
func belt_rect() -> Rect2:
	var r: Rect2 = _slot_rect(0).merge(_slot_rect(maxi(slot_count - 1, 0))).grow(6.0)
	r.size.y += bottom_margin
	return get_global_transform() * r


## Where a slot sits on screen. ONE source for this, because the click test and the
## drawing have to agree exactly - computed twice they drift the moment either moves.
func _slot_rect(index: int) -> Rect2:
	var screen: Vector2 = get_viewport_rect().size
	var cols: int = mini(per_row, slot_count)
	var rows: int = ceili(float(slot_count) / float(maxi(cols, 1)))
	var w: float = slot_size
	var h: float = slot_size * 0.88
	var total: float = float(cols) * w + float(cols - 1) * slot_gap
	var left: float = side_margin if align == Align.LEFT else (screen.x - total) * 0.5
	var top: float = screen.y - bottom_margin - float(rows) * h - float(rows - 1) * slot_gap
	var col: int = index % maxi(cols, 1)
	var row: int = index / maxi(cols, 1)
	return Rect2(Vector2(left + float(col) * (w + slot_gap), top + float(row) * (h + slot_gap)), Vector2(w, h))


## Anything the dialogue announces that names a known item lands in a slot. Unknown effects
## are somebody else's business and pass without comment.
func _on_effect(effect_name: String) -> void:
	if not ITEMS.has(effect_name):
		return
	add_item(effect_name)


func add_item(effect_name: String) -> void:
	# A SECOND NUGGET IS A SECOND NUGGET, not a duplicate to be thrown away. Stackable
	# items keep a count against the one slot; everything else is still one-of, because
	# two gauntlets or two tickets would be nonsense.
	if items.has(effect_name):
		if not bool((ITEMS.get(effect_name, {}) as Dictionary).get("stacks", false)):
			return
		counts[effect_name] = count_of(effect_name) + 1
		_flash = flash_seconds
		if not _filling:
			picked_up.emit(effect_name)
		return
	if items.size() >= slot_count:
		return
	items.append(effect_name)
	counts[effect_name] = 1
	_flash = flash_seconds
	if not _filling:
		picked_up.emit(effect_name)


## Handing something back to its owner has to empty the slot, or the belt keeps claiming
## you are carrying a watch that is now back in somebody else's pocket.
func remove_item(effect_name: String) -> void:
	# One off the stack, and only the last one empties the slot.
	if count_of(effect_name) > 1:
		counts[effect_name] = count_of(effect_name) - 1
		return
	var was: String = selected_effect()
	counts.erase(effect_name)
	items.erase(effect_name)
	# Slots shuffle down when one is removed, so the index that was in hand now points at
	# somebody else's item. Follow the THING, not the number.
	selected = items.find(was) if was != "" and was != effect_name else -1


func has_item(effect_name: String) -> bool:
	return items.has(effect_name)


## How many you are carrying. Zero if none, one for anything that does not stack.
func count_of(effect_name: String) -> int:
	if not items.has(effect_name):
		return 0
	return int(counts.get(effect_name, 1))


## Item 73's restart should empty your pockets too, or a second run starts with the reward
## of the first still on your wrist.
func reset() -> void:
	items.clear()
	counts.clear()
	selected = -1
	_flash = 0.0
	_filling = true
	for effect_name in starts_with:
		add_item(effect_name)
	_filling = false


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


## ONE FLAT SILHOUETTE PER ITEM (10 Oct, Ramon: "simple, recognizable silhouettes ... Avoid unnecessary gradients,
## complex shading"): a single fill in [param colour], at most a darker cut-out, sized to the slot's shorter side.
func _draw_icon(kind: String, box: Rect2, colour: Color) -> void:
	var unit: float = minf(box.size.x, box.size.y)
	var mid: Vector2 = box.get_center()
	var cut: Color = Color(0.06, 0.07, 0.10, 0.85)
	match kind:
		"azoth":
			# A gem: a crown and a point.
			var r: float = unit * 0.30
			draw_colored_polygon(PackedVector2Array([
				mid + Vector2(-r * 0.55, -r * 0.62), mid + Vector2(r * 0.55, -r * 0.62), mid + Vector2(r, -r * 0.12),
				mid + Vector2(0.0, r * 0.95), mid + Vector2(-r, -r * 0.12)]), colour)
			draw_line(mid + Vector2(-r, -r * 0.12), mid + Vector2(r, -r * 0.12), cut, maxf(unit * 0.035, 1.0), true)
		"egg":
			var pts := PackedVector2Array()
			for i in 28:
				var a: float = TAU * float(i) / 28.0
				var y: float = -cos(a)
				# Narrower at the top than the bottom.
				var w: float = sin(a) * (0.70 + 0.12 * y)
				pts.append(mid + Vector2(w * unit * 0.25, y * unit * 0.32 + unit * 0.02))
			draw_colored_polygon(pts, colour)
		"pickaxe":
			var half: float = unit * 0.32
			draw_line(mid + Vector2(-unit * 0.20, unit * 0.30), mid + Vector2(unit * 0.12, -unit * 0.14), colour, maxf(unit * 0.08, 2.0), true)
			var head := PackedVector2Array()
			for i in 13:
				var x: float = lerpf(-half, half, float(i) / 12.0)
				var k: float = (x / half) * (x / half)
				head.append(mid + Vector2(x, -unit * 0.26 + unit * 0.14 * k))
			for i in 13:
				var x: float = lerpf(half, -half, float(i) / 12.0)
				var k: float = (x / half) * (x / half)
				head.append(mid + Vector2(x, -unit * 0.17 + unit * 0.09 * k))
			draw_colored_polygon(head, colour)
		"watch":
			var face: Vector2 = mid + Vector2(0.0, unit * 0.04)
			var r: float = unit * 0.24
			draw_circle(face, r, colour)
			draw_rect(Rect2(face + Vector2(-unit * 0.04, -r - unit * 0.08), Vector2(unit * 0.08, unit * 0.09)), colour, true)
			draw_line(face, face + Vector2(0.0, -r * 0.62), cut, maxf(unit * 0.04, 1.2), true)
			draw_line(face, face + Vector2(r * 0.48, 0.0), cut, maxf(unit * 0.04, 1.2), true)
		"ticket":
			var w: float = unit * 0.34
			var h: float = unit * 0.21
			draw_rect(Rect2(mid - Vector2(w, h), Vector2(w * 2.0, h * 2.0)), colour, true)
			for i in 4:
				draw_circle(Vector2(mid.x - w * 0.30, mid.y - h + h * 2.0 * (float(i) + 0.5) / 4.0), unit * 0.025, cut)
		"gauntlet":
			draw_rect(Rect2(mid - Vector2(unit * 0.28, unit * 0.22), Vector2(unit * 0.56, unit * 0.44)), colour, true)
			draw_rect(Rect2(mid - Vector2(unit * 0.16, unit * 0.12), Vector2(unit * 0.32, unit * 0.18)), cut, true)


func _draw() -> void:
	if slot_count <= 0:
		return
	var font: Font = LabPrint.font("bold")
	var u: float = slot_size / 56.0
	var grid: Rect2 = _slot_rect(0).merge(_slot_rect(slot_count - 1))
	# One dark glass panel behind the whole grid.
	var panel := Style.glass_box(10.0 * u, 1.0, 0.72)
	draw_style_box(panel, grid.grow(5.0 * u))
	var line_c := Color(1.0, 1.0, 1.0, 0.10)
	for index in slot_count:
		var box: Rect2 = _slot_rect(index)
		var filled: bool = index < items.size()
		# The slots touch: a hairline between them, nothing more.
		draw_rect(box, line_c, false, 1.0)
		if not filled:
			continue
		var item: Dictionary = ITEMS.get(items[index], {})
		var colour: Color = item.get("colour", Color.WHITE)
		draw_rect(box.grow(-1.0), Color(1.0, 1.0, 1.0, 0.05), true)
		if _flash > 0.0 and index == items.size() - 1:
			var pulse: float = (sin(_flash * 9.0) + 1.0) * 0.5
			draw_rect(box.grow(-1.5), Color(colour, 0.25 + 0.45 * pulse), false, 2.0)
		if index == selected:
			draw_rect(box.grow(-1.0), Color(colour, 0.16), true)
			draw_rect(box.grow(-1.5), Color(colour, 0.95), false, maxf(2.0, 2.0 * u))
		_draw_icon(str(item.get("icon", "")), box, colour)
		# How many, in the corner: on anything that stacks, always; on nothing else.
		var held: int = count_of(items[index])
		if bool(item.get("stacks", false)) or held > 1:
			var tag: String = "%d" % held
			var tag_size: int = clampi(int(slot_size * 0.24), 10, 24)
			var tag_wide: float = font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
			var corner := Vector2(box.end.x - tag_wide - 4.0 * u, box.end.y - 4.0 * u)
			draw_string(font, corner + Vector2(1.0, 1.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color(0.0, 0.0, 0.0, 0.7))
			draw_string(font, corner, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size, Color(1.0, 1.0, 1.0, 0.95))
	# One line under the grid: what is in hand, or what just arrived.
	var shown: int = selected if selected >= 0 and selected < items.size() else (items.size() - 1 if _flash > 0.0 else -1)
	if shown >= 0:
		var item: Dictionary = ITEMS.get(items[shown], {})
		var label: String = str(item.get("name", ""))
		if shown == selected:
			label += "  in hand"
		var name_size: int = clampi(int(slot_size * 0.25), 11, 22)
		draw_string(font, Vector2(grid.position.x, grid.end.y + 5.0 * u + float(name_size) + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(1.0, 1.0, 1.0, 0.82))
