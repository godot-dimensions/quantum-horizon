@tool
extends Node4D

## The specimen picker on the Voxel Lab's floating panel (Creature Lab v2, 9 Oct 2026; Ramon's walkthrough
## item 2: "update the specimen toggle to the newer wobbly floating-panel design, keeping the logic").
##
## THE LOGIC is kit/kit_exhibit_picker_4d.gd's, unchanged: six slots, each an exhibit script, a name and an
## icon; the room calls choose() for keys 1 to 6; the slot lit is whichever animal the showcase has on its
## plinth, so it can never disagree with what you see. Its face is the same drawing.
##
## THE BODY is the Voxel Lab's floating panel's (VoxelLab/room/vl_float_panel_4d.gd, built again here from
## the lab's own kit, nothing there touched): a light rounded plate with black glass on its face and a glow
## line under it, tilted up towards you, floating with no stand, on a spring: it bobs on its own, and walk
## into it and it is pushed away, swings back and tilts as it goes.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const Glyphs := preload("res://ramon/CreationLab/kit/kit_glyphs.gd")

const SLOTS := 6
const PPM := 520.0
const MARGIN := 0.07
const SLAB := 0.06
const CORNER := 0.07

## The showcase whose plinth it chooses for.
@export var showcase: NodePath
@export var slot_scripts: PackedStringArray = ["res://ramon/CreationLab/scripts/rd_goat_4d.gd", "res://ramon/CreationLab/scripts/rd_chicken_4d.gd",
	"res://ramon/CreationLab/scripts/rd_wolf_4d.gd"]
@export var slot_names: PackedStringArray = ["GOAT", "CHICKEN", "WOLF"]
@export var slot_icons: PackedStringArray = ["goat", "chicken", "wolf"]

@export_group("Panel")
## The glass, metres (width, depth up the slope).
@export var width: float = 2.1
@export var depth: float = 0.56
## Tilted up towards you (degrees from the floor), its front edge this high.
@export var tilt: float = 40.0
@export var hover: float = 0.35
## The point it turns its face to (x, z, in its parent's frame).
@export var face_point: Vector2 = Vector2(0.0, 10.0)

@export_group("Spring")
## How close you can come (metres from its middle) before it is pushed, and how far it gives.
@export var reach: float = 1.35
@export var give: float = 0.45
@export var stiffness: float = 26.0
@export var damping: float = 4.2

## Who bumps into it.
var player: Node4D

var _body: Node4D
var _vp: SubViewport
var _page: Control
var _screen: MeshInstance4D
var _home: Vector4
var _yaw: float = 0.0
var _off := Vector2.ZERO
var _vel := Vector2.ZERO
var _t: float = 0.0
var _draw_t: float = 0.0
var _lit_at: float = -10.0
var _last_active: int = -2


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func _ready() -> void:
	_home = position
	var d := Vector2(face_point.x - position.x, face_point.y - position.z)
	_yaw = atan2(d.x, d.y) if d.length() > 0.01 else 0.0
	basis = Basis4D.from_zx(_yaw)
	_build()


## The palette changed (B): the plate again in the new one.
func apply_mood(_m: String, _instant: bool = false) -> void:
	if is_node_ready():
		_build()


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


func _build() -> void:
	for n in [_body, _vp]:
		if n != null and is_instance_valid(n):
			remove_child(n)
			n.queue_free()
	var th: float = deg_to_rad(tilt)
	var w: float = width + MARGIN * 2.0
	var dd: float = depth + MARGIN * 2.0
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	var slab := Node4D.new()
	slab.name = "Slab"
	slab.position = Vector4(0.0, hover + dd * 0.5 * sin(th) + SLAB * 0.5 * cos(th), 0.0, 0.0)
	slab.basis = Basis4D.from_yz(th)
	_body.add_child(slab)
	_rounded(slab, "Plate", Vector2(w, dd), SLAB, 0.0, CORNER, "kit_bezel")
	_screen = MeshInstance4D.new()
	_screen.name = "Screen"
	var sc := Vector4(width, 0.02, depth, Build.W_DEPTH)
	_screen.mesh = Mats.box_mesh(sc)
	_screen.position = Vector4(0.0, SLAB * 0.5 + 0.012, 0.0, 0.0)
	_screen.material_override = LabGrid.material("kit_glass", sc, Vector4.ZERO)
	slab.add_child(_screen)
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
		slab.add_child(line)
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
	_page.draw.connect(_draw_screen)
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
	_t += delta
	# The face: redrawn when the lit slot changes, and ten times a second while it flares and breathes.
	_draw_t -= delta
	var on: int = active()
	if (on != _last_active or _draw_t <= 0.0) and _page != null:
		_draw_t = 0.1
		_page.queue_redraw()
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if Engine.is_editor_hint():
		return
	# The spring: pushed away from you while you are within reach, always pulled home.
	var target := Vector2.ZERO
	if player != null and is_instance_valid(player):
		var p: Vector4 = player.global_position
		var parent := get_parent() as Node4D
		if parent != null:
			p -= parent.global_position
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


## The picker's face (kit_exhibit_picker_4d.gd's, on the black glass): SPECIMENS, the keys, and a slot per
## animal, the one on the plinth lit in blue.
func _draw_screen() -> void:
	var c: Control = _page
	var w: float = c.size.x
	var h: float = c.size.y
	var u: float = h / 276.0
	var on := active()
	if on != _last_active:
		_last_active = on
		_lit_at = _t
	var blue: Color = Style.UI_ACCENT
	var grey: Color = Style.UI_GREY
	var faint := Color(Style.UI_GREY, 0.28)
	var bg := Color(0.035, 0.042, 0.055)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	c.draw_rect(Rect2(Vector2.ZERO, c.size), bg)
	var mg: float = 22.0 * u
	c.draw_string(fb, Vector2(mg, 40.0 * u), "SPECIMENS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(24.0 * u), grey)
	var hint: String = "PRESS 1 TO %d" % SLOTS
	var hint_w: float = fs.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18.0 * u)).x
	c.draw_string(fs, Vector2(w - mg - hint_w, 39.0 * u), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18.0 * u), Color(grey, 0.6))
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
			var flare: float = clampf(1.0 - (_t - _lit_at) / 0.6, 0.0, 1.0)
			box.bg_color = Color(blue, 0.14 + 0.16 * flare)
			box.border_color = Color(blue, 0.85 + 0.15 * sin(_t * 3.0))
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
		c.draw_string(fs, r.position + Vector2(12.0 * u, 26.0 * u), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(19.0 * u), ink)
		if not filled:
			c.draw_string(fl, Vector2(r.position.x, r.end.y - 18.0 * u), "EMPTY", HORIZONTAL_ALIGNMENT_CENTER, sw, int(14.0 * u), faint)
			continue
		var icon_r := Rect2(r.position + Vector2(sw * 0.14, 22.0 * u), Vector2(sw * 0.72, sh - 62.0 * u))
		Glyphs.animal(c, slot_icons[i] if i < slot_icons.size() else "", icon_r, ink, Color(bg.lerp(ink, 0.12) if lit else bg))
		var nm: String = slot_names[i] if i < slot_names.size() else ""
		c.draw_string(fs, Vector2(r.position.x, r.end.y - 16.0 * u), nm, HORIZONTAL_ALIGNMENT_CENTER, sw, int(16.0 * u), ink)
