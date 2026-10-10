extends Node4D

## The level console (PLAN.md step 52): the Shooting Range's floating panel (QuantumRange/scripts/
## range_console_4d.gd, copied, not shared) with six level tiles and START. A light rounded plate with
## black glass on its face and a glow line under it, tilted up towards you.
##
## WHERE IT STANDS (round 3, Ramon, 10 Oct: "the level-selection panel currently appears to move with
## the player ... I'd prefer a static panel"). It stands still: in the lobby in the back left corner,
## between the Phase Maze wall and the back wall, turned to face you as you come in (anchor "lobby");
## in the hall at one place beside where you arrive, facing you (anchor "near"). The game gives it both
## places (`spots`). It used to turn to you every frame and fly to your side after a level.
## A plinth under it collides, so you walk round it, not through it. It is only as deep in W as a body,
## not the range's 24 m, so it can never show through into other cells of the maze.
##
## NUMBERED BOXES ARE BUTTONS (the kit's rule): every tile is pressed, never just lit. Click it (where
## your aim crosses the glass, pick()), or press its number; Enter presses START.
##
## NO class_name (engine_gotchas.md).

const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_print.gd")
const LabMaterials := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_materials.gd")
const Build := preload("res://ramon/PhaseMazeRemake/carried/scripts/chamber_build.gd")
const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const Glyphs := preload("res://ramon/PhaseMazeRemake/hud/maze_glyphs.gd")

const SCREEN := Vector2(2.19, 0.42)
const PPM := 520.0
## Six levels and START.
const BUTTONS := 7
const MARGIN := 0.08
const SLAB := 0.06
const CORNER := 0.08
const TILT := 58.0
const HOVER := 0.78
## Thickness through W: about a body's, so it shows only in the cell it stands in.
const W_DEPTH := 1.2

## What it shows: {"sel": int, "tiles": [[key, name, best, done, glyph, par], ...], "start": "START",
## "hover": int, "anchor": "lobby" | "near", "hint": String, "live": bool}.
var data: Dictionary = {}
## Whose side it turns to, and the frame it stands beside you in (anything with level_basis()).
var player: Node4D
var frame: Node
## Its place in the lobby.
var home: Vector4 = Vector4.ZERO
## Where "near" may put it: [low corner, high corner] in x and z (the exit's cell, inset).
var room: Array = []
## Its fixed places: {anchor: [position, yaw]}. An anchor not in here falls back to `home`, facing +z.
var spots: Dictionary = {}

var _vp: SubViewport
var _page: Control
var _screen: MeshInstance4D
var _slab: Node4D
var _buttons: Array = []
var _sig: int = 0
var _clock: float = 0.0
var _lit_at: float = -10.0
var _last_sel: int = -1
var _pos: Vector4 = Vector4.ZERO
var _yaw: float = 0.0
var _anchor: String = "lobby"


func _ready() -> void:
	_pos = home
	_build()
	_place()


func _build() -> void:
	var th: float = deg_to_rad(TILT)
	var w: float = SCREEN.x + MARGIN * 2.0
	var d: float = SCREEN.y + MARGIN * 2.0
	_slab = Node4D.new()
	_slab.name = "Slab"
	_slab.position = Vector4(0.0, HOVER + d * 0.5 * sin(th) + SLAB * 0.5 * cos(th), 0.0, 0.0)
	_slab.basis = Basis4D.from_yz(th)
	add_child(_slab)
	_rounded(_slab, "Plate", Vector2(w, d), SLAB, 0.0, CORNER, "maze_bezel")
	_screen = MeshInstance4D.new()
	_screen.name = "Screen"
	var sc := Vector4(SCREEN.x, 0.02, SCREEN.y, W_DEPTH)
	_screen.mesh = _box(sc)
	_screen.position = Vector4(0.0, SLAB * 0.5 + 0.012, 0.0, 0.0)
	_screen.material_override = LabGrid.material("maze_screen", sc, Vector4.ZERO)
	_slab.add_child(_screen)
	var under: float = -SLAB * 0.5 - 0.008
	var inset: float = CORNER + 0.04
	for g in [[Vector3(0, under, d * 0.5 - 0.05), Vector3(w - inset * 2.0, 0.016, 0.03)], [Vector3(-w * 0.5 + 0.05, under, 0), Vector3(0.03, 0.016, d - inset * 2.0)],
			[Vector3(w * 0.5 - 0.05, under, 0), Vector3(0.03, 0.016, d - inset * 2.0)], [Vector3(0, under, -d * 0.5 + 0.05), Vector3(w - inset * 2.0, 0.016, 0.03)]]:
		var at: Vector3 = g[0]
		var sz: Vector3 = g[1]
		var line := MeshInstance4D.new()
		line.name = "Underglow"
		line.mesh = _box(Vector4(sz.x, sz.y, sz.z, W_DEPTH))
		line.position = Vector4(at.x, at.y, at.z, 0.0)
		line.material_override = LabMaterials.glow(Kit.pick(Kit.COVE), 1.8)
		_slab.add_child(line)
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
	for i in BUTTONS:
		var button := Node4D.new()
		button.name = "Button%d" % i
		button.position = _on_glass(_tile_m(i).get_center())
		button.set_meta("maze_button", i)
		add_child(button)
		_buttons.append(button)
	_plinth()
	for mi in find_children("*", "MeshInstance4D", true, false):
		(mi as MeshInstance4D).set("allow_projection", false)


