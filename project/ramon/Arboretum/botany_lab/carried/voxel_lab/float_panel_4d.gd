extends Node4D

## WATER LAB COPY (9 Oct 2026) of VoxelLab/room/vl_float_panel_4d.gd, for the koi showcase (Ramon:
## "one of the floating panels from voxel lab so that when you activate it, you can see some infos on
## it"). What is new here: PAGES. `source` (a node with face() and panel_pages()) gives the summary
## and a few pages of more; activate() (the room's E) turns to the next page, past the last back to
## the summary, the underglow brighter while a page is open. A page is {title, kicker, text} or
## {title, kicker, rows}. The face says "E  MORE" while you are near.
##
## The Voxel Lab's floating panel beside an exhibit (Ramon, 8 Oct: "in the shooting range, the new one,
## we have this kind of floating panel ... it wobbles a bit when you move against it, like put it here
## and put it close to the block"; "a bit less wide than in the shooting range"). It takes the place of
## the consoles you pressed E at.
##
## THE BUILD is the Quantum Range console's (QuantumRange/scripts/range_console_4d.gd, built again here
## from the lab's carried kit, nothing there touched): a light rounded plate with black glass on its
## face and a glow line under it, tilted up towards you, floating with no stand. Narrower: `width`
## metres of glass (the range's was 2.19).
##
## THE WOBBLE is new: the range's console only eased to follow you, it never wobbled. Here it is on a
## spring. It bobs a little on its own; walk into it and it is pushed away from you, swings back, and
## tilts as it goes, settling in a second or two.
##
## ITS FACE: the exhibit's number, its title and a line, and up to three live numbers, read from the
## station every half second (`face()` of the exhibit, else its numbers()).
##
## ROUND 2 (Ramon, 9 Oct: "I can walk straight through the little panel ... and also the panel doesn't
## move with me. Like it's dynamic ... it tilts a little bit and moves a little bit when you walk close
## to it, and it follows you a little bit"):
##   the spring now reads you in its parent's frame (the Voxel Lab's later fix: in a parent away from
##   the origin it never felt you); within `notice` metres it leans a little toward you (`follow`
##   metres at most) and turns part way to face you (`turn_to_you`); a solid box under it, left where
##   it was put, stops you walking through it. `number` 0 hides the number; with no station and no
##   source it shows `rows`; `hint` is what the bottom line says while you are near.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/Arboretum/botany_lab/carried/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")
const Mats := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_materials.gd")
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")
const Glyphs := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_glyphs.gd")

## The glass, metres (width, depth up the slope), and how finely its picture is drawn.
@export var width: float = 1.3
@export var depth: float = 0.5
const PPM := 520.0
const MARGIN := 0.07
const SLAB := 0.06
const CORNER := 0.07
## Tilted up towards you (degrees from the floor), its front edge this high.
@export var tilt: float = 58.0
@export var hover: float = 0.95

@export_group("Face")
@export var number: int = 1
@export var title: String = "The block"
@export var kicker: String = "THE ENGINE'S VOXELS, CUT LIVE"
## The station it is about (a kit showcase); its exhibit fills in the numbers.
@export var station: NodePath
## WATER LAB: what it says, a node with face() (the summary's rows) and panel_pages(); wins over
## `station`.
@export var source: NodePath
## The point it turns its face to (x, z), usually the exhibit's ring.
@export var face_point: Vector2 = Vector2.ZERO

@export_group("Spring")
## How close you can come (metres from its middle) before it is pushed, and how far it gives.
@export var reach: float = 0.95
@export var give: float = 0.45
@export var stiffness: float = 26.0
@export var damping: float = 4.2
## Within this many metres it leans toward you, at most `follow` metres, and turns this share of the
## way round to face you.
@export var notice: float = 3.2
@export var follow: float = 0.22
@export_range(0.0, 1.0) var turn_to_you: float = 0.45
## A solid box under it (you cannot walk through it).
@export var solid: bool = true
## Turned to face you wherever you are in the room, not only near (round 3, Ramon: "I would always
## make the panel face the direction of the player ... no matter where you are in the room").
@export var face_always: bool = false
## The glow lines under its plate (round 3: off on the showcase's: "remove all the cyan lines").
@export var underglow: bool = true

