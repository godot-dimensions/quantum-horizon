@tool
extends Node4D

## A place the W Exploder leaves clear (w_exploder_4d.gd, group "w_exclude"): a ball, or with `box` set a box,
## in x, z and W (height is ignored), where this node stands. For a clearing the hand-placed wood has but its
## W copies would fill, or a spot ana or kata that must stay open (a door in W, a view).

## Ball radius, or with box set, the box's half sizes in x, z and W.
@export_range(0.1, 100.0, 0.1, "suffix:m") var radius: float = 5.0
@export var box: bool = false
@export var half: Vector3 = Vector3(5.0, 5.0, 5.0)


func _enter_tree() -> void:
	add_to_group(&"w_exclude")


## In the editor, a wire of the shape so it can be seen and placed (never saved, never drawn in play).
func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	var shape: Shape4D
	if box:
		var b := BoxShape4D.new()
		b.size = Vector4(half.x * 2.0, 1.0, half.y * 2.0, half.z * 2.0)
		shape = b
	else:
		var s := SphereShape4D.new()
		s.radius = radius
		shape = s
	var wire := MeshInstance4D.new()
	wire.name = "Wire"
	wire.mesh = shape.to_wire_mesh()
	add_child(wire)


func excludes(point: Vector4) -> bool:
	var d: Vector4 = global_basis.inverse() * (point - global_position)
	if box:
		return absf(d.x) <= half.x and absf(d.z) <= half.y and absf(d.w) <= half.z
	return Vector3(d.x, d.z, d.w).length() <= radius
