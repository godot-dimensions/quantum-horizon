@tool
extends Node4D
class_name AscentBuilder4D

## Builds the Phase 1 greybox shell of THE 4D ASCENT: spine, station decks,
## recovery floors, checkpoints and the temporary stairs that make the whole
## tower walkable with no 4D moves at all.
##
## PHASE 1 EXIT GATE (from the brief): "ordinary 3D traversal complete". Every
## stair generated here is scaffolding, due to be deleted beat by beat as real
## obstacles replace it - that is what `suppress_phase1_stair` is for. Keeping
## the course finishable at every commit is the whole point of the gated build
## order, so the scaffolding leaves one station at a time, never all at once.
##
## WHAT THE ENGINE AUDIT FORCED (measured, see `_audit_probe.gd`):
##
## - Every collider is an AXIS-ALIGNED BOX and nothing here is ever rotated. A
##   `BoxShape4D` rotated 45 degrees in zw was measured to inflate its collision
##   bounds by x1.414, because `AxisAlignedBoxPhysicsEngine4D` reduces every
##   shape to `get_rect_bounds_global()`. Rotated bridges and diagonal W ramps
##   are therefore not representable, and the brief's branch B is forced.
## - There are NO SLOPES, for the same reason: an axis-aligned box can only ever
##   present an axis-aligned normal, so `CharacterBody4D._determine_surface_type`
##   can never see one. Height is gained by steps, never by ramps.
## - Steps are capped at [member max_step_rise] because `CharacterBody4D` has NO
##   step-up logic whatsoever (`_snap_distance` is 0.1 m and nothing else). Every
##   rise is cleared by jumping, and the measured jump apex is 1.033 m, so the
##   default 0.8 m leaves real margin for a mistimed jump.
##
## Generated nodes are deliberately NOT owned by the scene, so none of this is
## serialised into `ascent.tscn` - same discipline as the Demo hub, and the
## reason a `MeshInstance4D` full of generated geometry never bloats a scene
## file here. `_verify_ascent.gd` asserts it, because a violation stays
## invisible until the scene file is unexpectedly enormous weeks later.

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")
const SurfaceMaterial := preload("res://ramon/Demo/scripts/hub_material_4d.gd")
const StationDef := preload("res://ramon/ObstacleCourse/scripts/ascent_station_def.gd")

## Marks everything this script spawns, so `rebuild()` can clear its own output
## without ever touching a hand-placed node.
const GENERATED_META := &"ascent_generated"

## Per-tier palette names. Index is [member AscentStationDef4D.tier].
const TIER_COLOURS: Array[String] = ["white", "yellow", "red"]

## Measured in `_audit_probe.gd`: JUMP_VELOCITY 4.5 against gravity 9.8 gives an
## apex of 1.033 m. Anything at or above this is uncrossable, not merely hard.
const MEASURED_JUMP_APEX := 1.033

## Measured walk-jump horizontal reach at SPEED 5.0 (airtime 0.918 s). Gaps
## wider than this need a 4D solution; gaps narrower than it do not, whatever
## the designer intended.
const MEASURED_WALK_JUMP_REACH := 4.592


@export_group("Course")

## The course, in order. Array order is route order and drives the helix, so
## moving an entry re-lays-out the tower.
@export var stations: Array[Resource] = []:
	set(value):
		stations = value
		rebuild()

## Total rotation around the spine across the whole climb, in degrees. 1080 is
## three full turns, which keeps consecutive bays clearly apart while letting the
## player see the tower wrap.
@export var total_bearing_degrees: float = 1080.0:
	set(value):
		total_bearing_degrees = value
		rebuild()

## Distance from the spine axis to a deck's centre.
@export var deck_radius: float = 9.0:
	set(value):
		deck_radius = value
		rebuild()

@export_group("Spine")

## The invariant reference the whole course is read against. Broad in BOTH z and
## w on purpose: the brief asks for a hyperbox rather than a w-thin pole, so that
## it is equally present in every slice the player can rotate to. A spine that
## thinned out under rotation would fail exactly when it is most needed.
@export var spine_size_xz: float = 4.0:
	set(value):
		spine_size_xz = value
		rebuild()

@export var spine_height: float = 34.0:
	set(value):
		spine_height = value
		rebuild()

## How far the spine extends along w, centred on w = 0. Large enough that no
## reachable rotation or w-translation takes the player outside it.
@export var spine_w_extent: float = 40.0:
	set(value):
		spine_w_extent = value
		rebuild()

@export_group("Geometry")

## Slab thickness for decks, steps and recovery floors.
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

## Maximum rise per step. Held below [constant MEASURED_JUMP_APEX] by
## [method rebuild], which clamps rather than trusts, because a step taller than
## the jump apex is a soft-locked course and the failure looks like bad level
## design rather than a bad number.
@export var max_step_rise: float = 0.8:
	set(value):
		max_step_rise = value
		rebuild()

## Square footprint of one temporary stair step. Square so that a flight running
## at any bearing needs no rotation - which it could not have anyway.
@export var step_footprint: float = 2.0:
	set(value):
		step_footprint = value
		rebuild()