@export_group("Words")
## Shown when there is no station and no source: [[label, value], ...].
@export var rows: Array = []
## The bottom line while you are near ("" the pages' own).
@export var hint: String = ""

## Who bumps into it.
var player: Node4D

var _slab: Node4D
var _body: Node4D
var _vp: SubViewport
var _page: Control
var _screen: MeshInstance4D
var _home: Vector4
var _yaw: float = 0.0
var _off := Vector2.ZERO
var _vel := Vector2.ZERO
var _t: float = 0.0
var _read_t: float = 0.0
var _data: Dictionary = {}
var _sig: String = ""
## WATER LAB: the page open (-1 the summary), whether you are near (the hint shows), the glow lines.
var page_index: int = -1
var near: bool = false
var _glows: Array = []
var _home_yaw: float = 0.0


func _ready() -> void:
	_home = position
	var d := Vector2(face_point.x - position.x, face_point.y - position.z)
	_yaw = atan2(d.x, d.y) if d.length() > 0.01 else 0.0
	_home_yaw = _yaw
	_build()
	_read()
	if solid and not Engine.is_editor_hint():
		_make_solid.call_deferred()


## The solid box: in the parent, where the panel was put, turned as it was (it does not swing).
func _make_solid() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var body := StaticBody4D.new()
	body.name = name + "Solid"
	body.position = _home + Vector4(0.0, 0.6, 0.0, 0.0)
	body.basis = Basis4D.from_zx(_home_yaw)
	var shape := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = Vector4(minf(width, 1.0), 1.2, 0.5, Build.W_DEPTH)
	shape.shape = bs
	body.add_child(shape)
	parent.add_child(body)


func _build() -> void:
	var th: float = deg_to_rad(tilt)
	var w: float = width + MARGIN * 2.0
	var dd: float = depth + MARGIN * 2.0
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	_slab = Node4D.new()
	_slab.name = "Slab"
	_slab.position = Vector4(0.0, hover + dd * 0.5 * sin(th) + SLAB * 0.5 * cos(th), 0.0, 0.0)
	_slab.basis = Basis4D.from_yz(th)
	_body.add_child(_slab)
	_rounded(_slab, "Plate", Vector2(w, dd), SLAB, 0.0, CORNER, "kit_bezel")
	_screen = MeshInstance4D.new()
	_screen.name = "Screen"
	var sc := Vector4(width, 0.02, depth, Build.W_DEPTH)
	_screen.mesh = Mats.box_mesh(sc)
	_screen.position = Vector4(0.0, SLAB * 0.5 + 0.012, 0.0, 0.0)
	_screen.material_override = LabGrid.material("kit_glass", sc, Vector4.ZERO)
	_slab.add_child(_screen)
	var under: float = -SLAB * 0.5 - 0.008
	var inset: float = CORNER + 0.04
	for g in [[Vector3(0, under, dd * 0.5 - 0.05), Vector3(w - inset * 2.0, 0.016, 0.03)], [Vector3(-w * 0.5 + 0.05, under, 0), Vector3(0.03, 0.016, dd - inset * 2.0)],
			[Vector3(w * 0.5 - 0.05, under, 0), Vector3(0.03, 0.016, dd - inset * 2.0)], [Vector3(0, under, -dd * 0.5 + 0.05), Vector3(w - inset * 2.0, 0.016, 0.03)]]:
		var at: Vector3 = g[0]
		var sz: Vector3 = g[1]
		if not underglow:
			continue
		var line := MeshInstance4D.new()
		line.name = "Underglow"
		line.mesh = Mats.box_mesh(Vector4(sz.x, sz.y, sz.z, Build.W_DEPTH))
		line.position = Vector4(at.x, at.y, at.z, 0.0)
		line.material_override = Mats.glow(Style.pick(Style.COVE), 1.8)
		_slab.add_child(line)
		_glows.append(line)
	_vp = SubViewport.new()
	_vp.name = "PanelView"
	_vp.size = Vector2i(int(width * PPM), int(depth * PPM))
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
	LabGrid.set_print(m, _vp.get_texture(), Vector4(0, 1, 0, 0), Rect2(Vector2.ZERO, Vector2(width, depth)), Color.WHITE, 0.9)
	LabGrid.set_print_strength(m, 1.0)
	m.get_cross_section_material_3d().set_shader_parameter("print_aa", 1.0)


