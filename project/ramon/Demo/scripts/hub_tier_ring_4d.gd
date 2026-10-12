@tool
extends Node4D

## Lays hub2's gates out along an arc, same as hub1, but each gate's height
## comes from an authored tier instead of sitting flat - and reaching a
## non-ground tier depends on the player's w-slice. See HUB2_README.md for the
## full pitch; this is the placement half of it.
##
## Forked from hub1's hub_gate_ring_4d.gd rather than reused - the whole point
## of hub2 is a different structural idea, and hub1 must keep generating
## exactly what it always has for the A/B to mean anything.
##
## BEARING VS TIER. [member gates]' array order drives angular position exactly
## as in hub1 - it is derived, never hand-placed. [member HubTierGateDef4D.tier]
## is the one thing each resource authors, and this script is what turns that
## int into a height, a platform, and - for anything above ground - a ramp
## whose collision only exists in one w-band. Tier 0 gets none of that: it is
## ground level, always solid, always reachable, by construction rather than by
## any per-gate flag.
##
## WHY A GATE'S OWN FRAME NEVER GETS A CollisionShape4D: matching hub1, whose
## generated pillars and lintels are pure geometry. The PLATFORM and RAMP are
## the parts of hub2 a player actually has to stand on, so those are the parts
## built as StaticBody4D - same split PhaseMaze's builder uses between decor and
## walkable panels.

const GateScript := preload("res://ramon/Demo/scripts/hub_tier_gate_4d.gd")
const SurfaceMaterial := preload("res://ramon/Demo/scripts/hub_material_4d.gd")
const GENERATED_META := "hub_generated"

@export_tool_button("Rebuild ring") var _rebuild_action: Callable = rebuild

## The catalogue. Array order drives bearing, exactly as in hub1 - reordering
## re-lays-out the arc.
@export var gates: Array[HubTierGateDef4D] = []:
	set(value):
		gates = value
		rebuild()

## Tier 1, 2, ... in order. Tier 0 (ground, dead ahead) is not in this array -
## it has no ramp and no w-dependency, so there is nothing here to describe it.
@export var tiers: Array[HubTier4D] = []:
	set(value):
		tiers = value
		rebuild()

@export_group("Layout")
@export_range(4.0, 40.0, 0.5, "suffix:m") var radius: float = 10.5:
	set(value):
		radius = value
		rebuild()

## Wider than hub1's 60 degrees on purpose: "left" and "right" need to actually
## read as different bearings for an address built from them to be memorable.
@export_range(20.0, 340.0, 1.0, "suffix:°") var arc_degrees: float = 150.0:
	set(value):
		arc_degrees = value
		rebuild()

@export_range(-180.0, 180.0, 1.0, "suffix:°") var arc_offset_degrees: float = 0.0:
	set(value):
		arc_offset_degrees = value
		rebuild()

@export_group("Gate defaults")
@export_range(0.5, 6.0, 0.1, "suffix:m") var aperture_radius: float = 1.1:
	set(value):
		aperture_radius = value
		rebuild()

@export_range(0.1, 2.0, 0.05, "suffix:m") var frame_thickness: float = 0.25:
	set(value):
		frame_thickness = value
		rebuild()

@export_range(0.1, 3.0, 0.05, "suffix:m") var frame_depth: float = 0.6:
	set(value):
		frame_depth = value
		rebuild()

@export_range(0.0, 6.0, 0.1, "suffix:m") var threshold_depth: float = 2.0:
	set(value):
		threshold_depth = value
		rebuild()

@export var use_dev_textures: bool = true:
	set(value):
		use_dev_textures = value
		rebuild()

@export_range(0.1, 32.0, 0.1, "suffix:m") var texture_metres: float = 1.0:
	set(value):
		texture_metres = value
		rebuild()

@export_group("Platforms and ramps")
## Extra floor beyond the gate's own footprint, on every side - so there is
## somewhere to stand after climbing, and before the ramp starts.
@export_range(0.5, 6.0, 0.1, "suffix:m") var platform_margin: float = 1.5:
	set(value):
		platform_margin = value
		rebuild()

@export_range(0.5, 6.0, 0.1, "suffix:m") var ramp_width: float = 2.2:
	set(value):
		ramp_width = value
		rebuild()

@export_range(0.05, 1.0, 0.05, "suffix:m") var slab_thickness: float = 0.2:
	set(value):
		slab_thickness = value
		rebuild()

