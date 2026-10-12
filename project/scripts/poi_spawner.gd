extends Node
## Randomly places POI4D markers on a generated VoxelTerrain4D's actual
## surface. Testing ground for the supporting systems a real spawn/loot/
## base-placement system would need - not a game loop itself (see poi.gd's
## own header).
##
## Surface points come directly from the terrain's own generated Ground
## mesh vertices, not a raycast (this project's own collision - see
## voxel_hover_camera_4d.gd's header - collapses everything to a bounding
## box, so real raycasting against the actual surface isn't available the
## way it would be in 3D) and not a re-derived height function (the
## terrain's density functions are anonymous closures private to
## _add_model_layer, not separately callable, and for the "plane"/"globe"
## models the height term isn't solvable in closed form anyway - see
## voxel_terrain_4d.gd's own noise sampling). Ground/<brick>.mesh
## (ArrayTetraMesh4D) vertices are written directly in the terrain's own
## LOCAL space (voxel_terrain_4d.gd's _build_mesh: `world_position =
## (grid_position - center) * cell_size`, same for PLANAR and RADIAL - shape
## only affects color banding, not vertex placement), and each brick's
## MeshInstance4D is added with no position of its own (confirmed: created
## via `MeshInstance4D.new()` with no `.position` assignment) - so a
## vertex's LOCAL coordinate IS already exactly the local coordinate a
## POI4D child of this same terrain needs for its own `.position`, no
## transform math required at all.

## Number of POIs to spawn per category - see poi.gd's Category enum.
@export var poi_counts: Dictionary = {
	POI4D.Category.ORE: 6,
	POI4D.Category.BASE: 2,
	POI4D.Category.UNIT: 4,
}
## 0 = real randomness each run; nonzero = a reproducible layout (useful
## for comparing before/after screenshots).
@export var random_seed: int = 0
## Lifts each POI slightly above the sampled vertex so its marker mesh
## doesn't z-fight/clip into the ground mesh at the exact same point.
@export var surface_lift: float = 0.6

@export var terrain_path: NodePath
## Where to parent spawned POIs - MUST be the terrain itself or a
## Node4D descendant of it with no position/rotation of its own, so a
## sampled terrain-local vertex coordinate can be used as this node's
## .position directly and still land in the right place, AND so global_
## position automatically tracks the terrain's own current 4D rotation
## (rig.basis) for free, the same way the terrain's own geometry does -
## see poi.gd's own header. Left unset, POIs are parented directly onto
## the terrain node.
@export var poi_container_path: NodePath
## If true, waits for the terrain to actually have generated/loaded
## content, then spawns automatically - no external caller needs to know
## the terrain's own generation timing. Off for callers that want to spawn
## at a specific moment themselves (e.g. right after a specific bake
## finishes loading) via spawn_all() directly.
@export var auto_spawn: bool = true

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if auto_spawn:
		_wait_and_auto_spawn()


## Polls for actual collectible surface points, NOT terrain._generated_bricks
## - confirmed by direct testing that _generated_bricks[bk] is set true
## before that brick's Ground mesh child actually exists (there's a real
## window, wide enough to matter, where bricks are "generated" but have no
## surface to sample from yet). Waiting on the real thing we need, not a
## proxy for it, avoids depending on exactly when that dict is populated
## relative to mesh-build - which isn't this script's concern to track.
func _wait_and_auto_spawn() -> void:
	var terrain: Node4D = _get_terrain()
	if terrain == null:
		return
	while _collect_surface_points_local(terrain).is_empty():
		await get_tree().create_timer(0.5).timeout
	spawn_all()


func _get_terrain() -> Node4D:
	return get_node_or_null(terrain_path) as Node4D


func _get_container() -> Node4D:
	if not poi_container_path.is_empty():
		var container: Node4D = get_node_or_null(poi_container_path) as Node4D
		if container != null:
			return container
	return _get_terrain()


## Every ground-mesh vertex currently generated, in the terrain's own local
## space - see this script's own header for why no transform is needed.
func _collect_surface_points_local(terrain: Node4D) -> PackedVector4Array:
	var points := PackedVector4Array()
	var ground: Node = terrain.get_node_or_null("Ground")
	if ground == null:
		return points
	for chunk in ground.get_children():
		if chunk is MeshInstance4D and chunk.mesh is ArrayTetraMesh4D:
			var mesh: ArrayTetraMesh4D = chunk.mesh
			points.append_array(mesh.get_vertex_positions())
	return points


func spawn_all() -> void:
	if random_seed != 0:
		_rng.seed = random_seed

	var terrain: Node4D = _get_terrain()
	var container: Node4D = _get_container()
	if terrain == null or container == null:
		push_warning("POISpawner4D: terrain_path/poi_container_path not resolved - nothing spawned.")
		return

	var surface_points: PackedVector4Array = _collect_surface_points_local(terrain)
	if surface_points.is_empty():
		push_warning("POISpawner4D: terrain has no generated surface yet - call spawn_all() after generation completes.")
		return

	for category in poi_counts.keys():
		for i in range(int(poi_counts[category])):
			var point: Vector4 = surface_points[_rng.randi() % surface_points.size()]
			point.y += surface_lift

			var poi := POI4D.new()
			poi.category = category
			poi.position = point
			container.add_child(poi)


## Removes every previously-spawned POI4D under the container, so
## spawn_all() can be called again (e.g. after loading a different bake)
## without accumulating duplicates.
func clear_all() -> void:
	var container: Node4D = _get_container()
	if container == null:
		return
	for child in container.get_children():
		if child is POI4D:
			child.queue_free()
