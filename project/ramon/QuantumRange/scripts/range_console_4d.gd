extends Node4D

## The console: a floating panel in the kit's desk style (CreationLab/kit/kit_desk_4d.gd and its specimen
## picker, kit_exhibit_picker_4d.gd, built again here: nothing in CreationLab/ is touched): a light rounded
## plate with black glass on its face and a glow line under it, tilted up towards you, floating with no
## stand. The tiles are the same size as before, one per experiment, and START (Ramon, 6 Oct: "more like the
## floating panel in the kit, but keep the same size and icon ratio"); a sixth experiment widened the glass
## by one tile, from 1.9 to 2.19 m, so the tiles kept their shape.
##
## WHERE IT STANDS. In the middle of the bay, facing you as you come in through the door. Once you start
## something it flies out of the view downrange to a place close beside you, on your right and a little
## ahead, and keeps facing you, so from then on you work it from where you stand (Ramon, 6 Oct). Walk
## off and it follows. It faces you at any angle, which the physics could not pick (box-only: a turned
## tile collides as its square, and its neighbours' squares overlap it), so it is not picked by physics:
## pick() finds where your aim crosses the glass, exactly (range_weapon_4d.gd asks it every ray).
##
## THE PICTURE is the kit picker's: the card, a header with how to use it, and one slot per experiment
## with its key, its glyph and its name. The chosen one is lit blue, flaring as it is chosen, then
## breathing; it also shows the stage it starts from (A to D: press its number again, or shoot it again,
## for the next). A finished experiment carries a small green stopwatch and its best time.
##
## NUMBERED BOXES ARE BUTTONS (Ramon's rule for the kit): each one is pressed, never just lit. Shoot it,
## or look at it and press F; number keys pick too (the director). Each tile has a node with meta
## "range_button" (its index, 5 being START) that pick() hands the weapon.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/QuantumRange/carried/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/QuantumRange/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/QuantumRange/carried/LabKit/lab_print.gd")
const Kit := preload("res://ramon/QuantumRange/carried/kit/kit_style.gd")
const Glyphs := preload("res://ramon/QuantumRange/carried/kit/kit_glyphs.gd")
const Mats := preload("res://ramon/QuantumRange/scripts/range_mats.gd")
const Layout := preload("res://ramon/QuantumRange/scripts/range_layout.gd")

## The glass, and how finely its picture is drawn.
const SCREEN := Vector2(2.19, 0.42)
const PPM := 520.0
## One tile per experiment, and START.
const BUTTONS := 7
## The plate round the glass: its border, thickness and corner radius.
const MARGIN := 0.08
const SLAB := 0.06
const CORNER := 0.08
## Tilted back from upright so the glass looks up at you a little (degrees from the floor), its front
## edge floating this high.
const TILT := 58.0
const HOVER := 0.78
## How quickly it flies and turns to where it wants to be (per second, eased).
const FOLLOW := 3.0
## Its place beside you once you have started: right of you, a little ahead (metres), and how far you can
## walk from where you stood before it follows (looking round never moves it).
const BESIDE := Vector2(1.8, 0.3)
const FOLLOW_AFTER := 1.4
## While a stage runs it is not used (shots pass through it): it tucks back and down out of your view
## (beside you, its tiles filled the lower right whenever you aimed that way, play/wolf_1_card, 6 Oct).
const TUCKED := Vector3(0.5, -0.55, -1.1)

## What it shows: {"sel": int, "stage": int, "tiles": [[key, name, best, done, glyph], ...],
## "start": "START", "hover": int, "anchor": "lobby" | "near", "hint": String, "live": bool (pickable)}.
var data: Dictionary = {}
## Whose side it turns to.
var player: Node4D
## The room's turn to follow your slice (quantum_range_4d.gd room_view()): [basis, pivot], or [] for none.
var view: Array = []

