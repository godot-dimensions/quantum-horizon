@tool
extends Node4D

## PathCreator: a label painted flat on the dev space's floor, readable from any W (a plate the floor's
## whole W depth). For naming the W stations and the yard; a developer's note, not wayfinding (the
## sheet: "map annotations are design notes, not required floor labels").
##
## NO class_name (engine_gotchas.md).

const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const GENERATED := "pc_generated"
const PPM := 120.0

@export var text: String = "LABEL":
	set(v):
		text = v
		_later()
@export var note: String = "":
	set(v):
		note = v
		_later()
## The plate, metres (x along the text, z its height on the floor).
@export var size: Vector2 = Vector2(4.0, 1.0):
	set(v):
		size = v
		_later()

var _queued: bool = false


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
	for c in get_children():
		if c.has_meta(GENERATED):
			c.queue_free()
	var floor := Color(0.96, 0.965, 0.97)
	LabGrid.set_swatch("pc_label", floor, floor, floor, 0.0)
	var s4 := Vector4(size.x, 0.01, size.y, Spec.W_REACH * 2.0)
	var mi := MeshInstance4D.new()
	mi.name = "Plate"
	mi.mesh = Mats.box_mesh(s4)
	mi.position = Vector4(0, 0.006, 0, -position.w)
	mi.material_override = LabGrid.material("pc_label", s4, mi.position)
	mi.set_meta(GENERATED, true)
	add_child(mi)
	if not is_inside_tree():
		return
	var px := Vector2i(int(size.x * PPM), int(size.y * PPM))
	var ink := Color("#10233d")
	var dim := Color("#668bae")
	var t: String = text
	var n: String = note
	var tex: Texture2D = await LabPrint.render(get_tree(), px, func(c: Control) -> void:
		var f: Font = LabPrint.font("bold")
		var fs: int = int(px.y * (0.42 if n.is_empty() else 0.34))
		c.draw_string(f, Vector2(px.y * 0.15, px.y * (0.62 if n.is_empty() else 0.46)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		if not n.is_empty():
			c.draw_string(LabPrint.font("body"), Vector2(px.y * 0.15, px.y * 0.82), n, HORIZONTAL_ALIGNMENT_LEFT, -1, int(px.y * 0.2), dim))
	if not is_instance_valid(mi):
		return
	# Printed on the plate's top face, read from the south (+z) as the player arrives.
	LabGrid.set_print(mi.material_override as TetraMaterial4D, tex, Vector4(0, 1, 0, 0), Rect2(Vector2.ZERO, size), Color.WHITE, 0.0)
	LabGrid.set_print_strength(mi.material_override as TetraMaterial4D, 1.0)