## w-extent for platforms, which - unlike ramps - are never gated. Just needs
## to comfortably exceed anything a tier's [member HubTier4D.w_offset] plus half
## its [member HubTier4D.w_extent] will ever reach.
@export_range(4.0, 200.0, 1.0, "suffix:m") var platform_w_extent: float = 40.0:
	set(value):
		platform_w_extent = value
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	if not is_inside_tree():
		return
	_clear_generated()
	if gates.is_empty():
		return

	var count := gates.size()
	var arc_radians := deg_to_rad(arc_degrees)
	var offset_radians := deg_to_rad(arc_offset_degrees)
	# A single gate sits dead ahead rather than at one end of the arc.
	var step := 0.0 if count <= 1 else arc_radians / float(count - 1)
	var start := 0.0 if count <= 1 else -arc_radians * 0.5

	for i in count:
		var definition: HubTierGateDef4D = gates[i]
		if definition == null:
			push_warning("HubTierRing4D: gates[%d] is empty, skipping." % i)
			continue
		var angle := start + step * float(i) + offset_radians + deg_to_rad(definition.angle_nudge)
		_build_slot(definition, angle, radius + definition.radius_nudge, i)

	_check_spacing(step)


func _clear_generated() -> void:
	for child in get_children():
		if child.has_meta(GENERATED_META):
			child.queue_free()
			remove_child(child)


## One gate's whole vertical address: the door, and - for tier > 0 - the
## platform it stands on and the w-gated ramp leading up to it.
##
## DIRECTIONS, so the maths below reads: [param angle] is measured the same way
## hub1's ring measures it, so [param outward_dir] (away from spawn) and
## [param inward_z] (the gate's own local +Z, facing spawn) come out identical
## to hub1's basis construction at height 0 - confirmed by checking hub1's own
## comment that local -Z points radially outward.
func _build_slot(definition: HubTierGateDef4D, angle: float, gate_radius: float, index: int) -> void:
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	var right_dir := Vector4(cos_a, 0.0, sin_a, 0.0)
	var up_dir := Vector4(0.0, 1.0, 0.0, 0.0)
	var outward_dir := Vector4(sin_a, 0.0, -cos_a, 0.0)
	var inward_z := Vector4(-sin_a, 0.0, cos_a, 0.0)

	var tier: HubTier4D = null
	if definition.tier > 0:
		var tier_index := definition.tier - 1
		if tier_index < tiers.size():
			tier = tiers[tier_index]
		else:
			push_warning(
				"HubTierRing4D: gates[%d] wants tier %d, only %d defined - treating as ground."
				% [index, definition.tier, tiers.size()]
			)
	var height: float = tier.height if tier != null else 0.0

	var slot := Node4D.new()
	slot.name = "Slot%d_%s" % [index, definition.gate_name.validate_node_name()]
	slot.set_meta(GENERATED_META, true)
	add_child(slot)

	var gate := Node4D.new()
	gate.set_script(GateScript)
	gate.name = "Gate"
	gate.aperture_radius = aperture_radius
	gate.frame_thickness = frame_thickness
	gate.frame_depth = frame_depth
	gate.threshold_depth = threshold_depth
	gate.use_dev_textures = use_dev_textures
	gate.texture_metres = texture_metres
	gate.gate_name = definition.gate_name
	gate.visited = definition.visited
	# Local +Z faces spawn, local -Z points radially outward - hub1's exact
	# convention, so a script reading either hub's gates cannot get it backwards
	# by assuming the other one's sign.
	gate.basis = Projection(right_dir, up_dir, inward_z, Vector4(0.0, 0.0, 0.0, 1.0))
	gate.position = outward_dir * gate_radius + up_dir * height
	slot.add_child(gate)

	if tier == null:
		return

	# The platform has to clear the gate's own frame depth and threshold pad on
	# its inner (spawn-facing) edge, plus a margin on both edges to actually
	# stand on.
	var outer_radius := gate_radius + frame_depth * 0.5 + platform_margin
	var inner_radius := gate_radius - frame_depth * 0.5 - threshold_depth - platform_margin
	var platform_depth := outer_radius - inner_radius
	var platform_width := aperture_radius * 2.0 + frame_thickness * 2.0 + platform_margin * 2.0
	var platform_centre_radius := (outer_radius + inner_radius) * 0.5

	_build_platform(slot, platform_width, platform_depth, platform_centre_radius, right_dir, up_dir, outward_dir, height)
	_build_ramp(slot, tier, inner_radius, right_dir, up_dir, outward_dir, height)