func _rounded(parent: Node4D, nm: String, s: Vector2, t: float, y: float, r: float, swatch: String) -> void:
	var a := MeshInstance4D.new()
	a.name = nm
	var sa := Vector4(s.x, t, s.y - r * 2.0, Build.W_DEPTH)
	a.mesh = Mats.box_mesh(sa)
	a.position = Vector4(0.0, y, 0.0, 0.0)
	a.material_override = LabGrid.material(swatch, sa, Vector4.ZERO)
	parent.add_child(a)
	var b := MeshInstance4D.new()
	b.name = nm + "Ends"
	var sb := Vector4(s.x - r * 2.0, t - 0.002, s.y, Build.W_DEPTH)
	b.mesh = Mats.box_mesh(sb)
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


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	# The spring: pushed away from you while you are within reach, always pulled home.
	var target := Vector2.ZERO
	var want_yaw: float = _home_yaw
	if player != null and is_instance_valid(player):
		var p: Vector4 = player.global_position
		# In the parent's frame, where _home is.
		var parent := get_parent() as Node4D
		if parent != null:
			p = parent.global_basis.inverse() * (p - parent.global_position)
		var away := Vector2(_home.x + _off.x - p.x, _home.z + _off.y - p.z)
		var d: float = away.length()
		if d < reach and d > 0.001:
			target = away / d * minf(give, (reach - d) * 1.6) + _off
		elif d < notice and d > 0.001:
			# Leaning a little toward you, and turning part way round to you.
			var k: float = 1.0 - smoothstep(reach, notice, d)
			target = -away / d * follow * k
			var to_you: float = atan2(-away.x, -away.y)
			want_yaw = lerp_angle(_home_yaw, to_you, turn_to_you * clampf(k * 1.6, 0.0, 1.0))
		if face_always and d > 0.001:
			want_yaw = atan2(-away.x, -away.y)
	_yaw = lerp_angle(_yaw, want_yaw, 1.0 - exp(-delta * 2.5))
	var acc: Vector2 = (target - _off) * stiffness - _vel * damping
	_vel += acc * delta
	_off += _vel * delta
	_off = _off.limit_length(give * 1.4)
	var bob: float = sin(_t * 1.3) * 0.018
	position = _home + Vector4(_off.x, bob, _off.y, 0.0)
	# Leaning with its swing: the velocity, in its own frame, tips it about its two floor axes.
	var local: Vector2 = _vel.rotated(_yaw)
	basis = Basis4D.from_zx(_yaw) * Basis4D.from_xy(clampf(-local.x * 0.12, -0.3, 0.3)) * Basis4D.from_yz(clampf(local.y * 0.10, -0.25, 0.25))
	_read_t -= delta
	if _read_t <= 0.0:
		_read_t = 0.5
		_read()


## WATER LAB: the next page (E), past the last back to the summary.
func activate() -> void:
	var src: Node = get_node_or_null(source) if not source.is_empty() else null
	var n: int = (src.call("panel_pages") as Array).size() if src != null and src.has_method("panel_pages") else 0
	page_index = page_index + 1 if page_index + 1 < n else -1
	for g in _glows:
		(g as MeshInstance4D).material_override = Mats.glow(Style.UI_ACCENT if page_index >= 0 else Style.pick(Style.COVE), 2.6 if page_index >= 0 else 1.8)
	_read()


func set_near(on: bool) -> void:
	if on != near:
		near = on
		_read()


