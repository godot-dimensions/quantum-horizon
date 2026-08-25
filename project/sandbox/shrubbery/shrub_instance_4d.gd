@tool
class_name ShrubInstance4D
extends Node4D
## One shrub, built from a ShrubSpecies4D config via ShrubGenerator4D +
## ShrubMeshBuilder4D (see the approved port plan). Self-contained:
## creates its own "Mesh" MeshInstance4D child on demand rather than
## requiring a hand-authored scene structure, unlike voxel_mining_block.gd's
## "Ground" convention (that block's own scene predates this script; a
## shrub has no equivalent pre-authored scene yet).
##
## Strips its generated mesh before an editor save and rebuilds right
## after (see _notification), matching voxel_mining_block.gd's and
## voxel_terrain_4d.gd's own identical pattern - a MeshInstance4D
## serializes whatever mesh it holds, and this project has already hit a
## real 24MB/90k-tet scene-bloat case from skipping this.

@export_tool_button("Generate") var _generate_action: Callable = generate
@export_tool_button("Clear") var _clear_action: Callable = clear

@export var species: ShrubSpecies4D = null

const _WOOD_MESH_CHILD_NAME := "WoodMesh"
const _LEAF_MESH_CHILD_NAME := "LeafMesh"

static var _wood_material: TetraMaterial4D = null
static var _leaf_material: TetraMaterial4D = null


func _ready() -> void:
	var mesh_instance := _get_wood_mesh_instance()
	if mesh_instance != null and mesh_instance.mesh == null:
		generate()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		clear()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		generate()


## Builds separate wood/leaf meshes (each its own flat-color material)
## rather than one mesh in one color - see ShrubMeshBuilderBlocky4D's own
## voxel_id_filter comment for why (Material4D's per-vertex color path is
## dead code in this engine's shader; separate meshes are the only way to
## get more than one flat color short of the full palette-texture
## system). Uses the fast blocky builder, not ShrubMeshBuilder4D's smooth
## one - see that class's own header for why the smooth path is
## currently impractical (172s measured for one tiny shrub).
func generate() -> void:
	if species == null:
		push_warning("ShrubInstance4D.generate() called with no species assigned - skipping.")
		return
	var generator := ShrubGenerator4D.new(species.seed)
	generator.build_trunk(species)
	generator.spawn_attractors_from_tesseract(species)
	generator.grow(species)
	var voxels: Dictionary = generator.voxelize(species)

	var wood_mesh: ArrayTetraMesh4D = ShrubMeshBuilderBlocky4D.build_mesh(voxels, species, ShrubGenerator4D.VOXEL_ID_WOOD)
	var leaf_mesh: ArrayTetraMesh4D = ShrubMeshBuilderBlocky4D.build_mesh(voxels, species, ShrubGenerator4D.VOXEL_ID_LEAF)

	var wood_instance := _get_or_create_wood_mesh_instance()
	wood_instance.mesh = wood_mesh
	wood_instance.material_override = _get_wood_material()

	var leaf_instance := _get_or_create_leaf_mesh_instance()
	leaf_instance.mesh = leaf_mesh
	leaf_instance.material_override = _get_leaf_material()


func clear() -> void:
	var wood_instance := _get_wood_mesh_instance()
	if wood_instance != null:
		wood_instance.mesh = null
	var leaf_instance := _get_leaf_mesh_instance()
	if leaf_instance != null:
		leaf_instance.mesh = null


func _get_wood_mesh_instance() -> MeshInstance4D:
	return get_node_or_null(_WOOD_MESH_CHILD_NAME) as MeshInstance4D


func _get_leaf_mesh_instance() -> MeshInstance4D:
	return get_node_or_null(_LEAF_MESH_CHILD_NAME) as MeshInstance4D


## Creates a mesh-instance child on first use and, when running inside
## the editor, assigns it an owner so it actually persists as a scene
## node across saves (with its heavy .mesh data stripped/rebuilt
## separately - see _notification) - the real target use case is a
## handful of hand-placed showcase shrubs saved into a real .tscn, not a
## purely transient runtime rig like motion_lab_creature.gd's own legs.
func _get_or_create_mesh_instance(child_name: String) -> MeshInstance4D:
	var existing := get_node_or_null(child_name) as MeshInstance4D
	if existing != null:
		return existing
	var mesh_instance := MeshInstance4D.new()
	mesh_instance.name = child_name
	add_child(mesh_instance)
	if Engine.is_editor_hint():
		var tree := get_tree()
		if tree != null and tree.edited_scene_root != null:
			mesh_instance.owner = tree.edited_scene_root
	return mesh_instance


func _get_or_create_wood_mesh_instance() -> MeshInstance4D:
	return _get_or_create_mesh_instance(_WOOD_MESH_CHILD_NAME)


func _get_or_create_leaf_mesh_instance() -> MeshInstance4D:
	return _get_or_create_mesh_instance(_LEAF_MESH_CHILD_NAME)


## One shared flat-color material per voxel type across every shrub
## instance - matches this codebase's own established convention
## (terrain4d_chunk_pool.gd's own comment: "one shared TetraMaterial4D
## per color band... matches the flat-albedo_color pattern used
## everywhere else").
static func _get_wood_material() -> TetraMaterial4D:
	if _wood_material == null:
		_wood_material = TetraMaterial4D.new()
		_wood_material.albedo_color = Color(0.35, 0.22, 0.12, 1)
	return _wood_material


static func _get_leaf_material() -> TetraMaterial4D:
	if _leaf_material == null:
		_leaf_material = TetraMaterial4D.new()
		_leaf_material.albedo_color = Color(0.25, 0.55, 0.18, 1)
	return _leaf_material
