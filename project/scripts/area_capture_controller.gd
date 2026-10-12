class_name AreaCaptureController
extends Node4D
## "Draw an area, capture it" prototype. First draw_area press (T) raycasts
## from the player's current view against the ground's real collision shape
## (same PhysicsServer4D.raycast_physics_objects pattern hitscan_weapon.gd's
## own _fire_hitscan() uses: origin = player head position, direction = head's
## own -Z) to place corner 1. While waiting for the second press, every frame
## re-raycasts for a live corner 2 and previews a translucent BoxTetraMesh4D
## spanning both corners across x/z/w TOGETHER, not a flat x/z footprint -
## rotating the player's 4D slice (right-drag, per player.gd) between the two
## placements is exactly what lets the box pick up a real w-extent, since the
## ground itself already has w-extent to hit. Second press locks it in: swaps
## the preview material for a solid, distinctly-colored one (not a terrain
## edit - this box just sits on top of the ground) and starts fresh for the
## next box, leaving prior captured boxes in place.
##
## Box height is small and FIXED (CAPTURE_HEIGHT), not derived from the two
## corners' own y - deliberate groundwork for a fence feature planned after
## this: swapping in a taller CAPTURE_HEIGHT later needs no other change here.
##
## draw_area is a real InputMap action (not a raw Input.is_key_pressed check)
## specifically so it stays easily rebindable, per the project's established
## convention for player-facing controls (move_*, fire, rotate_4d, etc.) -
## unlike voxel_hover_camera_4d.gd's raw-key dev-tool exception, this is
## meant to be a real gameplay mechanic going forward.
##
## While idle (not yet drawing), a small "ghost" marker continuously
## previews where corner 1 will land if draw_area is pressed right now - the
## same ground raycast used for the real placement, just rendered before
## committing to it. Only shown within GHOST_MAX_DISTANCE of the player:
## beyond that, placement isn't just imprecise, it's not really "reach"
## anymore, so the marker disappears rather than implying a placement that
## wouldn't feel intentional.
##
## Rendered as a BoxWireMesh4D outline, not a filled BoxTetraMesh4D - the
## Cross-section shader (tetra_cross_section_shader.glsl) only ever writes
## ALBEDO, never ALPHA, so a TetraMaterial4D's albedo_color.a is silently
## ignored and every filled shape renders fully opaque regardless of alpha
## (confirmed directly: an alpha-0.12 white filled box rendered as solid
## opaque white, not a faint tint - caught by an actual screenshot, not
## assumed). A sparse wireframe is genuinely subtler on screen than a filled
## shape even at full opacity, simply by covering far less area - the same
## reason voxel_hover_camera_4d.gd's own edit-highlight already uses
## OrthoplexWireMesh4D instead of a filled mesh for its own "preview,
## haven't committed yet" marker. Real alpha blending would need a shader
## change (adding an ALPHA write) - a shared, higher-risk edit affecting
## every TetraMaterial4D-rendered object, not something to make unprompted
## for one dev-tool marker.
##
## reset_capture (R) clears every captured box and cancels any box in
## progress, back to a clean slate - a full reset rather than an undo-last,
## since this is still a single-attempt puzzle prototype (one cluster, no
## scoring loop yet) where "start over" is the only reset that makes sense.

@export var player_path: NodePath
@export var player_head_path: NodePath
@export var ground_path: NodePath

const CAPTURE_HEIGHT := 0.2
const MIN_AXIS_EXTENT := 0.3
const MAX_AXIS_EXTENT := 40.0
const MAX_RAY_DISTANCE := 300.0
const GHOST_MAX_DISTANCE := 15.0

const PREVIEW_COLOR := Color(0.3, 0.8, 1.0, 0.35)
const CAPTURED_COLOR := Color(0.9, 0.7, 0.1, 1.0)
## Alpha is inert here (see class doc comment on the shader's ALPHA
## limitation) - kept honest at 1.0 rather than implying a fade that isn't
## actually happening. The wireframe itself, not alpha, is what keeps this
## subtle.
const GHOST_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const GHOST_FOOTPRINT := 1.0 # x/z/w size of the idle placement-preview marker.

## Every locked-in box, oldest first - kept around (rather than just the most
## recent) so a later capture-check feature has something to test targets
## against without redesigning this list.
var captured_boxes: Array[MeshInstance4D] = []

var _player: Node
var _player_head: Node4D
var _ground: Node
var _preview_material: TetraMaterial4D
var _ghost_material: TetraMaterial4D
var _ghost_indicator: MeshInstance4D
var _drawing: bool = false
var _corner_a: Vector4 = Vector4.ZERO
var _preview_box: MeshInstance4D