@export_group("Recovery")

## How far below a tier's lowest deck its reset plane sits. Anything that falls
## past every deck in the tier crosses this and is returned to the tier's
## checkpoint.
##
## THERE ARE NO RECOVERY FLOORS, deliberately. The first build gave every station
## a full-span slab three metres below it, and a top-down render showed the
## result immediately: ten opaque 30 m ceilings stacked up the tower, hiding
## everything above and burying the brief's "vertical spectacle comes from seeing
## the tower above". They also overlapped, since consecutive stations are only
## 2-5 m apart and the slab for one sat exactly on the deck of the one below.
##
## The helix is tight enough that the PREVIOUS STATION'S DECK is already the
## recovery floor for the next - a missed jump falls a station, not a tier. So
## the only thing still needed is a catch for a fall that misses everything, and
## that is better served by a reset volume than by geometry: it costs seconds,
## honours "no failure sends the player below the current tier checkpoint", and
## leaves the tower open all the way up.
@export var reset_depth: float = 6.0:
	set(value):
		reset_depth = value
		rebuild()

## Half-width of the reset volume, generously past [member deck_radius] so a fall
## in any direction is caught.
@export var reset_margin: float = 10.0:
	set(value):
		reset_margin = value
		rebuild()

@export_group("Look")

@export var use_dev_textures: bool = true:
	set(value):
		use_dev_textures = value
		rebuild()

## World size of one texture tile, shared with the Demo hub so the two read at
## the same grain.
@export var texture_metres: float = 2.0:
	set(value):
		texture_metres = value
		rebuild()

@export_tool_button("Rebuild course") var _rebuild_action: Callable = rebuild


func _ready() -> void:
	rebuild()


## Clears and regenerates everything. Safe to call repeatedly.
func rebuild() -> void:
	# A @tool script that gained exports while its scene was open hands back Nil
	# for them until the scene is reloaded, and a Nil BOOL reads as false, which
	# would silently skip geometry and merely look unfinished. Typed guards turn
	# that into one readable warning instead. Every new toggle joins this list.
	if typeof(use_dev_textures) != TYPE_BOOL:
		push_warning("AscentBuilder4D: stale @tool properties. Reload the scene (Scene > Reload Saved Scene).")
		return
	if not is_inside_tree():
		return

	_clear_generated()

	if max_step_rise >= MEASURED_JUMP_APEX:
		push_warning("AscentBuilder4D: max_step_rise %.2f m is at or above the measured jump apex %.2f m - the course would be uncompletable. Clamping." % [max_step_rise, MEASURED_JUMP_APEX])

	_build_spine()

	var defs := _valid_stations()
	if defs.is_empty():
		return

	var previous_centre := Vector4()
	var has_previous := false
	for index in defs.size():
		var def: AscentStationDef4D = defs[index]
		var centre := _station_centre(index, defs.size(), def)
		_build_deck(def, centre)
		if has_previous and not def.suppress_phase1_stair:
			_build_phase1_stair(def, previous_centre, centre)
		previous_centre = centre
		has_previous = true

	_build_tier_reset_volumes(defs)


## Discards nulls and anything that is not a station, so one bad array entry
## cannot take the whole tower down.
func _valid_stations() -> Array:
	var out: Array = []
	for entry in stations:
		var def := entry as AscentStationDef4D
		if def != null:
			out.append(def)
	return out


## Where a station's deck centre sits. Bearing is derived by spreading the whole
## course evenly over [member total_bearing_degrees], so inserting a beat
## re-spaces every other one rather than requiring them all to be re-typed.
func _station_centre(index: int, count: int, def: AscentStationDef4D) -> Vector4:
	var t: float = 0.0 if count <= 1 else float(index) / float(count - 1)
	var degrees: float = t * total_bearing_degrees + def.bearing_nudge_degrees
	var radians := deg_to_rad(degrees)
	return Vector4(sin(radians) * deck_radius, def.height, -cos(radians) * deck_radius, 0.0)


func _tier_colour(tier: int) -> String:
	return TIER_COLOURS[clampi(tier, 0, TIER_COLOURS.size() - 1)]


## The always-present central reference. Grey rather than any tier colour,
## because it belongs to no tier and reading it as "the white part of the tower"
## would defeat its job.
func _build_spine() -> void:
	var size := Vector4(spine_size_xz, spine_height, spine_size_xz, spine_w_extent)
	var body := _make_static_box("Spine", size, Vector4(0.0, spine_height * 0.5, 0.0, 0.0), "grey")
	add_child(body)


func _build_deck(def: AscentStationDef4D, centre: Vector4) -> void:
	var size := Vector4(def.deck_size.x, slab_thickness, def.deck_size.y, structure_w_extent)
	var position := Vector4(centre.x, centre.y - slab_thickness * 0.5, centre.z, 0.0)
	var body := _make_static_box("Deck_%s" % def.beat_id, size, position, _tier_colour(def.tier))
	add_child(body)

	if def.is_checkpoint:
		_build_checkpoint(def, centre)


