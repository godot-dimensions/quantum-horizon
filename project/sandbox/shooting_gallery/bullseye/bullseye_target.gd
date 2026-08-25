extends Area4D
## Bullseye Practice's target: reports two independent, never-blended scores -
## an on-screen 2D "aim" score (which of 10 concentric rings the shot landed
## in, read straight off local x/y since this target never rotates)
## and a "slice" score (how well the player's current slice was aligned with
## this target's own w position at the moment of the shot). Both numbers are
## exposed for bullseye_weapon.gd to read at resolution time; neither is
## computed by anyone else.
##
## Deliberately never rotated (identity local basis, always facing the
## spawner's fixed backstop-z layout) - keeping the face plane pinned to
## world x/y is what makes "distance from center in local x/y" the same
## thing as "distance from center on screen," with no basis transform
## needed to score a shot.
##
## Rings are real stacked geometry (5 flat round panels, largest-at-back to
## smallest-at-front along z, each a reoriented instance of the cylinder(ico)
## mesh - see _build_cylinder_panel()), not a texture - same "many small
## pieces build the look" approach already proven on the hazard barrier's
## Stripe0-3 bands and the Holodeck's tiled walls, and it sidesteps the
## UVW-texture-mapping unreliability shape_blocker_spawner_ramon.gd already
## ran into on several imported meshes. Classic 5-color/10-ring archery
## target convention: each color band covers 2 score values with no visible
## seam between them, same as a real target face - not 10 visually distinct
## rings.
##
## Kept thin in w (see W_THICKNESS) like every other target in this project
## (gallery_target.tscn, duck_target.tscn, contest targets) - a bullseye you
## could hit regardless of slice alignment would make the slice score
## meaningless. Made wider than those in x/y (see RADIUS) since aim
## precision, not fast reaction time, is the point of this mode.
##
## The slice-alignment glow curve is IN_SLICE_DISTANCE_EPSILON below is
## identical to slice_alignment_glow.gd's own (same derivation, same
## constants) - reused here to tint this target's own material instead of a
## screen-edge overlay. Confirmed via the engine source that there's no
## built-in shortcut for this: Camera4D's w_fade_mode/w_fade_distance/
## w_fade_slope properties are camera-global (no per-material equivalent
## exists on TetraMaterial4D), and more fundamentally they only affect the
## Wireframe Canvas rendering engine (engine/modules/4d/render/
## wireframe_canvas/wireframe_canvas_rendering_engine_4d.cpp) - this
## project's Camera4D always runs rendering_engine="Cross-section"
## (project/player/player.tscn), which never reads w_fade at all.
## get_alignment_t() is exposed (rather than each caller re-deriving the
## curve) specifically so the live glow and the scored number can never
## silently disagree - both read the exact same computation.

const RADIUS := 1.0 # Half-width/height of the outermost (white) ring - the on-screen scoring face.
const W_THICKNESS := 1.0 # Same order of magnitude as every other target's w-collider - slice alignment must stay a real requirement.
const PANEL_DEPTH := 0.15 # Total z-span the 5 stacked ring layers occupy.
const LAYER_THICKNESS := 0.03

## Outer radius of each of the 10 scoring rings, innermost (score 10) first -
## RADIUS split into 10 even steps. A shot's score is 10 minus the index of
## the first radius its local x/y offset falls within; falling outside all
## of them (index -1, i.e. off the visible face but still inside the
## slightly-generous collider) scores 0.
const RING_OUTER_RADII: PackedFloat32Array = [
	0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0,
]

## 5-color archery band palette, outermost first - each covers 2 of the 10
## rings above (indices 0-1 -> band 0, 2-3 -> band 1, etc.).
const BAND_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.95, 1.0), # White - outermost, scores 1-2.
	Color(0.08, 0.08, 0.08, 1.0), # Black - scores 3-4.
	Color(0.15, 0.35, 0.85, 1.0), # Blue - scores 5-6.
	Color(0.85, 0.1, 0.1, 1.0), # Red - scores 7-8.
	Color(0.95, 0.85, 0.1, 1.0), # Gold - center, scores 9-10. Same gold Ramon uses for his own hit/reward feedback.
]

const OUTER_ANGLE_THRESHOLD_DEG := 30.0
const IN_SLICE_DISTANCE_EPSILON := 0.25
const ALIGNED_TINT_MULTIPLIER := Color(1.35, 1.35, 1.15, 1.0) # Multiplied in, not lerped to - brightens every band equally without washing out their distinct hues.

## All 5 ring panels share this one mesh resource, each reoriented/rescaled
## to its own size by its own MeshInstance4D.basis - see
## _build_cylinder_panel()'s own comment for the reorientation math. Reads as
## a genuine round disc rather than a square, unlike the BoxTetraMesh4D this
## replaced.
const CylinderIcoMesh := preload("res://models/primitives/cylinder/ico/cylinder_smooth_ico2.g4b")

## cylinder_smooth_ico2.g4b's native shape (see workhorse/models/primitives/
## cylinder/make_cylinder.gd, _make_icosahedral_cylinder): round in native
## X/Z/W (an icosahedral cross-section, this radius), thin in native Y only
## (its "cylinder length" - spans 0 to 1, NOT centered like this project's
## usual +-half-size convention). Radius derived analytically from the
## source icosahedron.off vertices (0, +-0.5, +-phi/2) - normalized max
## component = (phi/2) / sqrt(0.25 + (phi/2)^2), phi = golden ratio.
const CYLINDER_NATIVE_ROUND_RADIUS := 0.85065081
const CYLINDER_NATIVE_THIN_LENGTH := 1.0