var _vp: SubViewport
var _page: Control
var _screen: MeshInstance4D
var _slab: Node4D
var _buttons: Array = []
var _sig: int = 0
var _clock: float = 0.0
var _lit_at: float = -10.0
var _last_sel: int = -1
# Where it is and which way it faces, and its place beside you.
var _pos: Vector4 = Layout.CONSOLE_LOBBY
var _yaw: float = 0.0
var _spot: Vector4 = Layout.CONSOLE_LOBBY
var _has_spot: bool = false
# Where you stood when it took that place: it moves again only when you walk off, never as you look round.
var _spot_from: Vector4 = Vector4.ZERO


func _ready() -> void:
	_build()
	_place()


func _build() -> void:
	var th: float = deg_to_rad(TILT)
	var w: float = SCREEN.x + MARGIN * 2.0
	var d: float = SCREEN.y + MARGIN * 2.0
	# The slab, tilted about its own middle so its front edge floats HOVER over the floor (kit_desk_4d.gd).
	_slab = Node4D.new()
	_slab.name = "Slab"
	_slab.position = Vector4(0.0, HOVER + d * 0.5 * sin(th) + SLAB * 0.5 * cos(th), 0.0, 0.0)
	_slab.basis = Basis4D.from_yz(th)
	add_child(_slab)
	_rounded(_slab, "Plate", Vector2(w, d), SLAB, 0.0, CORNER, "range_bezel")
	_screen = MeshInstance4D.new()
	_screen.name = "Screen"
	var sc := Vector4(SCREEN.x, 0.02, SCREEN.y, Build.W_DEPTH)
	_screen.mesh = Mats.box(sc)
	_screen.position = Vector4(0.0, SLAB * 0.5 + 0.012, 0.0, 0.0)
	_screen.material_override = LabGrid.material("range_screen", sc, Vector4.ZERO)
	_slab.add_child(_screen)
	# A glow line round the underside, set in from the edge.
	var under: float = -SLAB * 0.5 - 0.008
	var inset: float = CORNER + 0.04
	for g in [[Vector3(0, under, d * 0.5 - 0.05), Vector3(w - inset * 2.0, 0.016, 0.03)], [Vector3(-w * 0.5 + 0.05, under, 0), Vector3(0.03, 0.016, d - inset * 2.0)],
			[Vector3(w * 0.5 - 0.05, under, 0), Vector3(0.03, 0.016, d - inset * 2.0)], [Vector3(0, under, -d * 0.5 + 0.05), Vector3(w - inset * 2.0, 0.016, 0.03)]]:
		var at: Vector3 = g[0]
		var sz: Vector3 = g[1]
		var line := MeshInstance4D.new()
		line.name = "Underglow"
		line.mesh = Mats.box(Vector4(sz.x, sz.y, sz.z, Build.W_DEPTH))
		line.position = Vector4(at.x, at.y, at.z, 0.0)
		line.material_override = Mats.glow(Kit.pick(Kit.COVE), 1.8)
		_slab.add_child(line)
	# The picture, drawn into a viewport of its own and printed on the glass.
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
	LabGrid.set_print(m, _vp.get_texture(), Vector4(0, 1, 0, 0), Rect2(Vector2.ZERO, SCREEN), Color.WHITE, 0.9)
	LabGrid.set_print_strength(m, 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)
	# One node per tile, at its middle on the glass, for the weapon to be handed (pick()).
	for i in BUTTONS:
		var button := Node4D.new()
		button.name = "Button%d" % i
		button.position = _on_glass(_tile_m(i).get_center())
		button.set_meta("range_button", i)
		add_child(button)
		_buttons.append(button)


