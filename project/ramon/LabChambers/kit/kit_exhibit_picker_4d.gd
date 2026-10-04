@tool
extends "res://ramon/LabChambers/kit/kit_desk_4d.gd"

## Kit: the specimen picker. A small panel floating low in front of the pedestal, tilted up to you,
## with a slot per animal the room can show: an icon, its name and the key that brings it (Ramon,
## 4 Oct: "a small floating panel near the ground with info on it. it has icons. a goat icon and a
## chicken icon, and room for 4 more. press 1, is goat. press 2, and you get the same presentation
## for the chicken. and a chicken icon lights up in blue. before light grey").
##
## It is the research panel's body (kit_desk_4d.gd: the rounded slab, the live 2D screen drawn into
## a viewport, the row of square collision boxes) with its own picture. The room owns the keys
## (goat_room_4d.gd: 1 to 6 call choose()); the slot lit is whichever animal the showcase has on
## its plinth, so it can never disagree with what you see. Not in the "kit_desk" group, so no key
## prompt pops up over it.
##
## THE SLOTS are three lists of the same length, in the inspector: each animal's exhibit script,
## its name and its icon (kit_glyphs animal(): "goat", "chicken"). Slots past the end are drawn
## empty, waiting.
##
## NO class_name (engine_gotchas.md).

const SLOTS := 6

@export var slot_scripts: PackedStringArray = ["res://ramon/LabChambers/scripts/rd_goat_4d.gd", "res://ramon/LabChambers/scripts/rd_chicken_4d.gd"]
@export var slot_names: PackedStringArray = ["GOAT", "CHICKEN"]
@export var slot_icons: PackedStringArray = ["goat", "chicken"]

var _lit_at: float = -10.0
var _last_active: int = -2


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


## Never a place to stand and press E.
func near(_p: Vector4) -> bool:
	return false


## Key `i` (0 for the 1 key): the exhibit script for that slot, or null for an empty slot.
func choose(i: int) -> Script:
	if i < 0 or i >= slot_scripts.size() or slot_scripts[i].is_empty():
		return null
	return load(slot_scripts[i]) as Script


## The slot of the animal on the plinth now, or -1.
func active() -> int:
	var sc: Node = get_node_or_null(showcase)
	var s: Script = sc.get("exhibit_script") if sc != null else null
	return slot_scripts.find(s.resource_path) if s != null else -1


func _draw_screen() -> void:
	var c: Control = _canvas
	var w: float = c.size.x
	var h: float = c.size.y
	var u: float = h / 276.0
	var on := active()
	if on != _last_active:
		_last_active = on
		_lit_at = _clock
	var blue := Color(0.30, 0.62, 1.0)
	var grey := Color(0.80, 0.82, 0.86)
	var faint := Color(0.80, 0.82, 0.86, 0.28)
	var bg := Color(0.045, 0.06, 0.09)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	# The card.
	var card := StyleBoxFlat.new()
	card.bg_color = bg
	card.set_corner_radius_all(int(18.0 * u))
	card.anti_aliasing = true
	c.draw_style_box(card, Rect2(Vector2.ZERO, c.size))
	# The header: what it is, and how to use it.
	var mg: float = 22.0 * u
	c.draw_string(fb, Vector2(mg, 40.0 * u), "SPECIMENS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(24.0 * u), grey)
	var hint: String = "PRESS 1 TO %d" % SLOTS
	var hint_w: float = fs.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18.0 * u)).x
	c.draw_string(fs, Vector2(w - mg - hint_w, 39.0 * u), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18.0 * u), Color(grey, 0.6))
	# The slots.
	var gap: float = 14.0 * u
	var top: float = 56.0 * u
	var sw: float = (w - mg * 2.0 - gap * float(SLOTS - 1)) / float(SLOTS)
	var sh: float = h - top - 16.0 * u
	for i in SLOTS:
		var r := Rect2(Vector2(mg + float(i) * (sw + gap), top), Vector2(sw, sh))
		var filled: bool = i < slot_scripts.size() and not slot_scripts[i].is_empty()
		var lit: bool = i == on
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(12.0 * u))
		box.anti_aliasing = true
		if lit:
			# Lit: a blue edge that flares as it is chosen, then breathes.
			var flare: float = clampf(1.0 - (_clock - _lit_at) / 0.6, 0.0, 1.0)
			box.bg_color = Color(blue, 0.14 + 0.16 * flare)
			box.border_color = Color(blue, 0.85 + 0.15 * sin(_clock * 3.0))
			box.set_border_width_all(int(maxf(2.0, 3.5 * u)))
		elif filled:
			box.bg_color = Color(1, 1, 1, 0.04)
			box.border_color = Color(grey, 0.30)
			box.set_border_width_all(int(maxf(1.0, 2.0 * u)))
		else:
			box.bg_color = Color(1, 1, 1, 0.015)
			box.border_color = Color(grey, 0.12)
			box.set_border_width_all(int(maxf(1.0, 1.5 * u)))
		c.draw_style_box(box, r)
		var ink: Color = blue if lit else (grey if filled else faint)
		# The key, top left.
		c.draw_string(fs, r.position + Vector2(12.0 * u, 26.0 * u), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * u), ink)
		if not filled:
			c.draw_string(fl, Vector2(r.position.x, r.end.y - 18.0 * u), "EMPTY", HORIZONTAL_ALIGNMENT_CENTER, sw, int(14.0 * u), faint)
			continue
		var icon_r := Rect2(r.position + Vector2(sw * 0.14, 22.0 * u), Vector2(sw * 0.72, sh - 62.0 * u))
		Glyphs.animal(c, slot_icons[i] if i < slot_icons.size() else "", icon_r, ink, Color(bg.lerp(ink, 0.12) if lit else bg))
		var nm: String = slot_names[i] if i < slot_names.size() else ""
		c.draw_string(fs, Vector2(r.position.x, r.end.y - 16.0 * u), nm, HORIZONTAL_ALIGNMENT_CENTER, sw, int(16.0 * u), ink)