@onready var player: CharacterBody4D = $"../../Player"

var _band_materials: Array[TetraMaterial4D] = []


func _ready() -> void:
	for i in BAND_COLORS.size():
		# BAND_COLORS is ordered outermost-first (White..Gold), but
		# RING_OUTER_RADII is ordered innermost-first (score 10..1) - rank
		# converts one indexing into the other. Band i's own outer ring is
		# the larger of its pair of two (e.g. White, rank 4, covers ring
		# indices 8-9 - scores 2 and 1 - so its outer edge is RING_OUTER_
		# RADII[9], the full target radius).
		var rank: int = BAND_COLORS.size() - 1 - i
		var outer_index: int = rank * 2 + 1
		var half_size: float = RING_OUTER_RADII[outer_index]
		var material := TetraMaterial4D.new()
		material.albedo_color = BAND_COLORS[i]
		_band_materials.append(material)

		var mesh_instance: MeshInstance4D = _build_cylinder_panel(half_size, rank)
		mesh_instance.material_override = material
		add_child(mesh_instance)

	var collision_shape := CollisionShape4D.new()
	var box_shape := BoxShape4D.new()
	box_shape.size = Vector4(RADIUS * 2.0, RADIUS * 2.0, PANEL_DEPTH, W_THICKNESS)
	collision_shape.shape = box_shape
	add_child(collision_shape)


## Reorients a shared cylinder(ico) mesh instance to this panel's own size:
## native round axes X and Z map onto local x and y (the face toward the
## player); the third native round axis (W) lands on local z and gets
## squeezed down to this panel's thin depth (LAYER_THICKNESS) so it reads
## as a flat coin, not a ball; native Y (the mesh's one genuinely thin
## axis) lands on local w, matching every other target's w-thinness
## convention (W_THICKNESS) - with a centering correction, since native Y
## spans 0..1 rather than this project's usual +-half-size convention.
## Rotation and scale are combined directly into one basis (a pure axis
## permutation, each column scaled to its target extent) rather than
## composed as separate rotate-then-scale steps - equivalent, fewer
## operations. Confirmed safe under non-uniform scale: the cross-section
## shader recomputes normals per-frame from the sliced triangle's own
## world-space edges, not from a stored mesh normal transformed by this
## basis, so there's no inverted-normal risk here.
func _build_cylinder_panel(half_size: float, rank: int) -> MeshInstance4D:
	var round_scale: float = half_size / CYLINDER_NATIVE_ROUND_RADIUS
	var depth_scale: float = LAYER_THICKNESS / (2.0 * CYLINDER_NATIVE_ROUND_RADIUS)
	var w_scale: float = W_THICKNESS / CYLINDER_NATIVE_THIN_LENGTH

	var mesh_instance := MeshInstance4D.new()
	mesh_instance.mesh = CylinderIcoMesh
	# Columns are where each NATIVE axis ends up, scaled to its target extent
	# in the same motion: native X -> local x, native Z -> local y, native
	# W -> local z, native Y -> local w.
	mesh_instance.basis = Projection(
		Vector4(round_scale, 0, 0, 0),
		Vector4(0, 0, 0, w_scale),
		Vector4(0, round_scale, 0, 0),
		Vector4(0, 0, depth_scale, 0),
	)
	# z: same front-to-back stacking every panel uses. w: native Y's 0..1
	# span becomes 0..w_scale after the basis above - centering it here.
	mesh_instance.position = Vector4(0, 0, rank * -LAYER_THICKNESS, -w_scale * 0.5)
	return mesh_instance


func _process(_delta: float) -> void:
	if player == null:
		return
	var alignment_t: float = get_alignment_t()
	var multiplier: Color = Color(1, 1, 1, 1).lerp(ALIGNED_TINT_MULTIPLIER, alignment_t)
	for i in _band_materials.size():
		_band_materials[i].albedo_color = BAND_COLORS[i] * multiplier


## Which of the 10 rings a world-space hit point falls in, read off local x/y
## only (this target's basis is always identity, so local x/y IS world x/y
## minus this target's own position) - 10 is dead center, 0 is a miss on the
## panel entirely.
func get_ring_score(world_point: Vector4) -> int:
	var local_offset: Vector4 = world_point - global_position
	var radius: float = Vector2(local_offset.x, local_offset.y).length()
	for i in RING_OUTER_RADII.size():
		if radius <= RING_OUTER_RADII[i]:
			return 10 - i
	return 0


## 0-1: how well the player's CURRENT slice is aligned with this target's w
## position, right now - identical curve to slice_alignment_glow.gd (see
## that script's own comment for the full derivation): 0 beyond 30 degrees
## off-slice, 1 once genuinely intersecting (within the target's own
## physical w-thickness), eased between with a t*t curve.
func get_alignment_t() -> float:
	var bearing: Dictionary = BearingUtility4D.compute(player, global_position)
	var rel_length: float = bearing.rel.length()
	var angle_deg: float = absf(rad_to_deg(bearing.angle_off_slice))
	var inner_threshold_deg: float = (
		rad_to_deg(asin(clampf(IN_SLICE_DISTANCE_EPSILON / rel_length, -1.0, 1.0))) if rel_length > 0.0001 else 0.0
	)
	if angle_deg <= inner_threshold_deg:
		return 1.0
	if angle_deg >= OUTER_ANGLE_THRESHOLD_DEG:
		return 0.0
	var t: float = clampf((OUTER_ANGLE_THRESHOLD_DEG - angle_deg) / (OUTER_ANGLE_THRESHOLD_DEG - inner_threshold_deg), 0.0, 1.0)
	return t * t
