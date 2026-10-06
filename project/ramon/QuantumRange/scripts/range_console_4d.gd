extends Node4D

## The console, on a stand to your left in the bay, facing you: a black-glass screen (the kit's rule: screens are black glass) with
## one button per experiment, 01 to 05, and START. NUMBERED BOXES ARE BUTTONS (Ramon's rule for the kit):
## each one is pressed, never just lit. Two ways to press one, both the range's own verbs: SHOOT it, the
## way a range's start plate works, or look at it and press F. Number keys pick too (the director).
##
## The screen is a 2D page drawn into a viewport of its own and printed onto the glass (the kit's grid
## shader print, as the wall panels are), redrawn only when what it shows changes. Each button has an
## Area4D the weapon's ray can find (meta "range_button": its index, 5 being START).
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/QuantumRange/carried/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/QuantumRange/carried/LabKit/lab_grid.gd")
const Kit := preload("res://ramon/QuantumRange/carried/kit/kit_style.gd")
const Layout := preload("res://ramon/QuantumRange/scripts/range_layout.gd")

const SCREEN := Vector2(1.9, 0.42)
const PPM := 520.0
const BUTTONS := 6

## What it shows: {"sel": int, "tiles": [[number, title, status, done], ...], "start": "START",
## "hover": int, "mode": "lobby" | "run" | "results"}.
var data: Dictionary = {}

var _vp: SubViewport
var _page: Control
var _screen: MeshInstance4D
var _sig: int = 0


## The glass's lower edge above the floor.
const BASE_Y := 1.1


func _ready() -> void:
	# Its +Z faces +X, towards you across the bay: a quarter turn keeps every hitbox square to the world.
	position = Layout.CONSOLE_AT
	basis = Basis4D.from_zx(PI * 0.5)
	# A white stand, a bezel, the black glass in it.
	Build.box(self, "Stand", Vector3(0.0, BASE_Y * 0.5, -0.12), Vector3(0.5, BASE_Y, 0.26), "range_counter", true)
	Build.box(self, "Bezel", Vector3(0.0, BASE_Y + SCREEN.y * 0.5 + 0.02, -0.02), Vector3(SCREEN.x + 0.1, SCREEN.y + 0.08, 0.05), "range_counter", false)
	_screen = Build.box(self, "Screen", Vector3(0.0, BASE_Y + SCREEN.y * 0.5 + 0.02, 0.012), Vector3(SCREEN.x, SCREEN.y, 0.02), "range_screen", false)
	_vp = SubViewport.new()
	_vp.name = "ConsoleView"
	_vp.size = Vector2i(int(SCREEN.x * PPM), int(SCREEN.y * PPM))
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.msaa_2d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_page = Control.new()
	_page.size = Vector2(_vp.size)
	_page.draw.connect(_paint)
	_vp.add_child(_page)
	var m: TetraMaterial4D = _screen.material_override as TetraMaterial4D
	LabGrid.set_print(m, _vp.get_texture(), Vector4(0, 0, 1, 0), Rect2(Vector2.ZERO, SCREEN), Color.WHITE, 0.9)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)
	# One hitbox per button, just proud of the glass.
	for i in BUTTONS:
		var r: Rect2 = _tile_m(i)
		var area := Area4D.new()
		area.name = "Button%d" % i
		var shape := CollisionShape4D.new()
		var bs := BoxShape4D.new()
		bs.size = Vector4(r.size.x, r.size.y, 0.12, 0.6)
		shape.shape = bs
		area.add_child(shape)
		area.position = Vector4(r.get_center().x - SCREEN.x * 0.5, BASE_Y + 0.02 + r.get_center().y, 0.03, 0.0)
		area.set_meta("range_button", i)
		add_child(area)


## A tile's rectangle in metres on the glass, from its lower-left corner (x right, y up).
func _tile_m(i: int) -> Rect2:
	var pad: float = 0.04
	var gap: float = 0.025
	var start_w: float = 0.38
	var w: float = (SCREEN.x - pad * 2.0 - start_w - gap * float(BUTTONS - 1)) / float(BUTTONS - 1)
	var h: float = SCREEN.y - 0.12
	var x: float = pad + (w + gap) * float(i)
	return Rect2(Vector2(x, 0.05), Vector2(start_w if i == BUTTONS - 1 else w, h))


