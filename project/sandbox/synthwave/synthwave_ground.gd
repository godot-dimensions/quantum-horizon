extends MeshInstance4D
## Synthwave grid ground - see synthwave_sky.gd's own comment on why this
## can't just be a plain ShaderMaterial sub-resource in the .tscn: a
## MeshInstance4D's material_override is typed Material4D, so building it
## needs a TetraMaterial4D wrapper whose internal cross_section_material's
## shader gets swapped for the custom one, done here in code.

const GridShader := preload("res://sandbox/synthwave/synthwave_grid.gdshader")

@export var line_color: Color = Color(1.0, 0.15, 0.85, 1.0)
@export var fill_color: Color = Color(0.05, 0.02, 0.12, 1.0)
@export var cell_size: float = 4.0
@export var line_thickness: float = 0.06 # World-space half-width, not pixels - see the shader's own comment.
@export var glow_distance: float = 60.0


func _ready() -> void:
	var ground_material := TetraMaterial4D.new()
	var shader_material: ShaderMaterial = ground_material.get_cross_section_material_3d()
	shader_material.shader = GridShader
	shader_material.set_shader_parameter("line_color", line_color)
	shader_material.set_shader_parameter("fill_color", fill_color)
	shader_material.set_shader_parameter("cell_size", cell_size)
	shader_material.set_shader_parameter("line_thickness", line_thickness)
	shader_material.set_shader_parameter("glow_distance", glow_distance)
	material_override = ground_material
