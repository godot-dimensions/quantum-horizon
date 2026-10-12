@tool
extends Node4D
class_name AscentWallBuilder4D

## Builds THE 4D ASCENT as the brief's page 5 elevation actually draws it: a
## bounded tower whose back wall carries three tier-coloured bands, a central
## spine, and a route that zigzags left and right across that spine as it climbs.
##
## Separate from `AscentBuilder4D` (the helix course) on purpose. They are two
## different bets on how a vertical 4D course stays legible, and only a playtest
## settles which wins - so neither is allowed to complicate the other. Nothing is
## shared between them but the palette and the material helper.
##
## THE ONE IDEA: the back wall is the HUD. Three coloured bands, seen from
## anywhere in the tower, answer "which tier am I in" without a single pixel of
## screen-space UI. That is why the tower is bounded rather than floating in a
## void, and why the wall is worth its geometry.
##
## WHAT THE ENGINE AUDIT FORCED (measured, see `_audit_probe.gd`):
##
## - Nothing is ever rotated. A `BoxShape4D` at 45 degrees zw was measured to
##   inflate its collision bounds x1.414, because `AxisAlignedBoxPhysicsEngine4D`
##   reduces every shape to `get_rect_bounds_global()`.
## - There are no slopes and cannot be: an axis-aligned box only ever presents an
##   axis-aligned normal. Height is gained by steps.
## - Steps are capped below the measured 1.033 m jump apex, because
##   `CharacterBody4D` has no step-up logic at all.
##
## Generated nodes are NOT owned by the scene, so nothing here is serialised into
## the `.tscn`. `_verify_ascent.gd` asserts it.

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")
const SurfaceMaterial := preload("res://ramon/Demo/scripts/hub_material_4d.gd")
const BayDef := preload("res://ramon/ObstacleCourse/scripts/ascent_bay_def.gd")

const GENERATED_META := &"ascent_generated"

## Index is [member AscentBayDef4D.tier].
const TIER_COLOURS: Array[String] = ["white", "yellow", "red"]

## Measured: JUMP_VELOCITY 4.5 against gravity 9.8. A rise at or above this is
## uncrossable, not merely hard.
const MEASURED_JUMP_APEX := 1.033

## Measured walk-jump horizontal reach (airtime 0.918 s at SPEED 5.0). A gap
## narrower than this needs no 4D solution, whatever the designer intended.
const MEASURED_WALK_JUMP_REACH := 4.592


@export_group("Course")

## The bays, in route order.
@export var bays: Array[Resource] = []:
	set(value):
		bays = value
		rebuild()

@export_group("Tower")

## Brief bounds: 28 m X, 34 m Y, 24 m Z.
@export var tower_size: Vector3 = Vector3(28.0, 34.0, 24.0):
	set(value):
		tower_size = value
		rebuild()

## Y heights where one tier band ends and the next begins. One more entry than
## there are tiers.
@export var tier_boundaries: PackedFloat32Array = PackedFloat32Array([0.0, 10.0, 22.0, 34.0]):
	set(value):
		tier_boundaries = value
		rebuild()

@export var show_back_wall: bool = true:
	set(value):
		show_back_wall = value
		rebuild()

@export var show_ground: bool = true:
	set(value):
		show_ground = value
		rebuild()

@export_group("Spine")

## Footprint as (x, z). THIN IN X, BROAD IN Z. The route crosses left and right
## past the spine, so width in x would block the very traverse the spine exists
## to be a reference for; depth in z is what keeps it present from every bay.
@export var spine_plan_size: Vector2 = Vector2(3.0, 10.0):
	set(value):
		spine_plan_size = value
		rebuild()

## How far the spine extends along w, centred on w = 0.
##
## The brief calls for "a broad 4D hyperbox spanning both Z and W, not a W-thin
## pole" - a spine that thinned out under slice rotation would vanish exactly
## when the player most needs a fixed reference.
@export var spine_w_extent: float = 40.0:
	set(value):
		spine_w_extent = value
		rebuild()

@export_group("W language")

## Violet markers at the brief's W bands. Mesh only, never collidable: these are
## LANGUAGE, and a player who bumps into a label has been taught something false
## about the world.
@export var show_w_lane_markers: bool = true:
	set(value):
		show_w_lane_markers = value
		rebuild()

@export var w_bands: PackedFloat32Array = PackedFloat32Array([-4.0, 0.0, 4.0]):
	set(value):
		w_bands = value
		rebuild()

@export_group("Geometry")

