extends RefCounted

## The range's materials for things that move and change: a lit colour (the engine's own cross-section
## shader, which takes the 4D lights) and a glow (the carried kit's unshaded shader) that the caller owns
## and can recolour every frame, unlike the kit's cached ones (carried/LabKit/lab_materials.gd keeps one
## material per colour, shared by everything that asked for that colour).
##
## NO class_name (engine_gotchas.md): preload it.

const GlowShader := preload("res://ramon/PhaseMazeRemake/carried/LabKit/shaders/lab_glow.gdshader")


## A lit colour of its own.
static func lit(color: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = color
	return m


## An unshaded glow of its own; recolour it with set_glow().
static func glow(color: Color, energy: float = 1.0) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	# The shader before anything else: Material4D only fills an empty slot with its own.
	cs.shader = GlowShader
	m.albedo_color = Color.WHITE
	cs.set_shader_parameter("glow_color", color)
	cs.set_shader_parameter("glow_energy", energy)
	return m


static func set_glow(m: TetraMaterial4D, color: Color, energy: float = 1.0) -> void:
	var cs: ShaderMaterial = m.get_cross_section_material_3d()
	cs.set_shader_parameter("glow_color", color)
	cs.set_shader_parameter("glow_energy", energy)


static func box(size: Vector4) -> BoxTetraMesh4D:
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	return mesh
