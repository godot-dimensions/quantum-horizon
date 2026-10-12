class_name SimplexGridLayer
extends Node4D
## Builds a regular grid_size x grid_size array of SimplexTetraMesh4D
## instances (each a regular 4-simplex / 5-cell, 5 tetrahedra) in the x/z
## plane, all at a fixed height and w=0, all sharing ONE TetraMaterial4D
## instance - so the whole grid costs one material's worth of GPU state, not
## grid_size^2 separate ones. Built for comparing per-object Cross-Section
## cost against other primitives (Box: 40-48 tets, Orthoplex: 16 tets) at a
## known, fixed instance count.

@export var grid_size: int = 8
@export var spacing: float = 4.0
@export var simplex_edge_length: float = 1.5
@export var height: float = 0.5
@export var simplex_color: Color = Color(0.9, 0.35, 0.2)

const SimplexTetraMesh4D = preload("res://scripts/simplex_tetra_mesh_4d.gd")

var instance_count: int = 0


func _ready() -> void:
	var shared_mesh: ArrayTetraMesh4D = SimplexTetraMesh4D.build(simplex_edge_length)
	var shared_material := TetraMaterial4D.new()
	shared_material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	shared_material.albedo_color = simplex_color

	var half: float = (float(grid_size) - 1.0) * spacing * 0.5
	for row in range(grid_size):
		for col in range(grid_size):
			var instance := MeshInstance4D.new()
			instance.mesh = shared_mesh
			instance.material_override = shared_material
			instance.position = Vector4(
				float(col) * spacing - half,
				height,
				float(row) * spacing - half,
				0.0
			)
			add_child(instance)
			instance_count += 1