## A plinth under the plate, in the kit's dark plinth colour, and a collider round the whole console,
## so the walker stops in front of it instead of walking into it.
func _plinth() -> void:
	var size := Vector4(SCREEN.x * 0.86, HOVER + 0.02, 0.34, W_DEPTH)
	var mi := MeshInstance4D.new()
	mi.name = "Plinth"
	mi.mesh = _box(size)
	mi.position = Vector4(0.0, size.y * 0.5, 0.05, 0.0)
	mi.material_override = LabMaterials.flat(Kit.pick(Kit.PLINTH))
	add_child(mi)
	var body := StaticBody4D.new()
	body.name = "Stand"
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(SCREEN.x + MARGIN * 2.0 + 0.1, 1.3, 0.9, W_DEPTH)
	shape.shape = box
	shape.position = Vector4(0.0, 0.65, 0.0, 0.0)
	body.add_child(shape)
	add_child(body)


static func _box(size: Vector4) -> BoxTetraMesh4D:
	var b := BoxTetraMesh4D.new()
	b.size = size
	return b


## Where a ray from `origin` along `dir` crosses the glass on a tile: {"button", "node", "distance",
## "point"}, else {}.
func pick(origin: Vector4, dir: Vector4) -> Dictionary:
	if not is_inside_tree() or _slab == null or not visible or not bool(data.get("live", true)):
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
	# 20 m: the console stands in the lobby's corner, 13.5 m from where you arrive (round 3).
	if t <= 0.0 or t > 20.0:
		return {}
	var p: Vector4 = o + d * t
	if absf(p.w) > W_DEPTH * 0.5:
		return {}
	var g := Vector2(p.x + SCREEN.x * 0.5, SCREEN.y * 0.5 - p.z)
	for i in BUTTONS:
		if _tile_m(i).has_point(g):
			return {"button": i, "node": _buttons[i], "distance": t, "point": origin + dir * t}
	return {}


func _on_glass(g: Vector2) -> Vector4:
	var local := Vector4(g.x - SCREEN.x * 0.5, SLAB * 0.5 + 0.022, SCREEN.y * 0.5 - g.y, 0.0)
	return _slab.position + _slab.basis * local


func _rounded(parent: Node4D, nm: String, s: Vector2, t: float, y: float, r: float, swatch: String) -> void:
	var a := MeshInstance4D.new()
	a.name = nm
	var sa := Vector4(s.x, t, s.y - r * 2.0, W_DEPTH)
	a.mesh = _box(sa)
	a.position = Vector4(0.0, y, 0.0, 0.0)
	a.material_override = LabGrid.material(swatch, sa, Vector4.ZERO)
	parent.add_child(a)
	var b := MeshInstance4D.new()
	b.name = nm + "Ends"
	var sb := Vector4(s.x - r * 2.0, t - 0.002, s.y, W_DEPTH)
	b.mesh = _box(sb)
	b.position = Vector4(0.0, y - 0.001, 0.0, 0.0)
	b.material_override = LabGrid.material(swatch, sb, Vector4.ZERO)
	parent.add_child(b)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var c := MeshInstance4D.new()
			c.name = nm + "Corner"
			c.mesh = _box(Vector4(r * 2.0, t - 0.002, r * 2.0, W_DEPTH))
			c.position = Vector4(cx * (s.x * 0.5 - r), y - 0.001, cz * (s.y * 0.5 - r), 0.0)
			c.material_override = LabGrid.material(swatch, Vector4(r * 2.0, t, r * 2.0, W_DEPTH), Vector4.ZERO)
			parent.add_child(c)


func _tile_m(i: int) -> Rect2:
	var pad: float = 0.04
	var gap: float = 0.025
	var start_w: float = 0.38
	var w: float = (SCREEN.x - pad * 2.0 - start_w - gap * float(BUTTONS - 1)) / float(BUTTONS - 1)
	var h: float = SCREEN.y - 0.12
	var x: float = pad + (w + gap) * float(i)
	return Rect2(Vector2(x, 0.05), Vector2(start_w if i == BUTTONS - 1 else w, h))


func show_data(d: Dictionary) -> void:
	data = d
	var anchor: String = String(d.get("anchor", "lobby"))
	if anchor != _anchor:
		_anchor = anchor
	if int(d.get("sel", -1)) != _last_sel:
		_last_sel = int(d.get("sel", -1))
		_lit_at = _clock
	var sig: int = hash(str(d))
	if sig != _sig:
		_sig = sig
		_redraw()


## Straight to where it should be (a level loaded, a restart): no flight across the maze.
func snap() -> void:
	_process(0.0)


