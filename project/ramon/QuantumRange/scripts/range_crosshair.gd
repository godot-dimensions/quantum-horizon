extends Control

## The crosshair, and the charge ring round it: the weapon's state where your eye already is.
##
##   the ticks    white; they take the colour of the part you are aiming at (red over a core, amber over
##                armour, grey over a shell or a locked core, green over a friendly: a warning)
##   the ring     fills amber, clockwise from the top, as a shot charges; at full it turns white-hot
##                and gets four ticks of its own ("release now"); vented it goes grey
##
## Reads the weapon (range_weapon_4d.gd) every frame. Sizes follow the window (kit type ladder units).
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")
const Kit := preload("res://ramon/QuantumRange/carried/kit/kit_style.gd")

var weapon: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var u: float = size.y / 720.0
	var c: Vector2 = size * 0.5
	var col := Color(1, 1, 1, 0.92)
	var hover: String = String(weapon.get("hover")) if weapon != null else ""
	if not hover.is_empty():
		if bool(weapon.get("hover_locked")) or hover == "shell":
			col = Color(0.72, 0.74, 0.78, 0.95)
		elif hover == "core":
			col = Style.glow("core")
		elif hover == "armour":
			col = Style.glow("armour")
		elif hover == "friend":
			col = Style.glow("friend")
		elif hover == "cover":
			col = Color(1, 1, 1, 1)
	var arm: float = 7.0 * u
	var gap: float = 4.0 * u
	var w: float = maxf(1.5, 2.0 * u)
	var shadow := Color(0, 0, 0, 0.35)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * gap + Vector2(1, 1), c + d * (gap + arm) + Vector2(1, 1), shadow, w)
		draw_line(c + d * gap, c + d * (gap + arm), col, w)
	if weapon == null:
		return
	var charging: bool = bool(weapon.get("charging"))
	var k: float = float(weapon.get("charge"))
	var vented: bool = bool(weapon.get("vented"))
	if not charging:
		return
	var r: float = 24.0 * u
	# A dark backing first, so the ring reads over anything (amber over an amber block was invisible).
	draw_arc(c, r, 0.0, TAU, 64, Color(0, 0, 0, 0.45), maxf(4.0, 6.5 * u), true)
	draw_arc(c, r, 0.0, TAU, 64, Color(1, 1, 1, 0.22), maxf(2.0, 3.0 * u), true)
	if vented:
		draw_arc(c, r, 0.0, TAU, 64, Color(0.55, 0.57, 0.60, 0.9), maxf(2.0, 3.0 * u), true)
		var f: Font = Kit.ui_font("heading")
		var px: int = Kit.type_px("caption", u)
		draw_string(f, c + Vector2(-60.0 * u, r + 16.0 * u), "VENTED", HORIZONTAL_ALIGNMENT_CENTER, 120.0 * u, px, Color(0.85, 0.87, 0.9))
		return
	if k > 0.0:
		var ring_col: Color = Style.glow("armour") if k < 0.999 else Color(1.0, 0.97, 0.88)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * k, 64, ring_col, maxf(2.5, 3.5 * u), true)
	if k >= 0.999:
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			var d2 := Vector2(cos(a), sin(a))
			draw_line(c + d2 * (r + 3.0 * u), c + d2 * (r + 9.0 * u), Color(1.0, 0.97, 0.88), maxf(2.0, 2.5 * u))
