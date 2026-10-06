@tool
extends MeshInstance4D

## A rock you can move by hand (Ramon, 6 Oct: "open it for me in the editor, i want to move around
## chunks", then "i want to be able to move all the stones, not just the huge ones"): the Watchstone's
## big chunks and, once baked, every stone of its crag. One designed-cut stone (terrain/cut_stone_4d.gd), stretched to [member size] and
## standing on this node's origin: its foot [member bury] metres under the ground there, so the rounded
## underside is out of sight, and its top [member size].y above it.
##
## MOVE IT, TURN IT, RESIZE IT. The node's position and rotation place it; [member size] stretches it.
## A crag it stands against (pen_crag_4d.gd, through the Watchstone) clears its own face stones where a
## chunk stands, so the chunk is one mass through the courses; the Watchstone rebuilds the crag a moment
## after you let go (watchstone_4d.gd, _process in the editor).
##
## THE NODE IS THE MESH. The 4D editor makes every mesh node you click selectable, children included
## (editor_main_viewport_4d.cpp, _gather_non_empty_visible_mesh_4d_nodes): when the rock was a generated
## child mesh, a click picked that child, a move moved only it and was never saved, and it could not be
## deleted (Ramon, 6 Oct: "a lot of rocks are floating on the left side, i couldnt delete them"). So the
## stone node draws itself: its mesh is a copy of the baked stone, stretched and lifted, built when it
## loads and never saved into the scene (_validate_property).
##
## NO class_name (engine_gotchas.md).

const StoneSet := preload("res://ramon/chickenpen/scripts/pen_stone_set_4d.gd")
const CutStone := preload("res://ramon/chickenpen/terrain/cut_stone_4d.gd")
const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const OWN := &"_chunk_part"

@export_enum("block", "round", "slab", "wedge", "cap", "ledge", "chip", "pillar") var kind: String = "block": set = _set_kind
@export_range(0, 3) var variant: int = 0: set = _set_variant
## A mossy top (grey sides turning green over the top), or plain grey.
@export var moss: bool = true: set = _set_moss
## Width (along this node's x), height above the ground, depth (along z), in metres.
@export var size: Vector3 = Vector3(6.0, 9.6, 4.4): set = _set_size
## How deep it is in W.
@export_range(0.5, 8.0, 0.1, "suffix:m") var w_size: float = 3.6: set = _set_w
## How far its foot runs under the ground.
@export_range(0.0, 4.0, 0.1, "suffix:m") var bury: float = 1.6: set = _set_bury
@export var solid: bool = true


func _set_kind(v: String) -> void: kind = v; _later()
func _set_variant(v: int) -> void: variant = v; _later()
func _set_moss(v: bool) -> void: moss = v; _later()
func _set_size(v: Vector3) -> void: size = v; _later()
func _set_w(v: float) -> void: w_size = v; _later()
func _set_bury(v: float) -> void: bury = v; _later()


var _pending: bool = false


func _ready() -> void:
	add_to_group(&"crag_chunk")
	rebuild()


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


## Neither the mesh nor the material is saved: both are built from the exports when the stone loads.
func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh" or property.name == "material_override":
		property.usage = PROPERTY_USAGE_NONE


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	var source: ArrayTetraMesh4D = StoneSet.stone_mesh(kind + ("_moss" if moss else ""), variant)
	if source == null:
		mesh = null
		return
	var half: Vector4 = (CutStone.KINDS[kind][0] as Vector4)
	var total: float = size.y + bury
	var own := ArrayTetraMesh4D.new()
	own.merge_with(source, Vector4(0, (size.y - bury) * 0.5, 0, 0), Projection(Vector4(size.x / (2.0 * half.x), 0, 0, 0),
		Vector4(0, total / (2.0 * half.y), 0, 0), Vector4(0, 0, size.z / (2.0 * half.z), 0), Vector4(0, 0, 0, w_size / (2.0 * half.w))))
	mesh = own
	material_override = TerrainBake.material()
	if solid and not Engine.is_editor_hint():
		var body := StaticBody4D.new()
		body.name = "Solid"
		body.set_meta(OWN, true)
		var holder := CollisionShape4D.new()
		var shape := BoxShape4D.new()
		shape.size = Vector4(size.x * 0.8, size.y, size.z * 0.8, w_size)
		holder.shape = shape
		holder.position = Vector4(0, size.y * 0.5, 0, 0)
		body.add_child(holder)
		add_child(body)


## For the crag: where it stands, its height and width, in [param frame]'s coordinates.
func footprint(frame: Node4D) -> Dictionary:
	var local: Vector4 = frame.global_basis.inverse() * (global_position - frame.global_position)
	return {"x": local.x, "z": local.z, "height": size.y, "width": size.x}


## A number that changes when the chunk is moved, turned or resized (the Watchstone watches it).
func signature() -> float:
	var b: Projection = global_basis
	return global_position.x * 1.1 + global_position.y * 1.3 + global_position.z * 1.7 + global_position.w * 1.9 \
		+ b.x.x * 2.3 + b.x.z * 2.9 + b.z.x * 3.1 + b.y.x * 3.7 + b.y.z * 4.1 + size.x * 5.3 + size.y * 5.9 + size.z * 6.1