func _redraw() -> void:
	_page.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Where it stands for the anchor in force, and which way it faces: fixed, never following you.
func _goal() -> Vector4:
	if spots.has(_anchor):
		return spots[_anchor][0]
	return home


func _goal_yaw() -> float:
	if spots.has(_anchor):
		return float(spots[_anchor][1])
	return 0.0


func _process(delta: float) -> void:
	_clock += delta
	# Straight to its place (the lobby and the hall change behind a fade), never gliding after you.
	_pos = _goal()
	_yaw = _goal_yaw()
	_place()
	if _clock - _lit_at < 0.7 or int(Engine.get_process_frames()) % 6 == 0:
		_redraw()


func _place() -> void:
	basis = Basis4D.from_zx(_yaw)
	position = _pos


# -- the picture --------------------------------------------------------------------------------------

func _paint() -> void:
	var c: Control = _page
	var sz: Vector2 = c.size
	var k: float = PPM
	var u: float = sz.y / 276.0
	var blue: Color = Kit.UI_ACCENT
	var grey: Color = Kit.UI_GREY
	# Finished and best: the pen's landmark orange (round 2: the pen's dev colours, not the kit's green).
	var green: Color = Color(0.95, 0.46, 0.30)
	var bg := Color(Kit.UI_GLASS, 1.0)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var card := StyleBoxFlat.new()
	card.bg_color = bg
	card.set_corner_radius_all(int(18.0 * u))
	card.anti_aliasing = true
	c.draw_style_box(card, Rect2(Vector2.ZERO, sz))
	var mg: float = 0.04 * k
	c.draw_string(fb, Vector2(mg, 34.0 * u), "PHASE MAZE  ·  LEVELS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22.0 * u), grey)
	var hint: String = String(data.get("hint", "PRESS 1 TO 6 OR CLICK A LEVEL, THEN START"))
	c.draw_string(fs, Vector2(0.0, 33.0 * u), hint, HORIZONTAL_ALIGNMENT_RIGHT, sz.x - mg, int(16.0 * u), Color(grey, 0.6))
	var tiles: Array = data.get("tiles", [])
	var sel: int = int(data.get("sel", 0))
	var hover: int = int(data.get("hover", -1))
	for i in BUTTONS:
		var rm: Rect2 = _tile_m(i)
		var r := Rect2(Vector2(rm.position.x * k, sz.y - (rm.position.y + rm.size.y) * k), rm.size * k)
		var lit: bool = i == sel
		var aimed: bool = i == hover
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(int(12.0 * u))
		box.anti_aliasing = true
		if i == BUTTONS - 1:
			box.bg_color = Color(0.96, 0.97, 0.98) if not aimed else Color(1, 1, 1)
			if aimed:
				box.shadow_color = Color(blue, 0.6)
				box.shadow_size = int(10.0 * u)
			c.draw_style_box(box, r)
			var dark := Color(0.06, 0.07, 0.09)
			c.draw_string(fb, Vector2(r.position.x, r.get_center().y + 12.0 * u), String(data.get("start", "START")), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(34.0 * u), dark)
			c.draw_string(fs, Vector2(r.position.x, r.end.y - 16.0 * u), "CLICK  OR  ENTER", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(14.0 * u), Color(dark, 0.7))
			continue
		if i >= tiles.size():
			continue
		var t: Array = tiles[i]
		if lit:
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
		c.draw_string(fs, r.position + Vector2(12.0 * u, 26.0 * u), String(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * u), ink)
		if bool(t[3]):
			var best: String = String(t[2])
			var bw: float = fs.get_string_size(best, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * u)).x
			var bx: float = r.end.x - 10.0 * u - bw
			c.draw_string(fs, Vector2(bx, 25.0 * u + r.position.y), best, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13.0 * u), green)
			_stopwatch(c, Vector2(bx - 11.0 * u, r.position.y + 20.0 * u), 7.0 * u, green)
		var icon_r := Rect2(r.position + Vector2(r.size.x * 0.2, 38.0 * u), Vector2(r.size.x * 0.6, r.size.y - 100.0 * u))
		Glyphs.draw(c, String(t[4]), icon_r, ink)
		if lit and t.size() > 5 and String(t[5]) != "":
			c.draw_string(fs, Vector2(r.position.x, r.end.y - 40.0 * u), String(t[5]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(13.0 * u), Color(blue, 0.85))
		c.draw_string(fs, Vector2(r.position.x, r.end.y - 14.0 * u), String(t[1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(16.0 * u), ink)


func _stopwatch(c: Control, at: Vector2, r: float, col: Color) -> void:
	c.draw_arc(at, r, 0.0, TAU, 24, col, maxf(1.0, r * 0.28), true)
	c.draw_line(at + Vector2(0, -r), at + Vector2(0, -r * 1.45), col, maxf(1.0, r * 0.3), true)
	c.draw_line(at, at + Vector2(r * 0.45, -r * 0.45), col, maxf(1.0, r * 0.22), true)