## Checkpoint volumes are cyan, not the tier colour, and not yellow.
##
## The brief reserves cyan for "the currently valid cross-section" and turns the
## goal cyan when the final alignment is right, so cyan already means "you are
## correctly here". A checkpoint is the same claim about position, which makes it
## the honest colour - and crucially it keeps tier colour meaning ONLY tier. The
## brief's own kill criteria fire if testers start reading tier colour as a
## spatial cue, so nothing spatial is ever encoded in white/yellow/red.
func _build_checkpoint(def: AscentStationDef4D, centre: Vector4) -> void:
	var pad_size := Vector4(minf(def.deck_size.x, 4.0), 0.06, minf(def.deck_size.y, 4.0), structure_w_extent)
	var pad_position := Vector4(centre.x, centre.y + 0.03, centre.z, 0.0)
	var pad := _make_mesh_only("CheckpointPad_%s" % def.beat_id, pad_size, pad_position, "cyan")
	add_child(pad)

	var area := Area4D.new()
	area.name = "Checkpoint_%s" % def.beat_id
	area.position = Vector4(centre.x, centre.y + 1.0, centre.z, 0.0)
	area.set_meta(GENERATED_META, true)
	var collider := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	# Deliberately tall and w-broad: a checkpoint the player can miss by being in
	# the wrong slice is worse than no checkpoint, since it silently costs them
	# the recovery they think they have.
	shape.size = Vector4(pad_size.x, 2.0, pad_size.z, structure_w_extent)
	collider.shape = shape
	area.add_child(collider)
	add_child(area)


## One invisible reset plane per tier, below that tier's lowest deck.
##
## An Area4D rather than a slab, so it catches a fall without becoming a ceiling
## for the tier underneath - see the note on [member reset_depth] for why that
## distinction cost a rebuild to learn.
func _build_tier_reset_volumes(defs: Array) -> void:
	var lowest: Dictionary = {}
	for entry in defs:
		var def: AscentStationDef4D = entry
		var tier: int = clampi(def.tier, 0, TIER_COLOURS.size() - 1)
		if not lowest.has(tier) or def.height < lowest[tier]:
			lowest[tier] = def.height

	var span: float = (deck_radius + reset_margin) * 2.0
	for tier: int in lowest:
		var area := Area4D.new()
		area.name = "TierReset_%d" % tier
		area.position = Vector4(0.0, lowest[tier] - reset_depth, 0.0, 0.0)
		area.set_meta(GENERATED_META, true)
		var collider := CollisionShape4D.new()
		var shape := BoxShape4D.new()
		# Thin in Y so it reads as a plane, but w-broad for the same reason the
		# checkpoints are: a player who has translated along w must still be
		# caught, or they fall forever in a slice nothing is watching.
		shape.size = Vector4(span, 2.0, span, structure_w_extent * 2.0)
		collider.shape = shape
		area.add_child(collider)
		add_child(area)


## Temporary Phase 1 scaffolding: a flight of square steps from the previous
## station to this one, so the tower is walkable before any 4D obstacle exists.
##
## Steps are square and axis-aligned, which lets a flight run at ANY bearing with
## no rotation at all - necessary, since a rotated box's collider inflates and
## would no longer match what is drawn.
func _build_phase1_stair(def: AscentStationDef4D, from_centre: Vector4, to_centre: Vector4) -> void:
	var rise: float = to_centre.y - from_centre.y
	if rise <= 0.001:
		return
	var effective_rise: float = minf(max_step_rise, MEASURED_JUMP_APEX - 0.1)
	var count: int = int(ceil(rise / effective_rise))
	if count <= 0:
		return

	var parent := Node4D.new()
	parent.name = "Phase1Stair_%s" % def.beat_id
	parent.set_meta(GENERATED_META, true)
	add_child(parent)

	# Stops one short of the destination: the final step would land at exactly the
	# deck's own height and span exactly the deck's own slab, so it is not a step
	# at all, it is a second copy of the deck sitting inside the first. Two
	# coincident boxes render as fighting white patches in the flat cross-section
	# shader, which has no depth bias to hide the overlap.
	for step_index in range(1, count):
		var t: float = float(step_index) / float(count)
		var height: float = from_centre.y + rise * t
		var x: float = lerpf(from_centre.x, to_centre.x, t)
		var z: float = lerpf(from_centre.z, to_centre.z, t)
		var size := Vector4(step_footprint, slab_thickness, step_footprint, structure_w_extent)
		var position := Vector4(x, height - slab_thickness * 0.5, z, 0.0)
		# Grey, not the tier colour: scaffolding should be visually obvious as
		# scaffolding, so nobody mistakes a temporary stair for authored content
		# when reviewing a screenshot.
		var body := _make_static_box("Step_%02d" % step_index, size, position, "grey")
		parent.add_child(body)


## A solid box: collider and mesh sized and positioned identically. Same
## collision-plus-visual split `phase_maze_builder.gd` uses for its walls.
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


## Visual-only geometry, with no collider at all. Used for surface inlays like
## the checkpoint pad, which the player should walk over rather than step onto -
## there is no step-up logic, so even a 6 cm lip would be a wall.
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