func _ready() -> void:
	_player = get_node_or_null(player_path)
	_player_head = get_node_or_null(player_head_path)
	_ground = get_node_or_null(ground_path)
	_preview_material = TetraMaterial4D.new()
	_preview_material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	_preview_material.albedo_color = PREVIEW_COLOR

	_ghost_material = TetraMaterial4D.new()
	_ghost_material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	_ghost_material.albedo_color = GHOST_COLOR
	_ghost_indicator = MeshInstance4D.new()
	var ghost_mesh := BoxWireMesh4D.new()
	ghost_mesh.size = Vector4(GHOST_FOOTPRINT, CAPTURE_HEIGHT, GHOST_FOOTPRINT, GHOST_FOOTPRINT)
	_ghost_indicator.mesh = ghost_mesh
	_ghost_indicator.material_override = _ghost_material
	_ghost_indicator.visible = false
	add_child(_ghost_indicator)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_capture"):
		_reset_all()
		return
	if not event.is_action_pressed(&"draw_area"):
		return
	if _drawing:
		_lock_in()
	else:
		_start_drawing()


func _start_drawing() -> void:
	var hit: Variant = _raycast_ground()
	if hit == null:
		return
	_corner_a = hit
	_drawing = true
	_ghost_indicator.visible = false
	_preview_box = MeshInstance4D.new()
	_preview_box.mesh = BoxTetraMesh4D.new()
	_preview_box.material_override = _preview_material
	add_child(_preview_box)
	_update_preview(hit)


func _reset_all() -> void:
	if _preview_box != null:
		_preview_box.queue_free()
		_preview_box = null
	for box in captured_boxes:
		box.queue_free()
	captured_boxes.clear()
	_drawing = false


func _process(_delta: float) -> void:
	if not _drawing:
		_update_ghost()
		return
	var hit: Variant = _raycast_ground()
	if hit == null:
		# Keep the box at its last valid position/size rather than hiding or
		# collapsing it - a momentary off-ground look shouldn't discard
		# progress on the box the player is actively drawing.
		return
	_update_preview(hit)


func _update_ghost() -> void:
	var hit: Variant = _raycast_ground()
	if hit == null:
		_ghost_indicator.visible = false
		return
	var hit_point: Vector4 = hit
	if _player_head.global_position.distance_to(hit_point) > GHOST_MAX_DISTANCE:
		_ghost_indicator.visible = false
		return
	_ghost_indicator.visible = true
	_ghost_indicator.position = Vector4(hit_point.x, hit_point.y + CAPTURE_HEIGHT * 0.5, hit_point.z, hit_point.w)


func _update_preview(corner_b: Vector4) -> void:
	var lo := Vector4(
		minf(_corner_a.x, corner_b.x),
		minf(_corner_a.y, corner_b.y),
		minf(_corner_a.z, corner_b.z),
		minf(_corner_a.w, corner_b.w),
	)
	var hi := Vector4(
		maxf(_corner_a.x, corner_b.x),
		maxf(_corner_a.y, corner_b.y),
		maxf(_corner_a.z, corner_b.z),
		maxf(_corner_a.w, corner_b.w),
	)
	var size_x: float = clampf(hi.x - lo.x, MIN_AXIS_EXTENT, MAX_AXIS_EXTENT)
	var size_z: float = clampf(hi.z - lo.z, MIN_AXIS_EXTENT, MAX_AXIS_EXTENT)
	var size_w: float = clampf(hi.w - lo.w, MIN_AXIS_EXTENT, MAX_AXIS_EXTENT)
	var ground_top_y: float = (lo.y + hi.y) * 0.5
	var box_mesh: BoxTetraMesh4D = _preview_box.mesh
	box_mesh.size = Vector4(size_x, CAPTURE_HEIGHT, size_z, size_w)
	_preview_box.position = Vector4(
		(lo.x + hi.x) * 0.5,
		ground_top_y + CAPTURE_HEIGHT * 0.5,
		(lo.z + hi.z) * 0.5,
		(lo.w + hi.w) * 0.5,
	)


func _lock_in() -> void:
	var captured_material := TetraMaterial4D.new()
	captured_material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	captured_material.albedo_color = CAPTURED_COLOR
	_preview_box.material_override = captured_material
	captured_boxes.append(_preview_box)
	_drawing = false
	_preview_box = null


## Returns the world-space hit point on the ground (Vector4), or null if the
## player isn't currently looking at it.
func _raycast_ground() -> Variant:
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = _player_head.global_position
	ray_params.global_ray_direction = -_player_head.global_basis.z
	ray_params.max_distance = MAX_RAY_DISTANCE
	if _player != null:
		ray_params.set_exclude_nodes([_player])
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
	if not result.get("hit", false):
		return null
	if _ground != null and result.get("body") != _ground:
		return null
	# ConcaveMeshShape4D never sets "point"/"global_point" (see
	# terrain4d_voxel_showcase.gd's own comment on this), but a plain
	# BoxShape4D used for this ground slab does - deriving from
	# global_distance regardless is the same robust fallback used
	# elsewhere in this project, and costs nothing when global_point is
	# already present.
	return result.get(
		"global_point",
		ray_params.global_ray_origin + ray_params.global_ray_direction * float(result.get("global_distance", 0.0)),
	)