func show(d: Dictionary) -> void:
	data = d
	var sig: int = hash(str(d))
	if sig != _sig:
		_sig = sig
		_page.queue_redraw()
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _paint() -> void:
	var c: Control = _page
	var k: float = PPM
	var sz: Vector2 = c.size
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.035, 0.042, 0.055))
	var fh: Font = Kit.ui_font("heading")
	var ft: Font = Kit.ui_font("title")
	var fb: Font = Kit.ui_font("text")
	c.draw_string(fh, Vector2(0.05 * k, 0.045 * k), "QUANTUM RANGE  ·  CONSOLE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.03 * k), Color(1, 1, 1, 0.55))
	var hint: String = String(data.get("hint", "SHOOT A NUMBER, OR PRESS 1 TO 5"))
	c.draw_string(fh, Vector2(0.0, 0.045 * k), hint, HORIZONTAL_ALIGNMENT_RIGHT, sz.x - 0.05 * k, int(0.03 * k), Color(1, 1, 1, 0.55))
	var tiles: Array = data.get("tiles", [])
	var sel: int = int(data.get("sel", 0))
	var hover: int = int(data.get("hover", -1))
	for i in BUTTONS:
		var rm: Rect2 = _tile_m(i)
		# Metres from the lower left to pixels from the upper left.
		var r := Rect2(Vector2(rm.position.x * k, sz.y - (rm.position.y + rm.size.y) * k), rm.size * k)
		var is_start: bool = i == BUTTONS - 1
		var on: bool = (i == sel and not is_start)
		var lit: bool = i == hover
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(0.02 * k))
		sb.anti_aliasing = true
		if is_start:
			sb.bg_color = Color(0.96, 0.97, 0.98) if not lit else Color(1, 1, 1)
		else:
			sb.bg_color = Color(1, 1, 1, 0.10 if on else 0.05)
			sb.border_color = Kit.UI_ACCENT if on else Color(1, 1, 1, 0.25 if lit else 0.12)
			sb.set_border_width_all(int((0.008 if on else 0.004) * k))
		if lit:
			sb.shadow_color = Color(Kit.UI_ACCENT, 0.5)
			sb.shadow_size = int(0.012 * k)
		c.draw_style_box(sb, r)
		if is_start:
			var label: String = String(data.get("start", "START"))
			c.draw_string(ft, Vector2(r.position.x, r.get_center().y + 0.02 * k), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(0.07 * k), Color(0.06, 0.07, 0.09))
			c.draw_string(fh, Vector2(r.position.x, r.end.y - 0.035 * k), "SHOOT  OR  F", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(0.026 * k), Color(0.06, 0.07, 0.09, 0.7))
			continue
		if i >= tiles.size():
			continue
		var t: Array = tiles[i]
		var ink := Color(1, 1, 1)
		c.draw_string(ft, Vector2(r.position.x + 0.03 * k, r.position.y + 0.09 * k), String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.075 * k), Kit.UI_ACCENT if on else ink)
		# The title on up to two lines, broken between words: one line cut "LOCATE & ALI" (frame room/03, 5 Oct).
		var fit: float = r.size.x - 0.06 * k
		var lines: Array = [""]
		for word in String(t[1]).split(" "):
			var tried: String = (String(lines[-1]) + " " + word).strip_edges()
			if lines[-1] != "" and fh.get_string_size(tried, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.03 * k)).x > fit:
				lines.append(word)
			else:
				lines[-1] = tried
		for j in mini(lines.size(), 2):
			c.draw_string(fh, Vector2(r.position.x + 0.03 * k, r.position.y + (0.155 + 0.037 * float(j)) * k), String(lines[j]), HORIZONTAL_ALIGNMENT_LEFT, fit, int(0.03 * k), ink)
		var done: bool = bool(t[3])
		c.draw_string(fb, Vector2(r.position.x + 0.03 * k, r.end.y - 0.03 * k), String(t[2]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 0.05 * k, int(0.026 * k), Kit.UI_LIVE if done else Color(1, 1, 1, 0.6))