## A small flat, ALWAYS-PRESENT floor patch the gate stands on. w-invariant, on
## purpose: a platform that could vanish under a player already standing on it
## would be a much harsher lesson than the ramp disappearing on approach, and
## the brief asked for legible, not punishing.
func _build_platform(
	slot: Node4D,
	width: float,
	depth: float,
	centre_radius: float,
	right_dir: Vector4,
	up_dir: Vector4,
	outward_dir: Vector4,
	height: float
) -> void:
	var size := Vector4(width, slab_thickness, depth, platform_w_extent)

	var body := StaticBody4D.new()
	body.name = "Platform"
	# -right_dir, not right_dir: (right, up, outward) is a MIRROR of the proper
	# (det = +1) frame the gate itself uses, (right, up, inward) - outward is
	# -inward, and flipping one column of an orthonormal basis flips its
	# determinant. A mirrored transform inverts every face's winding, which is
	# exactly the "inverted normals" symptom. Negating right_dir instead of
	# outward_dir fixes the parity for free: the box is symmetric across its own
	# width axis, so nothing about its shape or position changes.
	body.basis = Projection(-right_dir, up_dir, outward_dir, Vector4(0.0, 0.0, 0.0, 1.0))
	body.position = outward_dir * centre_radius + up_dir * (height - slab_thickness * 0.5)
	body.set_meta(GENERATED_META, true)
	slot.add_child(body)

	var collider := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = SurfaceMaterial.surface("grey", size, texture_metres, use_dev_textures)
	body.add_child(mesh_instance)


## The one w-varying structure in hub2. Its box - collision AND mesh alike - is
## sized [member HubTier4D.w_extent] along w and offset [member
## HubTier4D.w_offset], so PhysicsServer4D genuinely has no shape there outside
## that band, the same real slice-dependent solidity Phase Maze's walls use -
## not just a visual fade like hub1's ghosted door, which has no collider to
## begin with.
##
## TILTING WITHOUT TOUCHING w: the ramp's local y (thickness) and z (length)
## axes are [param up_dir] and [param outward_dir] rotated toward each other by
## the slope angle, in their own shared plane - an ordinary 3D-style tilt, using
## none of the rotation planes that involve w. Local x (width) and w stay
## exactly [param right_dir] and the fourth axis, untouched.
func _build_ramp(
	slot: Node4D,
	tier: HubTier4D,
	inner_radius: float,
	right_dir: Vector4,
	up_dir: Vector4,
	outward_dir: Vector4,
	height: float
) -> void:
	var theta := atan2(height, tier.ramp_run)
	var slope_length := sqrt(tier.ramp_run * tier.ramp_run + height * height)
	var tilted_up := up_dir * cos(theta) - outward_dir * sin(theta)
	var tilted_forward := up_dir * sin(theta) + outward_dir * cos(theta)

	var size := Vector4(ramp_width, slab_thickness, slope_length, tier.w_extent)

	var body := StaticBody4D.new()
	body.name = "Ramp"
	# -right_dir for the same reason _build_platform negates it: tilting
	# (up_dir, outward_dir) toward each other is a rotation, which preserves
	# whatever determinant the frame started with, so the mirror carries
	# straight through into the tilted basis unless corrected here too.
	body.basis = Projection(-right_dir, tilted_up, tilted_forward, Vector4(0.0, 0.0, 0.0, 1.0))
	# Centred halfway along the slope, which sits at (inner_radius - ramp_run/2)
	# out from spawn and half the tier's height up - the far (outward, high) end
	# lands exactly on the platform's inner edge at the platform's own height,
	# and the near (inward, low) end lands on the main floor at y = 0.
	var mid_radius := inner_radius - tier.ramp_run * 0.5
	body.position = outward_dir * mid_radius + up_dir * (height * 0.5) + Vector4(0.0, 0.0, 0.0, tier.w_offset)
	body.set_meta(GENERATED_META, true)
	slot.add_child(body)

	var collider := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = SurfaceMaterial.surface("grey", size, texture_metres, use_dev_textures)
	body.add_child(mesh_instance)


## Warns rather than silently producing a layout where neighbouring gates or
## platforms overlap - same reasoning as hub1's version, trimmed since hub2 has
## no billboards to collide.
func _check_spacing(step: float) -> void:
	if gates.size() < 2:
		return
	var spacing := radius * step
	var gate_width := (aperture_radius + frame_thickness) * 2.0
	if spacing < gate_width * 1.1:
		push_warning(
			"HubTierRing4D: gates overlap - %.1f m apart but %.1f m wide. Increase radius or arc_degrees, or remove a gate."
			% [spacing, gate_width]
		)
