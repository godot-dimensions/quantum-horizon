@tool
extends StaticBody4D
## An editable ocean plane: a flat colored box providing water visuals and
## sea-level collision. The terrain itself has its own real collision now
## (see dual_contour_terrain_4d.gd's HeightMapShape4D), which only covers
## the terrain's own grid extent - this box is sized well beyond that, so
## there's still solid ground/water anywhere outside the terrain's grid
## bounds. Unlike the old runtime-only floor script this replaces, this is a
## first-class scene node: @tool so it's visible in the editor, and its
## position/rotation are just this node's own ordinary Node4D Transform -
## move or drag it in the viewport like anything else, no special handling
## needed for that part.

@export var size: Vector4 = Vector4(200, 1, 200, 200):
	set(value):
		size = value
		_rebuild()
@export var ocean_color: Color = Color(0.1, 0.35, 0.6):
	set(value):
		ocean_color = value
		_rebuild()

var _collision_shape: CollisionShape4D
var _mesh_instance: MeshInstance4D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return # Exported setters can fire while the scene is still loading.

	if _collision_shape == null:
		_collision_shape = CollisionShape4D.new()
		add_child(_collision_shape)
	var shape := BoxShape4D.new()
	shape.size = size
	_collision_shape.shape = shape

	if _mesh_instance == null:
		_mesh_instance = MeshInstance4D.new()
		add_child(_mesh_instance)
	var box := BoxTetraMesh4D.new()
	box.size = size
	_mesh_instance.mesh = box

	if not (_mesh_instance.material_override is TetraMaterial4D):
		_mesh_instance.material_override = TetraMaterial4D.new()
	var material: TetraMaterial4D = _mesh_instance.material_override
	material.albedo_color = ocean_color
