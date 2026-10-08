extends Node4D

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
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/VoxelLab/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const Mats := preload("res://ramon/VoxelLab/carried/LabKit/lab_materials.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")

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
## The point it turns its face to (x, z), usually the exhibit's ring.
@export var face_point: Vector2 = Vector2.ZERO

@export_group("Spring")
## How close you can come (metres from its middle) before it is pushed, and how far it gives.
@export var reach: float = 0.95
@export var give: float = 0.45
@export var stiffness: float = 26.0
@export var damping: float = 4.2

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


func _ready() -> void:
	_home = position
	var d := Vector2(face_point.x - position.x, face_point.y - position.z)
	_yaw = atan2(d.x, d.y) if d.length() > 0.01 else 0.0
	_build()
	_read()


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
		var line := MeshInstance4D.new()
		line.name = "Underglow"
		line.mesh = Mats.box_mesh(Vector4(sz.x, sz.y, sz.z, Build.W_DEPTH))
		line.position = Vector4(at.x, at.y, at.z, 0.0)
		line.material_override = Mats.glow(Style.pick(Style.COVE), 1.8)
		_slab.add_child(line)
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
	if player != null and is_instance_valid(player):
		var p: Vector4 = player.global_position
		var away := Vector2(_home.x + _off.x - p.x, _home.z + _off.y - p.z)
		var d: float = away.length()
		if d < reach and d > 0.001:
			target = away / d * minf(give, (reach - d) * 1.6) + _off
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


## The face's data from the exhibit: {"number", "title", "kicker", "rows": [[label, value], ...]}.
func _read() -> void:
	var st: Node = get_node_or_null(station) if not station.is_empty() else null
	var ex: Node = st.get("exhibit") if st != null else null
	var rows: Array = []
	if ex != null and ex.has_method("face"):
		rows = ex.call("face")
	elif ex != null and ex.has_method("numbers"):
		var n: Dictionary = ex.call("numbers")
		for k in [["voxels", "Voxels"], ["chunks", "Chunk meshes"], ["tets", "Tetrahedra"]]:
			if n.has(k[0]):
				rows.append([k[1], String(n[k[0]])])
	_data = {"number": number, "title": title, "kicker": kicker, "rows": rows.slice(0, 3)}
	var s: String = str(_data)
	if s != _sig:
		_sig = s
		if _page != null:
			_page.queue_redraw()
			_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _paint() -> void:
	var sz: Vector2 = _page.size
	var u: float = sz.y / 260.0
	_page.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.035, 0.042, 0.055))
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var pad: float = 26.0 * u
	var num: String = "%02d" % int(_data.get("number", 1))
	var npx: int = int(64 * u)
	_page.draw_string(fb, Vector2(pad, pad + npx * 0.8), num, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, Style.UI_ACCENT)
	var nx: float = pad + fb.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x + 18.0 * u
	_page.draw_line(Vector2(nx, pad + 6.0 * u), Vector2(nx, pad + npx * 0.9), Color(1, 1, 1, 0.35), maxf(1.0, 2.0 * u))
	var tx: float = nx + 18.0 * u
	_page.draw_string(fb, Vector2(tx, pad + 34.0 * u), String(_data.get("title", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, sz.x - tx - pad, int(36 * u), Color.WHITE)
	_page.draw_string(fs, Vector2(tx, pad + 62.0 * u), String(_data.get("kicker", "")), HORIZONTAL_ALIGNMENT_LEFT, sz.x - tx - pad, int(17 * u), Style.UI_INK_DIM)
	var rows: Array = _data.get("rows", [])
	if rows.is_empty():
		return
	var top: float = pad + npx + 24.0 * u
	_page.draw_line(Vector2(pad, top - 10.0 * u), Vector2(sz.x - pad, top - 10.0 * u), Color(1, 1, 1, 0.15), maxf(1.0, u))
	var cw: float = (sz.x - pad * 2.0) / float(rows.size())
	for i in rows.size():
		var x: float = pad + cw * float(i)
		_page.draw_string(fb, Vector2(x, top + 40.0 * u), String(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, cw - 12.0 * u, int(34 * u), Color.WHITE)
		_page.draw_string(fl, Vector2(x, top + 68.0 * u), String(rows[i][0]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, cw - 12.0 * u, int(15 * u), Style.UI_INK_DIM)