## Where a ray from `origin` along `dir` (world, unit length) crosses the glass, if it does on a tile:
## {"button": index, "node": that tile's node, "distance": metres, "point": world}, else {}.
func pick(origin: Vector4, dir: Vector4) -> Dictionary:
	# While a stage runs it stands beside you, low: shots pass through it, so one meant for a target on
	# your right never picks another experiment and ends the run.
	if not is_inside_tree() or _slab == null or not bool(data.get("live", true)):
		return {}
	var inv: Projection = global_basis.inverse()
	var o: Vector4 = inv * (origin - global_position)
	var d: Vector4 = inv * dir
	var sinv: Projection = _slab.basis.inverse()
	o = sinv * (o - _slab.position)
	d = sinv * d
	if absf(d.y) < 0.000001:
		return {}
	var t: float = (SLAB * 0.5 + 0.022 - o.y) / d.y
	if t <= 0.0:
		return {}
	var p: Vector4 = o + d * t
	if absf(p.w) > Build.W_DEPTH * 0.5:
		return {}
	var g := Vector2(p.x + SCREEN.x * 0.5, SCREEN.y * 0.5 - p.z)
	for i in BUTTONS:
		if _tile_m(i).has_point(g):
			return {"button": i, "node": _buttons[i], "distance": t, "point": origin + dir * t}
	return {}


## A point on the glass, in metres from its lower-left corner as the picture is drawn (x right, y up),
## in the console's own space. The picture's foot is the glass's front edge, the low one nearest you.
func _on_glass(g: Vector2) -> Vector4:
	var local := Vector4(g.x - SCREEN.x * 0.5, SLAB * 0.5 + 0.022, SCREEN.y * 0.5 - g.y, 0.0)
	return _slab.position + _slab.basis * local


## A rounded plate `s` (x, z) by `t` thick (kit_desk_4d.gd _rounded): a box the full width with the
## corners' depth taken off, a box the full depth with their width taken off, a cylinder in each corner.
func _rounded(parent: Node4D, nm: String, s: Vector2, t: float, y: float, r: float, swatch: String) -> void:
	var a := MeshInstance4D.new()
	a.name = nm
	var sa := Vector4(s.x, t, s.y - r * 2.0, Build.W_DEPTH)
	a.mesh = Mats.box(sa)
	a.position = Vector4(0.0, y, 0.0, 0.0)
	a.material_override = LabGrid.material(swatch, sa, Vector4.ZERO)
	parent.add_child(a)
	var b := MeshInstance4D.new()
	b.name = nm + "Ends"
	var sb := Vector4(s.x - r * 2.0, t - 0.002, s.y, Build.W_DEPTH)
	b.mesh = Mats.box(sb)
	b.position = Vector4(0.0, y - 0.001, 0.0, 0.0)
	b.material_override = LabGrid.material(swatch, sb, Vector4.ZERO)
	parent.add_child(b)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var c := MeshInstance4D.new()
			c.name = nm + "Corner"
			c.mesh = Build._cubinder(r, t - 0.002, 32)
			c.position = Vector4(cx * (s.x * 0.5 - r), y - 0.001, cz * (s.y * 0.5 - r), 0.0)
			c.material_override = LabGrid.material(swatch, Vector4(r * 2.0, t, r * 2.0, Build.W_DEPTH), Vector4.ZERO)
			parent.add_child(c)


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
	if int(d.get("sel", -1)) != _last_sel:
		_last_sel = int(d.get("sel", -1))
		_lit_at = _clock
	var sig: int = hash(str(d))
	if sig != _sig:
		_sig = sig
		_redraw()


func _redraw() -> void:
	_page.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# -- where it stands ---------------------------------------------------------------------------------

## Beside you: right of the way you face (with your slice level) and a little ahead, kept in the bay.
func _beside() -> Vector4:
	var b: Projection = player.call("level_basis")
	var f: Vector4 = -b.z
	var r: Vector4 = b.x
	var at: Vector4 = player.global_position + r * BESIDE.x + f * BESIDE.y
	return Vector4(clampf(at.x, -Layout.BAY_HALF + 1.3, Layout.BAY_HALF - 1.3), 0.0,
		clampf(at.z, Layout.line_hold() + 0.4, Layout.BAY_BACK - 0.6), 0.0)