@export var slab_thickness: float = 0.5:
	set(value):
		slab_thickness = value
		rebuild()

## How far ordinary structure extends along w. Phase 1 is entirely w-invariant:
## nothing may vanish under rotation until the white tier deliberately teaches
## that it can.
@export var structure_w_extent: float = 24.0:
	set(value):
		structure_w_extent = value
		rebuild()

## Maximum rise per step. Well under the forked player's 0.7 m step-up allowance,
## so the whole staircase is WALKED rather than jumped - which is what makes a
## 34 m climb tolerable and what a jump-only course could never provide.
@export var max_step_rise: float = 0.35:
	set(value):
		max_step_rise = value
		rebuild()

## Square footprint of one step, so a flight running at any angle needs no
## rotation - which it could not have anyway.
##
## Nothing can be WALKED up in this engine - `CharacterBody4D` has no step-up
## logic at all - so every rise is a jump onto a landing, and tread size is what
## separates a staircase from an obstacle course.
##
## 0.8 m is a WALKING tread, not a landing pad. `ascent_player.tscn` adds step-up
## (0.7 m allowance), so a rise is stepped over rather than jumped onto and the
## tread only has to be wide enough to stand on.
@export var step_footprint: float = 0.8:
	set(value):
		step_footprint = value
		rebuild()

## Throws each step to alternating sides in z, making a flight switchback.
##
## ZERO by default, i.e. straight flights. A two-lane switchback was tried while
## the course was jump-only, and it cannot work at this scale: step N+2 always
## lands directly above step N, so headroom there is two rises minus a slab, and
## getting the 1.75 m a player needs would demand rises above 1.1 m - taller than
## the 1.033 m jump apex. Step-up removes the need for it entirely. Kept as a
## knob because a switchback is still the right answer if a flight ever has to
## climb further than its run allows.
@export var stair_zigzag: float = 0.0:
	set(value):
		stair_zigzag = value
		rebuild()

## Consecutive flights are pushed to opposite sides of the bay's depth by this
## much.
##
## Because the bays alternate left and right, the flight ARRIVING at a bay and
## the flight LEAVING it both run down the same side of it, and without this they
## stack: measured at 0.17 m of headroom between one flight's top tread and the
## next flight's bottom one. Two lanes 3.2 m apart in z keeps them clear of each
## other while both stay inside the bay's own footprint, so you can still step
## straight off either onto the deck.
@export var stair_lane_offset: float = 1.6:
	set(value):
		stair_lane_offset = value
		rebuild()

@export_group("Recovery")

## The brief's white-tier restriction, verbatim: "Every gap has a visible
## recovery floor no more than one jump-height below." White tier only - yellow
## and red are meant to carry risk, and catching every fall there would remove
## the tension those tiers exist to introduce.
@export var show_gap_recovery: bool = true:
	set(value):
		show_gap_recovery = value
		rebuild()

## How far below a tier's lowest bay its reset plane sits.
@export var reset_depth: float = 4.0:
	set(value):
		reset_depth = value
		rebuild()

@export_group("Look")

@export var use_dev_textures: bool = true:
	set(value):
		use_dev_textures = value
		rebuild()

@export var texture_metres: float = 2.0:
	set(value):
		texture_metres = value
		rebuild()

@export_tool_button("Rebuild course") var _rebuild_action: Callable = rebuild


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	# A @tool script that gained exports while its scene was open hands back Nil
	# for them until reload, and a Nil BOOL reads as false - which would skip
	# geometry in total silence and merely look unfinished.
	if typeof(use_dev_textures) != TYPE_BOOL:
		push_warning("AscentWallBuilder4D: stale @tool properties. Reload the scene (Scene > Reload Saved Scene).")
		return
	if not is_inside_tree():
		return

	_clear_generated()

	if max_step_rise >= MEASURED_JUMP_APEX:
		push_warning("AscentWallBuilder4D: max_step_rise %.2f m is at or above the measured jump apex %.2f m - the course would be uncompletable. Clamping." % [max_step_rise, MEASURED_JUMP_APEX])

	_build_spine()
	if show_back_wall:
		_build_back_wall()
	if show_ground:
		_build_ground()
	if show_w_lane_markers:
		_build_w_lane_markers()

	var defs := _valid_bays()
	if defs.is_empty():
		return

	var previous: BayDef = null
	var flight_index: int = 0
	for def: BayDef in defs:
		_build_bay(def)
		if previous != null:
			if not def.suppress_phase1_stair:
				_build_phase1_stair(def, previous, flight_index)
			# A recovery floor is only meaningful once there is a real gap to fall
			# into. While a beat still has its Phase 1 stair there IS no gap, and
			# building the slab anyway put it straight through the stairs of the
			# beat below - the two occupy the same volume by construction. So the
			# recovery floor arrives exactly when the scaffolding leaves.
			elif show_gap_recovery and def.tier == 0 and previous.tier == 0:
				_build_gap_recovery(def, previous)
			flight_index += 1
		previous = def

	_build_tier_reset_volumes(defs)