## The face's data from the exhibit: {"number", "title", "kicker", "rows": [[label, value], ...]}.
func _read() -> void:
	var src: Node = get_node_or_null(source) if not source.is_empty() else null
	if src != null:
		var pages: Array = src.call("panel_pages") if src.has_method("panel_pages") else []
		if page_index >= pages.size():
			page_index = -1
		if page_index >= 0:
			var pg: Dictionary = pages[page_index]
			_data = {"number": number, "title": String(pg.get("title", title)), "kicker": String(pg.get("kicker", "")),
				"rows": pg.get("rows", []), "text": String(pg.get("text", "")), "page": "%d / %d" % [page_index + 1, pages.size()]}
		else:
			_data = {"number": number, "title": title, "kicker": kicker, "rows": (src.call("face") as Array).slice(0, 3) if src.has_method("face") else [], "page": ""}
			# A selector (the showcase's creatures): tiles across the top, the chosen one's card under them.
			if src.has_method("tiles"):
				_data["tiles"] = src.call("tiles")
				if src.has_method("card"):
					var cd: Dictionary = src.call("card")
					_data["title"] = String(cd.get("title", title))
					_data["kicker"] = String(cd.get("kicker", kicker))
		_data["hint"] = near
		_data["hint_text"] = hint
		var s0: String = str(_data)
		if s0 != _sig:
			_sig = s0
			if _page != null:
				_page.queue_redraw()
				_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	var st: Node = get_node_or_null(station) if not station.is_empty() else null
	var ex: Node = st.get("exhibit") if st != null else null
	var found: Array = []
	if ex != null and ex.has_method("face"):
		found = ex.call("face")
	elif ex != null and ex.has_method("numbers"):
		var n: Dictionary = ex.call("numbers")
		for k in [["voxels", "Voxels"], ["chunks", "Chunk meshes"], ["tets", "Tetrahedra"]]:
			if n.has(k[0]):
				found.append([k[1], String(n[k[0]])])
	elif st == null:
		found = rows
	_data = {"number": number, "title": title, "kicker": kicker, "rows": found.slice(0, 3), "hint": near, "hint_text": hint}
	var s: String = str(_data)
	if s != _sig:
		_sig = s
		if _page != null:
			_page.queue_redraw()
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _paint() -> void:
	if _data.has("tiles") and String(_data.get("page", "")).is_empty():
		_paint_tiles()
		return
	var sz: Vector2 = _page.size
	var u: float = sz.y / 260.0
	_page.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.035, 0.042, 0.055))
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var pad: float = 26.0 * u
	var npx: int = int(64 * u)
	var tx: float = pad
	if int(_data.get("number", 1)) > 0:
		var num: String = "%02d" % int(_data.get("number", 1))
		_page.draw_string(fb, Vector2(pad, pad + npx * 0.8), num, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, Style.UI_ACCENT)
		var nx: float = pad + fb.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x + 18.0 * u
		_page.draw_line(Vector2(nx, pad + 6.0 * u), Vector2(nx, pad + npx * 0.9), Color(1, 1, 1, 0.35), maxf(1.0, 2.0 * u))
		tx = nx + 18.0 * u
	_page.draw_string(fb, Vector2(tx, pad + 34.0 * u), String(_data.get("title", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, sz.x - tx - pad, int(36 * u), Color.WHITE)
	_page.draw_string(fs, Vector2(tx, pad + 62.0 * u), String(_data.get("kicker", "")), HORIZONTAL_ALIGNMENT_LEFT, sz.x - tx - pad, int(17 * u), Style.UI_INK_DIM)
	# WATER LAB: the page's count and the hint, along the bottom.
	var foot_y: float = sz.y - pad * 0.7
	if not String(_data.get("page", "")).is_empty():
		_page.draw_string(fs, Vector2(pad, foot_y), String(_data["page"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * u), Style.UI_ACCENT)
	if bool(_data.get("hint", false)):
		var line: String = hint if not hint.is_empty() else ("E   NEXT PAGE" if int(page_index) >= 0 else "E   MORE ABOUT IT")
		_page.draw_string(fs, Vector2(pad, foot_y), line, HORIZONTAL_ALIGNMENT_RIGHT, sz.x - pad * 2.0, int(15 * u), Style.UI_ACCENT)
	var body: String = String(_data.get("text", ""))
	if not body.is_empty():
		var top0: float = pad + npx + 22.0 * u
		_page.draw_line(Vector2(pad, top0 - 10.0 * u), Vector2(sz.x - pad, top0 - 10.0 * u), Color(1, 1, 1, 0.15), maxf(1.0, u))
		_page.draw_multiline_string(fl, Vector2(pad, top0 + 18.0 * u), body, HORIZONTAL_ALIGNMENT_LEFT, sz.x - pad * 2.0, int(17 * u), 6, Color(1, 1, 1, 0.88))
		return
	var cols: Array = _data.get("rows", [])
	if cols.is_empty():
		return
	var top: float = pad + npx + 24.0 * u
	_page.draw_line(Vector2(pad, top - 10.0 * u), Vector2(sz.x - pad, top - 10.0 * u), Color(1, 1, 1, 0.15), maxf(1.0, u))
	var cw: float = (sz.x - pad * 2.0) / float(cols.size())
	for i in cols.size():
		var x: float = pad + cw * float(i)
		_page.draw_string(fb, Vector2(x, top + 40.0 * u), String(cols[i][1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 12.0 * u, int(34 * u), Color.WHITE)
		_page.draw_string(fl, Vector2(x, top + 68.0 * u), String(cols[i][0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, cw - 12.0 * u, int(15 * u), Style.UI_INK_DIM)


## WATER LAB: the selector (round 3, Ramon: "similar to the floating panel at the shooter range ... the
## icons that you can select of the different animals ... showcased in the middle when you click an
## icon with the arrow keys"): the Quantum Range console's tiles across the top (its look: the lit one
## blue-filled with a blue border, a key number in its corner, the glyph, the name under it), the
## chosen creature's card under them, the keys along the bottom.
func _paint_tiles() -> void:
	var sz: Vector2 = _page.size
	var u: float = sz.x / 1144.0
	_page.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.035, 0.042, 0.055))
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var pad: float = 30.0 * u
	var tiles: Array = _data["tiles"]
	var n: int = maxi(tiles.size(), 1)
	var gap: float = 16.0 * u
	var tw: float = (sz.x - pad * 2.0 - gap * float(n - 1)) / float(n)
	var th: float = sz.y * 0.46
	for i in tiles.size():
		var lit: bool = bool(tiles[i][2])
		var r := Rect2(Vector2(pad + float(i) * (tw + gap), pad), Vector2(tw, th))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Style.UI_ACCENT, 0.18) if lit else Color(1, 1, 1, 0.04)
		sb.border_color = Color(Style.UI_ACCENT, 0.95) if lit else Color(1, 1, 1, 0.28)
		sb.set_border_width_all(int(maxf(2.0, (4.0 if lit else 2.0) * u)))
		sb.set_corner_radius_all(int(18.0 * u))
		_page.draw_style_box(sb, r)
		var ink: Color = Style.UI_ACCENT if lit else Color(1, 1, 1, 0.82)
		_page.draw_string(fs, r.position + Vector2(16.0 * u, 34.0 * u), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * u), ink)
		var gr := Rect2(r.position + Vector2(r.size.x * 0.14, 30.0 * u), Vector2(r.size.x * 0.72, r.size.y - 82.0 * u))
		Glyphs.animal(_page, String(tiles[i][1]), gr, ink, sb.bg_color.lerp(Color(0.035, 0.042, 0.055), 0.5))
		_page.draw_string(fs, Vector2(r.position.x, r.end.y - 18.0 * u), String(tiles[i][0]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(20 * u), ink)
	# The chosen one's card.
	var y0: float = pad + th + 34.0 * u
	_page.draw_string(fb, Vector2(pad, y0 + 34.0 * u), String(_data.get("title", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, sz.x - pad * 2.0, int(40 * u), Color.WHITE)
	_page.draw_string(fs, Vector2(pad, y0 + 66.0 * u), String(_data.get("kicker", "")), HORIZONTAL_ALIGNMENT_LEFT, sz.x - pad * 2.0, int(18 * u), Style.UI_INK_DIM)
	var rows: Array = _data.get("rows", [])
	if not rows.is_empty():
		var top: float = y0 + 92.0 * u
		_page.draw_line(Vector2(pad, top), Vector2(sz.x - pad, top), Color(1, 1, 1, 0.15), maxf(1.0, u))
		var cw: float = (sz.x - pad * 2.0) / float(rows.size())
		for i in rows.size():
			var x: float = pad + cw * float(i)
			_page.draw_string(fb, Vector2(x, top + 46.0 * u), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 14.0 * u, int(34 * u), Color.WHITE)
			_page.draw_string(fl, Vector2(x, top + 74.0 * u), String(rows[i][0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, cw - 14.0 * u, int(16 * u), Style.UI_INK_DIM)
	var keys: String = "1 - %d  OR  LEFT / RIGHT   CHOOSE" % tiles.size()
	if bool(_data.get("hint", false)):
		keys += "        E   MORE ABOUT IT"
	_page.draw_string(fs, Vector2(pad, sz.y - pad * 0.8), keys, HORIZONTAL_ALIGNMENT_LEFT, sz.x - pad * 2.0, int(17 * u), Style.UI_ACCENT)