func _process(delta: float) -> void:
	_clock += delta
	var to: Vector4 = Layout.CONSOLE_LOBBY
	if String(data.get("anchor", "lobby")) == "near" and player != null:
		# A new place beside you once you have walked off from where you stood; turning to look at it
		# (or anywhere else) leaves it where it is.
		var pp: Vector4 = player.global_position
		if not _has_spot or Vector2(pp.x - _spot_from.x, pp.z - _spot_from.z).length() > FOLLOW_AFTER:
			_spot = _beside()
			_spot_from = pp
			_has_spot = true
		to = _spot
		if not bool(data.get("live", true)):
			var b: Projection = player.call("level_basis")
			to += b.x * TUCKED.x + Vector4(0.0, TUCKED.y, 0.0, 0.0) - b.z * TUCKED.z
	var k: float = 1.0 - exp(-delta * FOLLOW)
	_pos = _pos.lerp(to, k)
	# Facing you, from where it is.
	if player != null:
		var d := Vector2(player.global_position.x - _pos.x, player.global_position.z - _pos.z)
		if d.length() > 0.3:
			_yaw = lerp_angle(_yaw, atan2(d.x, d.y), 1.0 - exp(-delta * FOLLOW * 1.6))
	_place()
	# The chosen tile flares, then breathes: redraw while it moves.
	if _clock - _lit_at < 0.7 or int(Engine.get_process_frames()) % 6 == 0:
		_redraw()


## Its own place and turn, then the room's turn round you (when the room follows your slice).
func _place() -> void:
	var b: Projection = Basis4D.from_zx(_yaw)
	var p: Vector4 = _pos
	if view.size() == 2:
		var r: Projection = view[0]
		var e: Vector4 = view[1]
		b = r * b
		p = r * (p - e) + e
	basis = b
	position = p


# -- the picture --------------------------------------------------------------------------------------

