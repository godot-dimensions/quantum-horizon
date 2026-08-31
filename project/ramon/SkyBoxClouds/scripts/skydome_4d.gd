@tool
extends MeshInstance4D

# Deliberately no `class_name`. Windows resolves res:// paths case-insensitively
# but Godot does not, so a stale editor tab remembering an old spelling of this
# folder made Godot load this same file twice under two path strings - and the
# second copy's class_name collided with the first, failing the parse with
# "hides a global script class". Nothing here needs to be globally named; the
# scene references the script by path and _verify.gd loads it explicitly.

## A 4D skydome: a tetrahedral 3-sphere shell, coloured by a vertical gradient.
##
## Why geometry rather than a [WorldEnvironment] + [Sky]: the editor's "4D" tab
## renders through [CrossSectionRenderingEngine4D]'s own private [World3D]
## (see its [code]setup_for_viewport()[/code], which calls
## [code]viewport->set_world_3d()[/code] with a world the scene tree never
## touches). Nothing that lives on the scene's environment reaches that world,
## which is why the Isoclynic Sun's sky only appears in Play. 4D meshes, by
## contrast, are built directly into that private world, so they show in the
## editor unconditionally. Making the sky out of geometry is therefore the only
## way to preview it live without an engine change.
##
## The shell is the 600-cell: 600 tetrahedra whose boundary already forms a
## 3-sphere, with every vertex equidistant from the centre, so scaling it to
## [member radius] gives a round dome for free. A 4D shell cross-sections to a
## closed 3D surface at every w, so it is a sky from any slice, with no
## per-slice work.

## The roundest cheap regular 4-polytope in the project. Measured at 600
## tetrahedra / 2400 cell-vertices - see follow_up notes for the full budget
## table. The 120-cell is 3240 tets and not worth it for a background.
const SOURCE_MESH_PATH := "res://models/primitives/platonic/600_cell/600_cell.g4b"

const SKY_SHADER_PATH := "res://ramon/SkyBoxClouds/shaders/skybox_sky.gdshader"

@export_tool_button("Generate") var _generate_action: Callable = generate
@export_tool_button("Clear") var _clear_action: Callable = clear

@export_group("Shape")
## Distance from the dome's centre to the sky, in metres. Must comfortably
## exceed how far the viewer travels, since this build does not follow anything
## unless [member follow_path] is set.
@export_range(10.0, 5000.0, 10.0, "or_greater", "suffix:m") var radius: float = 500.0:
	set(value):
		radius = value
		_regenerate_if_ready()

## Reverses each tetrahedron's winding. The shader draws both faces
## ([code]cull_disabled[/code]), so this changes nothing visually today - it is
## kept because winding still decides the sign of the flat normal the vertex
## stage computes, which matters the moment any lit sky variant is tried.
@export var flip_winding: bool = false:
	set(value):
		flip_winding = value
		_regenerate_if_ready()

@export_group("Colour")
## Bottom of the gradient (offset 0) is the nadir, top (offset 1) the zenith.
@export var sky_gradient: Gradient = null:
	set(value):
		sky_gradient = value
		_regenerate_if_ready()

## Vertical resolution of the baked ramp. The texture is 1 x this x 1 - only
## the vertical axis carries information, so the other two cost nothing.
@export_range(4, 256, 1) var ramp_resolution: int = 64:
	set(value):
		ramp_resolution = value
		_regenerate_if_ready()

@export_group("Behaviour")
## Optional [Node4D] to stay centred on, so the viewer can never leave the
## dome. Left empty the dome is static, which is fine for a fixed test scene.
@export var follow_path: NodePath = NodePath()

var _ready_to_generate := false


func _ready() -> void:
	_ready_to_generate = true
	if mesh == null:
		generate()


## Keeps the generated shell out of the saved scene.
##
## A MeshInstance4D serializes whatever mesh it holds, so saving with the dome
## generated embeds all 600 tetrahedra into the .tscn - and, far worse, leaves
## `mesh` non-null on load, so [method _ready] skips generate(). Everything
## generate() does at runtime is then skipped too, including assigning the sky
## shader via get_cross_section_material_3d(). The dome falls back to the engine's
## stock cross-section shader, which culls back faces, and from inside the
## shell that means it renders as nothing at all. This is exactly why the sky
## appeared in the editor but not in Play.
##
## Stripping before save and rebuilding after keeps the file small and
## guarantees the runtime setup runs on every load.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			mesh = null
		NOTIFICATION_EDITOR_POST_SAVE:
			if mesh == null:
				generate()


