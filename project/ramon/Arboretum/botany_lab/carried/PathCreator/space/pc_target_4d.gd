@tool
extends Node4D

## PathCreator: a coloured target in the dev space, something to draw a path to (Ramon, 5 Oct:
## "build a dev space with colored boxes you draw paths too"). A box or a cubinder standing on the
## floor at the node's own W (`position.w`), `w_depth` deep in W: the slice cuts it only while it is
## within half that of the target's W, so a target at W +4 shows only when you are near W +4 (the
## "house sized blue cube somewhere in the W").
##
## Its footprint (x, z) is what a destination's frame grows round; `label` names it on the
## builder's map. Box physics only (engine_capabilities.md), so a cubinder collides as its box,
## and only within its W depth, as 4D physics does.
##
## `pole` puts a thin pole of its colour, deep in W, beside it: a developer's aid that shows where
## it is from any W, off by default (the paths' brackets are meant to do that job).
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_materials.gd")
const LabGrid := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_grid.gd")
const GENERATED := "pc_generated"

@export var label: String = "Target":
	set(v):
		label = v
		_later()
@export_enum("box", "cubinder") var shape: String = "box":
	set(v):
		shape = v
		_later()
## x, height, z, metres.
@export var size: Vector3 = Vector3(2, 2, 2):
	set(v):
		size = v
		_later()
## How deep in W it is, metres: it shows within half of this either side of its W.
@export_range(0.1, 40.0, 0.1) var w_depth: float = 1.2:
	set(v):
		w_depth = v
		_later()
@export var color: Color = Color(0.85, 0.2, 0.2):
	set(v):
		color = v
		_later()
@export var collide: bool = true:
	set(v):
		collide = v
		_later()
@export var pole: bool = false:
	set(v):
		pole = v
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


## Its footprint on the floor, metres (x, z).
func footprint() -> Vector2:
	return Vector2(size.x, size.z)


func rebuild() -> void:
	for c in get_children():
		if c.has_meta(GENERATED):
			c.queue_free()
	var swatch: String = "pc_target_" + color.to_html(false)
	LabGrid.set_swatch(swatch, color, color.darkened(0.25), color.darkened(0.12), 1.0)
	var mi := MeshInstance4D.new()
	mi.name = "Body"
	var s4 := Vector4(size.x, size.y, size.z, w_depth)
	if shape == "cubinder":
		var c := CubinderShape4D.new()
		c.radius = minf(size.x, size.z) * 0.5
		c.height = size.y
		c.thickness = w_depth * 0.5
		mi.mesh = c.to_tetra_mesh({"segments": 48})
	else:
		mi.mesh = Mats.box_mesh(s4)
	mi.position = Vector4(0, size.y * 0.5, 0, 0)
	mi.material_override = LabGrid.material(swatch, s4, global_position + mi.position if is_inside_tree() else mi.position)
	mi.set_meta(GENERATED, true)
	add_child(mi)
	if collide:
		var body := StaticBody4D.new()
		body.name = "Body4D"
		body.position = mi.position
		var cs := CollisionShape4D.new()
		var bs := BoxShape4D.new()
		bs.size = s4
		cs.shape = bs
		body.add_child(cs)
		body.set_meta(GENERATED, true)
		add_child(body)
	if pole:
		var p := MeshInstance4D.new()
		p.name = "Pole"
		var ps := Vector4(0.12, size.y + 3.0, 0.12, 30.0)
		p.mesh = Mats.box_mesh(ps)
		p.position = Vector4(size.x * 0.5 + 0.4, ps.y * 0.5, size.z * 0.5 + 0.4, -position.w)
		p.material_override = LabGrid.material(swatch, ps, p.position)
		p.set_meta(GENERATED, true)
		add_child(p)