func _paint() -> void:
	var c: Control = _page
	var sz: Vector2 = c.size
	var k: float = PPM
	var u: float = sz.y / 276.0
	var blue: Color = Kit.UI_ACCENT
	var grey: Color = Kit.UI_GREY
	var green: Color = Kit.UI_LIVE
	var bg := Color(Kit.UI_GLASS, 1.0)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	# The card.
	var card := StyleBoxFlat.new()
	card.bg_color = bg
	card.set_corner_radius_all(int(18.0 * u))
	card.anti_aliasing = true
	c.draw_style_box(card, Rect2(Vector2.ZERO, sz))
	# The header: what it is, and how to use it.
	var mg: float = 0.04 * k
	c.draw_string(fb, Vector2(mg, 34.0 * u), "EXPERIMENTS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22.0 * u), grey)
	var hint: String = String(data.get("hint", "PRESS 1 TO 6, AGAIN FOR A STAGE"))
	c.draw_string(fs, Vector2(0.0, 33.0 * u), hint, HORIZONTAL_ALIGNMENT_RIGHT, sz.x - mg, int(16.0 * u), Color(grey, 0.6))
	var tiles: Array = data.get("tiles", [])
	var sel: int = int(data.get("sel", 0))
	var stage: int = int(data.get("stage", 0))
	var hover: int = int(data.get("hover", -1))
	for i in BUTTONS:
		var rm: Rect2 = _tile_m(i)
		# Metres from the lower left to pixels from the upper left.
		var r := Rect2(Vector2(rm.position.x * k, sz.y - (rm.position.y + rm.size.y) * k), rm.size * k)
		var lit: bool = i == sel
		var aimed: bool = i == hover
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(12.0 * u))
		box.anti_aliasing = true
		if i == BUTTONS - 1:
			# START: the one white tile.
			box.bg_color = Color(0.96, 0.97, 0.98) if not aimed else Color(1, 1, 1)
			if aimed:
				box.shadow_color = Color(blue, 0.6)
				box.shadow_size = int(10.0 * u)
			c.draw_style_box(box, r)
			var dark := Color(0.06, 0.07, 0.09)
			c.draw_string(fb, Vector2(r.position.x, r.get_center().y + 12.0 * u), String(data.get("start", "START")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(34.0 * u), dark)
			c.draw_string(fs, Vector2(r.position.x, r.end.y - 16.0 * u), "SHOOT  OR  F", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(14.0 * u), Color(dark, 0.7))
			continue
		if i >= tiles.size():
			continue
		var t: Array = tiles[i]
		if lit:
			# Lit: a blue edge that flares as it is chosen, then breathes (kit_exhibit_picker_4d.gd).
			var flare: float = clampf(1.0 - (_clock - _lit_at) / 0.6, 0.0, 1.0)
			box.bg_color = Color(blue, 0.14 + 0.16 * flare)
			box.border_color = Color(blue, 0.85 + 0.15 * sin(_clock * 3.0))
			box.set_border_width_all(int(maxf(2.0, 3.5 * u)))
		else:
			box.bg_color = Color(1, 1, 1, 0.07 if aimed else 0.04)
			box.border_color = Color(grey, 0.55 if aimed else 0.30)
			box.set_border_width_all(int(maxf(1.0, 2.0 * u)))
		c.draw_style_box(box, r)
		var ink: Color = blue if lit else grey
		# The key, top left.
		c.draw_string(fs, r.position + Vector2(12.0 * u, 26.0 * u), String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * u), ink)
		# Finished: a small green stopwatch and the best time, top right.
		if bool(t[3]):
			var best: String = String(t[2])
			var bw: float = fs.get_string_size(best, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * u)).x
			var bx: float = r.end.x - 10.0 * u - bw
			c.draw_string(fs, Vector2(bx, 25.0 * u + r.position.y), best, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * u), green)
			_stopwatch(c, Vector2(bx - 11.0 * u, r.position.y + 20.0 * u), 7.0 * u, green)
		# The glyph, the stage row, the name.
		var icon_r := Rect2(r.position + Vector2(r.size.x * 0.16, 34.0 * u), Vector2(r.size.x * 0.68, r.size.y - 92.0 * u))
		Glyphs.animal(c, String(t[4]), icon_r, ink, bg.lerp(ink, 0.12) if lit else bg)
		if lit:
			_stages(c, Rect2(r.position.x, r.end.y - 52.0 * u, r.size.x, 18.0 * u), stage, u, fs, blue)
		c.draw_string(fs, Vector2(r.position.x, r.end.y - 14.0 * u), String(t[1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(16.0 * u), ink)


## Four stage chips, A to D, the one it starts from filled.
func _stages(c: Control, row: Rect2, on: int, u: float, f: Font, blue: Color) -> void:
	var cw: float = 20.0 * u
	var gap: float = 5.0 * u
	var x0: float = row.get_center().x - (cw * 4.0 + gap * 3.0) * 0.5
	for j in 4:
		var r := Rect2(Vector2(x0 + float(j) * (cw + gap), row.position.y), Vector2(cw, row.size.y))
		var chip := StyleBoxFlat.new()
		chip.set_corner_radius_all(int(5.0 * u))
		chip.anti_aliasing = true
		if j == on:
			chip.bg_color = blue
		else:
			chip.bg_color = Color(1, 1, 1, 0.0)
			chip.border_color = Color(blue, 0.5)
			chip.set_border_width_all(int(maxf(1.0, 1.5 * u)))
		c.draw_style_box(chip, r)
		var ink: Color = Color(Kit.UI_GLASS, 1.0) if j == on else Color(blue, 0.8)
		c.draw_string(f, Vector2(r.position.x, r.end.y - 4.0 * u), char(65 + j), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(12.0 * u), ink)


## A small stopwatch: a ring, a crown on top, one hand.
func _stopwatch(c: Control, at: Vector2, r: float, col: Color) -> void:
	c.draw_arc(at, r, 0.0, TAU, 24, col, maxf(1.0, r * 0.28), true)
	c.draw_line(at + Vector2(0, -r), at + Vector2(0, -r * 1.45), col, maxf(1.0, r * 0.3), true)
	c.draw_line(at, at + Vector2(r * 0.45, -r * 0.45), col, maxf(1.0, r * 0.22), true)