func _valid_bays() -> Array:
	var out: Array = []
	for entry in bays:
		var def := entry as BayDef
		if def != null:
			out.append(def)
	return out


func _centre(def: BayDef) -> Vector4:
	return Vector4(def.plan_x, def.height, def.plan_z, 0.0)


func _tier_colour(tier: int) -> String:
	return TIER_COLOURS[clampi(tier, 0, TIER_COLOURS.size() - 1)]


## The always-present central reference. Grey, because it belongs to no tier -
## reading it as "the white part of the tower" would defeat its whole job.
func _build_spine() -> void:
	var height: float = tower_size.y
	var size := Vector4(spine_plan_size.x, height, spine_plan_size.y, spine_w_extent)
	add_child(_make_static_box("Spine", size, Vector4(0.0, height * 0.5, 0.0, 0.0), "grey"))


## Three tier-coloured bands. Seen from the front this IS the brief's page 5
## elevation, and it is the reason this course needs no HUD tier indicator.
func _build_back_wall() -> void:
	var band_count: int = tier_boundaries.size() - 1
	if band_count < 1:
		push_warning("AscentWallBuilder4D: tier_boundaries needs at least two entries.")
		return
	for band in band_count:
		var low: float = tier_boundaries[band]
		var high: float = tier_boundaries[band + 1]
		var height: float = high - low
		if height <= 0.0:
			continue
		var size := Vector4(tower_size.x, height, slab_thickness, structure_w_extent)
		var position := Vector4(0.0, low + height * 0.5, tower_size.z * 0.5, 0.0)
		add_child(_make_static_box("TierBand_%d" % band, size, position, _tier_colour(band)))


## The tower floor, as a plinth UNDER the bays rather than level with them.
##
## Its top sits at -slab_thickness, one slab below y = 0. Placing it with its top
## at y = 0 (the obvious choice) makes it exactly co-volumetric with any bay
## authored at height 0 - bay00 is - and two coincident boxes in the flat
## cross-section shader render as fighting white patches that punch through every
## surface around them. That is the "full white wall clipping objects" symptom,
## and it is a geometry bug rather than a material one.
func _build_ground() -> void:
	var size := Vector4(tower_size.x, slab_thickness, tower_size.z, structure_w_extent)
	add_child(_make_static_box("Ground", size, Vector4(0.0, -slab_thickness * 1.5, 0.0, 0.0), "black"))


## Violet strips running the tower's width at each non-zero w band. W0 gets none:
## it is the home slice and therefore the default, and marking the default would
## make it look like one option among several rather than the place you start.
func _build_w_lane_markers() -> void:
	for index in w_bands.size():
		var w: float = w_bands[index]
		if is_zero_approx(w):
			continue
		var size := Vector4(tower_size.x, 0.08, 0.5, 0.5)
		var position := Vector4(0.0, 0.05, -tower_size.z * 0.5 + 1.0, w)
		add_child(_make_mesh_only("WLane_%d" % index, size, position, "violet"))


func _build_bay(def: BayDef) -> void:
	var centre := _centre(def)
	var size := Vector4(def.deck_size.x, slab_thickness, def.deck_size.y, structure_w_extent)
	var position := Vector4(centre.x, centre.y - slab_thickness * 0.5, centre.z, 0.0)
	add_child(_make_static_box("Bay_%s" % def.beat_id, size, position, _tier_colour(def.tier)))
	if def.is_checkpoint:
		_build_checkpoint(def, centre)


