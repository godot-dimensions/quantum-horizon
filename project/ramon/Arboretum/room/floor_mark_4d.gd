@tool
extends Node4D

## The Arboretum: a pedestal's number painted on the floor in front of it ("01  VOXELS"), in the wall
## blue, read from where you stand to look at the tree (the Unreal intro level numbers its stations
## the same way; the case study's rule 8: number every station). A thin plate a hair above the floor
## on the floor's own grid, so only the paint shows. Its +Z is toward the reader.
##
## NO class_name (engine_gotchas.md).

const Build := preload("res://ramon/Arboretum/carried/scripts/chamber_build.gd")
const RD := preload("res://ramon/Arboretum/carried/scripts/rd_build.gd")
const LabPrint := preload("res://ramon/Arboretum/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")

@export var number: int = 1:
	set(v):
		number = v
		_later()
@export var title: String = "VOXELS":
	set(v):
		title = v
		_later()
## The plate's size on the floor (m): across, and toward the reader.
@export var size: Vector2 = Vector2(3.2, 1.1):
	set(v):
		size = v
		_later()
## Which way it reads: its +Z (the reader's side) turned this many degrees toward +X.
@export_range(-180.0, 180.0, 1.0) var facing: float = 0.0:
	set(v):
		facing = v
		_later()

var _plate: MeshInstance4D
var _rec: Dictionary = {}
var _queued: bool = false


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


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
	_plate = Build.box(self, "Plate", Vector3(0, 0.006, 0), Vector3(size.x, 0.012, size.y), "kit_floor", false)
	_plate.basis = Basis4D.from_zx(deg_to_rad(facing))
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_rec = await RD.print_box(tree, _plate, Vector4(0, 1, 0, 0), size, _paint, {"bright": 0.2, "dark": 0.35}, 220.0)
	apply_mood(Style.mood)


func apply_mood(m: String, _instant: bool = false) -> void:
	if not _rec.is_empty():
		RD.apply(_rec, m if m in ["bright", "dark"] else "bright")


func _paint(c: Control, _ink: Dictionary) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	var blue: Color = Style.pick(Style.CODE_BLUE)
	var fb: Font = LabPrint.font("black")
	var num: String = "%02d" % number
	var px: int = int(h * 0.82)
	c.draw_string(fb, Vector2(h * 0.08, h * 0.83), num, HORIZONTAL_ALIGNMENT_LEFT, -1, px, blue)
	var nx: float = h * 0.08 + fb.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + h * 0.14
	c.draw_rect(Rect2(Vector2(nx, h * 0.18), Vector2(maxf(2.0, h * 0.05), h * 0.64)), blue)
	# The title shrinks to fit the plate rather than being cut off ("02 | SMOOTH V").
	var room_w: float = w - nx - h * 0.34
	var tpx: int = int(h * 0.42)
	var tw: float = fb.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx).x
	if tw > room_w:
		tpx = maxi(8, int(float(tpx) * room_w / tw))
	c.draw_string(fb, Vector2(nx + h * 0.2, h * 0.5 + float(tpx) * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tpx, blue)