func _process(_delta: float) -> void:
	if follow_path.is_empty():
		return
	var target: Node = get_node_or_null(follow_path)
	if target is Node4D:
		global_position = (target as Node4D).global_position


func _regenerate_if_ready() -> void:
	if _ready_to_generate:
		generate()


func clear() -> void:
	mesh = null


func generate() -> void:
	var source: TetraMesh4D = load(SOURCE_MESH_PATH)
	if source == null:
		push_error("Skydome4D: could not load %s" % SOURCE_MESH_PATH)
		return

	var shell: ArrayTetraMesh4D = source.to_array_tetra_mesh()

	# Every vertex of a regular 4-polytope already lies on a common 3-sphere, so
	# this is a rescale rather than a projection - it cannot distort the shape.
	var vertices: PackedVector4Array = shell.get_vertices()
	for i in range(vertices.size()):
		var length: float = vertices[i].length()
		if length > 0.0:
			vertices[i] = vertices[i] / length * radius
	shell.set_vertices(vertices)

	var indices: PackedInt32Array = shell.get_simplex_cell_indices()
	if flip_winding:
		for i in range(0, indices.size(), 4):
			var swap: int = indices[i + 1]
			indices[i + 1] = indices[i + 2]
			indices[i + 2] = swap
		shell.set_simplex_cell_indices(indices)

	# One UVW per tetrahedron corner, in the same order as the cell index list -
	# TetraMesh4D rejects a texture map whose length differs from that list.
	# Only the vertical component carries meaning: 0 at the nadir, 1 at the
	# zenith. The other two sit at 0.5 so the sampler stays away from the
	# texture's edges regardless of its filter mode.
	var texture_map := PackedVector3Array()
	texture_map.resize(indices.size())
	for i in range(indices.size()):
		var height: float = vertices[indices[i]].y / radius
		texture_map[i] = Vector3(0.5, clampf(0.5 + 0.5 * height, 0.0, 1.0), 0.5)
	shell.simplex_cell_texture_map = texture_map

	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY

	# Swap the engine's cross-section shader for the sky copy BEFORE pushing the
	# texture. Material4D only assigns its built-in shader when the slot is
	# empty, so once this is set it survives; setting the texture afterwards
	# re-runs update_cross_section_material() and pushes `albedo_texture` at the
	# replacement rather than leaving it unbound.
	var cross_section: ShaderMaterial = material.get_cross_section_material_3d()
	cross_section.shader = load(SKY_SHADER_PATH)
	material.albedo_texture_3d = _build_ramp_texture()

	shell.material = material
	mesh = shell


## Bakes [member sky_gradient] into a 1 x N x 1 3D texture. A 3D sampler is the
## only way to vary colour across a tetrahedral surface on this renderer:
## TetraMaterial4D pushes exactly two uniforms, `albedo` and `albedo_texture`,
## and never consults albedo_color_array, so per-vertex and per-cell colours
## both render pure white.
func _build_ramp_texture() -> ImageTexture3D:
	var gradient: Gradient = sky_gradient if sky_gradient != null else _default_gradient()
	var image: Image = Image.create_empty(1, ramp_resolution, false, Image.FORMAT_RGB8)
	for y in range(ramp_resolution):
		var height: float = float(y) / float(ramp_resolution - 1)
		image.set_pixel(0, y, gradient.sample(height))
	var texture := ImageTexture3D.new()
	texture.create(Image.FORMAT_RGB8, 1, ramp_resolution, 1, false, [image])
	return texture


## Deliberately the same three stops as the Isoclynic Sun's sky ramp, so the
## two read as the same world until there is a reason to diverge.
func _default_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.13, 0.11, 0.09),
		Color(0.55, 0.70, 0.95),
		Color(0.05, 0.12, 0.35),
	])
	return gradient