## Checkpoints are cyan, not the tier colour and not yellow.
##
## The brief reserves cyan for the currently valid cross-section and turns the
## goal cyan when its final alignment is right, so cyan already means "you are
## correctly here" - which is exactly a checkpoint's claim. It also keeps tier
## colour meaning tier and nothing else.
func _build_checkpoint(def: BayDef, centre: Vector4) -> void:
	var pad_size := Vector4(minf(def.deck_size.x, 4.0), 0.06, minf(def.deck_size.y, 3.0), structure_w_extent)
	add_child(_make_mesh_only("CheckpointPad_%s" % def.beat_id, pad_size, Vector4(centre.x, centre.y + 0.03, centre.z, 0.0), "cyan"))

	var area := Area4D.new()
	area.name = "Checkpoint_%s" % def.beat_id
	area.position = Vector4(centre.x, centre.y + 1.0, centre.z, 0.0)
	area.set_meta(GENERATED_META, true)
	var collider := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	# Tall and w-broad: a checkpoint that can be missed by being in the wrong
	# slice is worse than none, because it silently costs the player the recovery
	# they believe they have.
	shape.size = Vector4(pad_size.x, 2.0, pad_size.z, structure_w_extent)
	collider.shape = shape
	area.add_child(collider)
	add_child(area)


## A visible floor one jump-height under each white-tier gap, so a miss can be
## climbed straight back out of. Spans only the gap - a full-span slab per bay
## was tried on the helix course and stacked into opaque ceilings.
func _build_gap_recovery(def: BayDef, previous: BayDef) -> void:
	var from_centre := _centre(previous)
	var to_centre := _centre(def)
	var low: float = minf(from_centre.y, to_centre.y)

	# The recovery slab's TOP must land one jump-height under the walking surface
	# it catches you from, so it can always be climbed back out of. Getting this
	# sign wrong (`+ slab_thickness`) rode the slab up INTO the deck above it by
	# 0.22 m, and two intersecting boxes render as fighting white patches.
	var top: float = low - MEASURED_JUMP_APEX
	# Below the ground plinth there is nothing to recover onto and no room to put
	# a slab, so the tower floor does that job for the lowest gap instead.
	if top - slab_thickness <= -slab_thickness:
		return

	var span_x: float = absf(to_centre.x - from_centre.x) + def.deck_size.x
	var span_z: float = absf(to_centre.z - from_centre.z) + def.deck_size.y
	var size := Vector4(span_x, slab_thickness, span_z, structure_w_extent)
	var position := Vector4(
			(from_centre.x + to_centre.x) * 0.5,
			top - slab_thickness * 0.5,
			(from_centre.z + to_centre.z) * 0.5,
			0.0)
	add_child(_make_static_box("GapRecovery_%s" % def.beat_id, size, position, "white"))


## One invisible reset plane per tier. An Area4D rather than a slab, so a fall is
## caught without the catcher becoming a ceiling for the tier underneath.
func _build_tier_reset_volumes(defs: Array) -> void:
	var lowest: Dictionary = {}
	for entry in defs:
		var def: BayDef = entry
		var tier: int = clampi(def.tier, 0, TIER_COLOURS.size() - 1)
		if not lowest.has(tier) or def.height < lowest[tier]:
			lowest[tier] = def.height

	for tier: int in lowest:
		var area := Area4D.new()
		area.name = "TierReset_%d" % tier
		area.position = Vector4(0.0, lowest[tier] - reset_depth, 0.0, 0.0)
		area.set_meta(GENERATED_META, true)
		var collider := CollisionShape4D.new()
		var shape := BoxShape4D.new()
		# w-broad for the same reason the checkpoints are: a player who has
		# translated along w must still be caught, or they fall forever in a
		# slice nothing is watching.
		shape.size = Vector4(tower_size.x * 2.0, 2.0, tower_size.z * 2.0, structure_w_extent * 2.0)
		collider.shape = shape
		area.add_child(collider)
		add_child(area)


