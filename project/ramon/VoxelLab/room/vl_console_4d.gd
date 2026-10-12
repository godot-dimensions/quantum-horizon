@tool
extends Node4D

## The Voxel Lab (adapted from the Arboretum's room/tree_console_4d.gd, 6 Oct): the console beside a
## pedestal. A dark stand and a black glass screen tilted up to
## you (the kit's rule: screens are black glass with white type), printed with the pedestal's number,
## its method and the key that opens its card. Walk up and a key prompt pops over it (the room's
## carried kit_prompt.gd); E or a click opens the specimen's card (vl_card.gd).
##
## Faces its own +Z. Off the route and beside the specimen, never in front of it.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/VoxelLab/carried/scripts/chamber_build.gd")
const RD := preload("res://ramon/VoxelLab/carried/scripts/rd_build.gd")
const LabGrid := preload("res://ramon/VoxelLab/carried/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## The pedestal (a carried showcase) whose specimen's card this opens.
@export var station: NodePath
## The pedestal's number, its method and its line.
@export var number: int = 1:
	set(v):
		number = v
		_later()
@export var title: String = "Voxels":
	set(v):
		title = v
		_later()
@export var code: String = "VX-01":
	set(v):
		code = v
		_later()
@export var kicker: String = "THE SHRUBBERY LAB'S TREE":
	set(v):
		kicker = v
		_later()
## The screen's size (m), how high its middle stands and how far it leans back (degrees).
@export var screen_size: Vector2 = Vector2(1.5, 0.84):
	set(v):
		screen_size = v
		_later()
@export var screen_height: float = 1.15:
	set(v):
		screen_height = v
		_later()
@export_range(0.0, 80.0, 1.0) var tilt: float = 38.0:
	set(v):
		tilt = v
		_later()
## How near (m, on the floor) counts as standing at it.
@export var reach: float = 2.4
## What its key line says.
@export var key_text: String = "ABOUT THIS SPECIMEN":
	set(v):
		key_text = v
		_later()
## Which way it faces: its +Z turned this many degrees toward +X.
@export_range(-180.0, 180.0, 1.0) var facing: float = 0.0:
	set(v):
		facing = v
		if is_inside_tree():
			basis = Basis4D.from_zx(deg_to_rad(facing))
## Off: a sign only (the tour's), not a console that opens a card.
@export var card_console: bool = true

var _screen: MeshInstance4D
var _rec: Dictionary = {}
var _queued: bool = false


func _enter_tree() -> void:
	if card_console:
		add_to_group("vl_console")
	add_to_group("lab_mood_listener")
	basis = Basis4D.from_zx(deg_to_rad(facing))


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_inside_tree() or _queued:
		return
	_queued = true
	(func() -> void:
		_queued = false
		rebuild()).call_deferred()


func rebuild() -> void:
	Build.clear(self)
	var t: float = deg_to_rad(tilt)
	var top: float = screen_height - sin(t) * screen_size.y * 0.5
	var stand_h: float = maxf(top - 0.05, 0.2)
	Build.box(self, "Stand", Vector3(0, stand_h * 0.5, -0.05), Vector3(0.36, stand_h, 0.28), "kit_metal", true)
	_screen = Build.box(self, "Screen", Vector3(0, screen_height, 0), Vector3(screen_size.x, screen_size.y, 0.05), "kit_glass", false)
	# Lean back: the top away from you (+Z faces you).
	_screen.basis = Basis4D.from_yz(t)
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_rec = await RD.print_box(tree, _screen, Vector4(0, 0, 1, 0), screen_size, _paint, {"bright": 0.95, "dark": 0.95}, 420.0)
	apply_mood(Style.mood)


func apply_mood(m: String, _instant: bool = false) -> void:
	if not _rec.is_empty():
		RD.apply(_rec, m if m in ["bright", "dark"] else "bright")


func _paint(c: Control, _ink: Dictionary) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var white := Color(1, 1, 1)
	var dim := Color(0.80, 0.86, 0.96, 0.75)
	var accent: Color = Style.UI_ACCENT
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	# The white frame round the screen (the kit's screens all have one).
	var lw: float = maxf(2.0, h * 0.012)
	c.draw_rect(Rect2(Vector2(lw, lw), Vector2(w - lw * 2.0, h - lw * 2.0)), Color(1, 1, 1, 0.85), false, lw)
	var pad: float = h * 0.1
	c.draw_string(fs, Vector2(pad, pad + h * 0.08), "%s   ·   %s" % [code, kicker], HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, int(h * 0.06), accent)
	var nx: float = pad - h * 0.08
	if number > 0:
		c.draw_string(fb, Vector2(pad, pad + h * 0.38), "%02d" % number, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.3), white)
		nx = pad + fb.get_string_size("%02d" % number, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.3)).x + h * 0.08
		c.draw_line(Vector2(nx, pad + h * 0.14), Vector2(nx, pad + h * 0.4), dim, lw)
	c.draw_string(fb, Vector2(nx + h * 0.08, pad + h * 0.36), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - nx - pad, int(h * 0.15), white)
	# The key.
	var ky: float = h - pad - h * 0.14
	var cap := Rect2(Vector2(pad, ky), Vector2(h * 0.14, h * 0.14))
	c.draw_rect(cap, Color(1, 1, 1, 0.12))
	c.draw_rect(cap, white, false, lw)
	c.draw_string(fs, Vector2(cap.position.x, cap.position.y + h * 0.105), "E", HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, int(h * 0.09), white)
	c.draw_string(fs, Vector2(cap.end.x + h * 0.06, ky + h * 0.1), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.075), white)
	if card_console:
		c.draw_string(fl, Vector2(w - pad, ky + h * 0.1), "METHOD  ·  LIMITS  ·  MEASURED", HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5, int(h * 0.05), dim)


## Whether `p` (world) is standing at this console.
func near(p: Vector4) -> bool:
	var g: Vector4 = global_position
	var front: Vector4 = global_basis * Vector4(0, 0, 1.0, 0)
	return Vector2(p.x - (g.x + front.x), p.z - (g.z + front.z)).length() < reach