## Temporary scaffolding so the tower is walkable before any obstacle exists.
## Square, axis-aligned steps, so a flight can run at any angle without rotation.
func _build_phase1_stair(def: BayDef, previous: BayDef, flight_index: int) -> void:
	var from_centre := _centre(previous)
	var to_centre := _centre(def)
	var rise: float = to_centre.y - from_centre.y
	if rise <= 0.001:
		return
	var effective_rise: float = minf(max_step_rise, MEASURED_JUMP_APEX - 0.1)
	var count: int = int(ceil(rise / effective_rise))
	if count <= 0:
		return

	# A flight must advance at least one footprint per step. Below that the treads
	# overlap in plan, the upper step overhangs the lower, and the climb becomes
	# impossible rather than merely hard - so say so loudly rather than shipping
	# a bay pair nobody can get between.
	# Between the bays' FACING EDGES, not their centres. Centre-to-centre buried
	# the top two or three treads of every flight under the destination deck's
	# overhang - 100% covered, 0.07 m of clearance - so you climbed the stair and
	# hit your head on the thing you were climbing towards. Reported in play as
	# "I cannot use the second grey block, it is like it is nested under it".
	var lane: float = -stair_lane_offset if flight_index % 2 == 0 else stair_lane_offset
	var from_edge := _edge_toward(from_centre, previous.deck_size, to_centre) + Vector4(0.0, 0.0, lane, 0.0)
	var to_edge := _edge_toward(to_centre, def.deck_size, from_centre) + Vector4(0.0, 0.0, lane, 0.0)
	var run: float = Vector2(to_edge.x - from_edge.x, to_edge.z - from_edge.z).length()
	# Straight-line advance per step, plus the zigzag throw, is the real distance
	# between consecutive treads.
	var advance: float = Vector2(run / float(count), stair_zigzag * 2.0).length()
	if advance < step_footprint:
		push_warning("AscentWallBuilder4D: bay %s is only %.1f m from the previous bay but climbs %.1f m, so its %d steps advance %.2f m each against a %.2f m footprint. The treads will overlap and the climb will be blocked - move the bays further apart." % [def.beat_id, run, rise, count, advance, step_footprint])

	var parent := Node4D.new()
	parent.name = "Phase1Stair_%s" % def.beat_id
	parent.set_meta(GENERATED_META, true)
	add_child(parent)

	# Stops one short of the destination: the final step would land at exactly the
	# bay's own height and span exactly the bay's own slab, so it is not a step at
	# all, it is a second copy of the deck sitting inside the first.
	for step_index in range(1, count):
		var t: float = float(step_index) / float(count)
		var size := Vector4(step_footprint, slab_thickness, step_footprint, structure_w_extent)
		# Alternate sides in z, so the flight switchbacks instead of running
		# straight. A straight flight cannot give both a low rise and a wide
		# landing inside the 5-8 m between bays, and since NOTHING can be walked
		# up in this engine - every rise is jumped onto a tread - a narrow tread
		# is what makes a staircase feel like it is fighting you. Zigzagging buys
		# real distance between consecutive treads out of the tower's depth
		# rather than its width.
		var side: float = stair_zigzag if step_index % 2 == 1 else -stair_zigzag
		var position := Vector4(
				lerpf(from_edge.x, to_edge.x, t),
				from_centre.y + rise * t - slab_thickness * 0.5,
				lerpf(from_edge.z, to_edge.z, t) + side,
				0.0)
		# Grey, not the tier colour: scaffolding should be obvious AS
		# scaffolding, so nobody reviewing a screenshot mistakes it for content.
		parent.add_child(_make_static_box("Step_%02d" % step_index, size, position, "grey"))


## The point on a bay's rectangular edge facing [param towards]. Used to keep a
## stair in the GAP between two bays rather than under either of them.
func _edge_toward(centre: Vector4, deck_size: Vector2, towards: Vector4) -> Vector4:
	var delta := Vector2(towards.x - centre.x, towards.z - centre.z)
	if delta.length() < 0.001:
		return centre
	# The layout is x-dominant by design (the brief's elevation zigzags across the
	# tower's width), so the facing edge is the x one unless z clearly dominates.
	# delta is a Vector2 in the xz plane, so its second component is .y.
	if absf(delta.x) >= absf(delta.y):
		return Vector4(centre.x + signf(delta.x) * deck_size.x * 0.5, centre.y, centre.z, 0.0)
	return Vector4(centre.x, centre.y, centre.z + signf(delta.y) * deck_size.y * 0.5, 0.0)


func _make_static_box(node_name: String, size: Vector4, position: Vector4, palette_name: String) -> StaticBody4D:
	var body := StaticBody4D.new()
	body.name = node_name
	body.position = position
	body.set_meta(GENERATED_META, true)

	var collider := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = SurfaceMaterial.surface(palette_name, size, texture_metres, use_dev_textures)
	body.add_child(mesh_instance)
	return body


## Visual-only, no collider. For surface inlays and labels - there is no step-up
## logic, so even a 6 cm lip would be a wall.
func _make_mesh_only(node_name: String, size: Vector4, position: Vector4, palette_name: String) -> Node4D:
	var holder := Node4D.new()
	holder.name = node_name
	holder.position = position
	holder.set_meta(GENERATED_META, true)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = SurfaceMaterial.surface(palette_name, size, texture_metres, use_dev_textures)
	holder.add_child(mesh_instance)
	return holder


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			remove_child(child)
			child.queue_free()
