extends Node4D
## Floating "body" placeholder for the single-limb IK/foot-placement
## prototype. Reuses the EXACT x/z/w wander logic from
## terrain4d_creature_4d.gd's _pick_new_target/_step_toward_target
## (see that file for the fuller rationale) - deliberately WITHOUT that
## script's ground-raycast Y-tracking, since this body floats at a fixed
## height on purpose: ground-relative placement is the ATTACHED LIMB's job
## (later steps of this prototype), not the body's.

@export var speed: float = 2.0
@export var arrival_threshold: float = 0.3

## Base radius (before this creature's own scale) of the region the 4
## fixed waypoints (see _generate_waypoints) are scattered within, centered
## on spawn position. Replaces the old wander_min/wander_max box clamp,
## which also pinned w to a single fixed slice - waypoints now vary in x,
## z, AND w, real 4D freedom rather than a 3D wander dressed up in 4D.
@export var waypoint_region_radius: float = 6.0

## Eased-turn time constant (see _turn_toward_travel_direction) - same
## "1.0 - exp(-delta/tau)" shape already used for player-facing realignment
## in sandbox/shooting_gallery/w_targeting.gd.
@export var turn_time_constant_sec: float = 0.4

## Per-class body/leg proportions - segment-length ratios, hip/anchor
## height, and overall scale as real per-class data, applied to this
## body's own 4 LimbAnchor children (and their IKChain/joint/mesh
## descendants) once at spawn, rather than baked separately into N copies
## of the scene file's node tree.
##
## "steed" reproduces the rig's original, already-verified proportions
## EXACTLY (scale=1.0, front/back segment ratios both 0.4:0.3333:0.2667 -
## the same 3.0:2.5:2.0 this whole arc's entire verification history was
## built on - body_height 4.5, anchor offsets 1.8/0.5/-0.5) - a
## deliberate no-op baseline, not a fresh derivation, so applying "steed"
## can never be a regression relative to anything already verified.
##
## "hopper" gives the hind legs their own, LONGER reach
## (back_reach_multiplier) than the front legs, at a much lower overall
## body height - the combination is what reads as "curled hind legs" at
## rest: the hind legs have real slack (more reach than the low body
## height actually needs), which the unconstrained FABRIK solve resolves
## into some bend rather than a straight strut, without this file needing
## to dictate a specific bend shape itself (that's exactly the kind of
## anatomical styling ik_chain_controller.gd's own hinge constraints would
## normally own - currently disabled fleet-wide, see that file's own
## STATUS note - so what shows up here is whatever FABRIK naturally finds,
## not a hand-posed curl).
##
## "giraffe" is a straightforward large uniform scale-up with the SAME
## ratios as steed (both front and back legs are proportionally long, not
## just tall) - real giraffes' fore and hind legs are close enough in
## length that a symmetric scale-up is a reasonable placeholder.
const BASE_TOTAL_REACH := 7.5 # 3.0+2.5+2.0 - the original, verified rig's own total reach.
const BASE_SEGMENT_RATIOS: Array[float] = [0.4, 0.333333, 0.266667] # 3.0:2.5:2.0, normalized.
const BASE_BODY_HEIGHT := 4.5
const BASE_ANCHOR_FORWARD := 1.8
const BASE_ANCHOR_LATERAL := 0.5
const BASE_ANCHOR_DROP := 0.5
## Reference length for the separate, non-FABRIK foot segment (see
## limb_prototype_foot_segment.gd) - roughly 15% of the 3-joint chain's own
## total reach, an unmeasured placeholder same as every other rest-length
## constant here.
const BASE_FOOT_HEIGHT := 0.15 * BASE_TOTAL_REACH

const CREATURE_CLASSES := {
	"steed": {
		"scale": 1.0,
		"front_segment_ratios": BASE_SEGMENT_RATIOS,
		"back_segment_ratios": BASE_SEGMENT_RATIOS,
		"back_reach_multiplier": 1.0,
		"standing_utilization_ratio": 0.8,
	},
	"hopper": {
		"scale": 0.6,
		"front_segment_ratios": [0.45, 0.35, 0.20], # Short, simple front legs.
		"back_segment_ratios": [0.30, 0.45, 0.25], # Longer thigh+shin proportion - the "powerful hind leg" shape.
		"back_reach_multiplier": 1.6, # Hind legs have real slack relative to the low body height below - see this const's own header.
		# Kept at this rig's own original, proven-safe ratio (NOT the 0.8
		# steed/giraffe use) - measured directly (_verify_resting_fraction_
		# reach_check_runner.gd, a real 10s gait window): front legs' own
		# max_reach (4.5, vs back's 7.2) is small enough in absolute terms
		# that 0.65 already reintroduces the exact reach-release overfiring
		# this rig was previously fixed to avoid (2 fires/10s at 0.5333 vs.
		# 15-16 at 0.65, 17-18 at 0.8 - a threshold, not a gradual slide).
		# Steed/giraffe have no such asymmetry and stayed at 0-4 fires/10s
		# even at 0.8, so only hopper needs its own value here.
		"standing_utilization_ratio": 0.5333,
	},
	"giraffe": {
		"scale": 2.5,
		"front_segment_ratios": BASE_SEGMENT_RATIOS,
		"back_segment_ratios": BASE_SEGMENT_RATIOS,
		"back_reach_multiplier": 1.0,
		"standing_utilization_ratio": 0.8,
	},
}

@export_enum("steed", "hopper", "giraffe") var creature_class: String = "steed"

## Body-level state, NOT a gait preset (see gait_controller.gd's own
## _input handling for the key that toggles this) - stops wander motion
## outright rather than switching to a "zero speed" gait, and is read
## directly by gait_controller.gd to freeze phase_progress in lockstep
## (see that file's own _physics_process) so no NEW swing gets triggered
## while halted. A leg already mid-LIFTING/SWINGING is untouched by this
## flag and keeps evolving on its own elapsed-time clock in
## limb_prototype_foot_target.gd, finishing its landing normally instead
## of freezing mid-air.
var halted: bool = false

var _target_xzw: Vector4
## 4 fixed points generated once at spawn (see _generate_waypoints) -
## _pick_new_target just draws randomly from this set instead of
## continuously re-randomizing from wherever the body currently is, so the
## roam stays within a bounded, scale-proportionate region without needing
## a box clamp.
var _waypoints: Array[Vector4] = []


func _ready() -> void:
	# Explicitly runs before limb_prototype_foot_target.gd's default (0)
	# priority - same reasoning as gait_controller.gd's own explicit
	# priority (both are upstream inputs FootTarget reads every frame).
	process_physics_priority = -1
	# Synchronous, not deferred, and BEFORE _pick_new_target - this needs
	# to have already resized every leg's link_lengths/joint positions by
	# the time limb_prototype_foot_target.gd's own _ready() sums
	# ik_chain.link_lengths into max_reach, which happens synchronously in
	# ITS _ready(), not deferred. That ordering is guaranteed by ordinary
	# Godot scene-tree _ready() order (this node's whole subtree - Body,
	# LimbAnchorFL/FR/BL/BR, their IKChains - is declared, and therefore
	# readies, before the sibling FootTarget nodes declared later in the
	# same scene file), not an explicit priority - _ready() order (unlike
	# _physics_process order) doesn't need one.
	_apply_creature_class()
	_generate_waypoints()
	_pick_new_target()


## See CREATURE_CLASSES' own header for the per-class design rationale.
## Repositions each LimbAnchor, resizes its IKChain's link_lengths AND the
## matching joints' own local positions (both must move together - moving
## only link_lengths would desync the solver's assumed lengths from the
## scene tree's own real, physical joint spacing), and rescales the
## segment meshes to match, purely as a visual - IK correctness never
## depends on mesh size, only on link_lengths and joint local positions
## agreeing with each other.
func _apply_creature_class() -> void:
	var data: Dictionary = CREATURE_CLASSES[creature_class]
	var scale: float = data["scale"]
	var back_reach_multiplier: float = data["back_reach_multiplier"]

	# Body height is sized off the FRONT legs' own reach specifically
	# (front always uses reach multiplier 1.0 in every class above), not
	# whichever leg is longest. Sizing off the longer back legs instead
	# was tried first and measured to leave the front legs reach-starved:
	# hopper's front legs (total_reach 4.5, vs back's 7.2) ended up using
	# ~89% of their own reach just standing still (vs this rig's own
	# proven-good ~53% baseline ratio), so the ordinary drift of a normal
	# walk consumed their much-smaller remaining budget far faster,
	# firing the reach-based release backstop (limb_prototype_foot_
	# target.gd's own reach_release_fraction safety net) roughly 4x more
	# often than the phase gate alone intended - confirmed directly (22
	# cycles in 20s on a preset built for ~5). Sizing off the front legs'
	# OWN reach at the SAME ratio this whole rig was already verified at
	# reproduces that same safe ratio regardless of class; the longer
	# back legs then end up with genuinely MORE slack, not less - that
	# slack is exactly what should read as "curled hind legs" at rest.
	var front_total_reach: float = BASE_TOTAL_REACH * scale
	# Per-class now (see this dict entry's own comment above for why hopper
	# needs a different value than steed/giraffe) - hip_suspension_solver.gd
	# is the live owner of position.y from here on; this is only the
	# spawn-frame SEED, but matching its own target avoids a visible
	# one-time pop between spawn and its first correction (pushed onto that
	# sibling node below, once it's confirmed present).
	var standing_utilization_ratio: float = data["standing_utilization_ratio"]
	# +BASE_FOOT_HEIGHT*scale - this formula predates the separate foot
	# segment (limb_prototype_foot_segment.gd): FootTarget's own ankle
	# target sits foot_height ABOVE the true ground contact point (see
	# foot_height's own comment in limb_prototype_foot_target.gd), so
	# omitting it here was quietly sizing the body ~1 unit too low relative
	# to what hip_suspension_solver.gd now computes every frame from the
	# SAME ankle target - confirmed directly (measured a ~1.1 unit jump at
	# spawn before the solver's first correction).
	position.y = BASE_ANCHOR_DROP * scale + BASE_FOOT_HEIGHT * scale + standing_utilization_ratio * front_total_reach

	# A smaller creature covers less absolute ground per stride - scaling
	# speed with the SAME overall scale keeps the reach-release backstop's
	# absolute drift budget (reach_release_fraction*max_reach minus the
	# geometric standing distance) proportionate to how far a single
	# stride actually needs to carry the anchor, rather than leaving a
	# physically tiny creature's tiny leg budget getting drained by a
	# full-sized creature's own absolute wander speed.
	speed = speed * scale

	for leg_name in ["FL", "FR", "BL", "BR"]:
		var anchor: Node4D = get_node("LimbAnchor%s" % leg_name)
		var is_front: bool = leg_name.begins_with("F")
		var forward_sign: float = 1.0 if is_front else -1.0
		var lateral_sign: float = 1.0 if leg_name.ends_with("L") else -1.0
		var reach_multiplier: float = 1.0 if is_front else back_reach_multiplier
		var total_reach: float = BASE_TOTAL_REACH * scale * reach_multiplier
		var ratios: Array = data["front_segment_ratios"] if is_front else data["back_segment_ratios"]

		anchor.position = Vector4(
			forward_sign * BASE_ANCHOR_FORWARD * scale,
			-BASE_ANCHOR_DROP * scale,
			lateral_sign * BASE_ANCHOR_LATERAL * scale,
			0.0
		)

		var ik_chain: Node = anchor.get_node("IKChain")
		var new_lengths: Array[float] = []
		for ratio in ratios:
			new_lengths.append(total_reach * ratio)
		ik_chain.link_lengths = new_lengths

		var joint1: Node4D = ik_chain.get_node("Joint1")
		var joint2: Node4D = joint1.get_node("Joint2")
		var joint3: Node4D = joint2.get_node("Joint3")
		joint2.position = Vector4(0, new_lengths[0], 0, 0)
		joint3.position = Vector4(0, new_lengths[1], 0, 0)

		_rescale_segment_mesh(joint1.get_node("ExtensionMesh1"), new_lengths[0], BASE_SEGMENT_RATIOS[0] * BASE_TOTAL_REACH)
		_rescale_segment_mesh(joint2.get_node("ExtensionMesh2"), new_lengths[1], BASE_SEGMENT_RATIOS[1] * BASE_TOTAL_REACH)
		_rescale_segment_mesh(joint3.get_node("ExtensionMesh3"), new_lengths[2], BASE_SEGMENT_RATIOS[2] * BASE_TOTAL_REACH)

		# The separate, non-FABRIK foot segment (limb_prototype_foot_
		# segment.gd) and its FootTarget sibling both need this class's own
		# foot height - FootTarget lives as a sibling of Body (both direct
		# children of the same scene root), not under this leg's own
		# subtree, so it's reached via get_parent() rather than anchor.
		# get_node_or_null throughout this block - older scenes authored
		# before the foot segment existed have no "Foot" child under Joint3
		# and no foot_height export on their FootTarget; skip gracefully
		# rather than crashing them.
		var foot_height: float = BASE_FOOT_HEIGHT * scale
		var foot_target: Node = get_parent().get_node_or_null("FootTarget%s" % leg_name)
		if foot_target != null and "foot_height" in foot_target:
			foot_target.foot_height = foot_height
		var foot_node: Node4D = joint3.get_node_or_null("Foot")
		if foot_node != null:
			foot_node.rest_length = foot_height
			_rescale_segment_mesh(foot_node.get_node("ExtensionMeshFoot"), foot_height, BASE_FOOT_HEIGHT)

	# hip_suspension_solver.gd is a sibling too (see the foot_target sibling
	# comment above for why get_parent() rather than anchor) - it needs the
	# SAME per-class ratio just used for the spawn-frame seed above, since
	# it's the one that actually owns position.y every frame from here on;
	# get_node_or_null so scenes without one (e.g. an older/simpler rig)
	# skip gracefully rather than crashing.
	var hip_suspension_solver: Node = get_parent().get_node_or_null("HipSuspensionSolver")
	if hip_suspension_solver != null and "resting_extension_fraction" in hip_suspension_solver:
		hip_suspension_solver.resting_extension_fraction = standing_utilization_ratio

	var body_mesh: MeshInstance4D = get_node_or_null("BodyMesh")
	if body_mesh != null:
		var mesh: BoxTetraMesh4D = body_mesh.mesh.duplicate()
		mesh.size = mesh.size * scale
		body_mesh.mesh = mesh


## Repositions a segment's extension mesh to the new segment's midpoint and
## rescales it (length exactly, thickness proportionally to the same
## length change) so a much longer/shorter leg doesn't end up wearing its
## ORIGINAL, unscaled mesh. Duplicates the mesh resource first - every leg's
## ExtensionMesh1 (etc.) shares ONE SubResource in the scene file by
## default, so mutating .size in place without duplicating would silently
## resize every OTHER leg's same-numbered segment too, most visibly wrong
## for hopper (front and back legs need genuinely different lengths).
func _rescale_segment_mesh(mesh_instance: MeshInstance4D, new_length: float, base_length: float) -> void:
	mesh_instance.position = Vector4(0, new_length * 0.5, 0, 0)
	var length_scale: float = new_length / base_length
	var mesh: OrthoplexTetraMesh4D = mesh_instance.mesh.duplicate()
	mesh.size = Vector4(mesh.size.x * length_scale, new_length, mesh.size.z * length_scale, mesh.size.w * length_scale)
	mesh_instance.mesh = mesh


## _physics_process, NOT _process - this body's position IS every leg's
## anchor (LimbAnchorFL/FR/BL/BR are its own children), read from
## ik_chain_controller.gd's _physics_process and used to build
## limb_prototype_foot_target.gd's own raycast targets there too. Moving
## it on the idle/render tick instead - decoupled from the fixed physics
## tick everything downstream actually runs on - was tried first (it's
## the original, harmless-looking form this script shipped with) and
## measured to be a real, second source (after gait_controller.gd's own
## identical mistake) of run-to-run gait non-determinism: since ALL FOUR
## legs share this one moving anchor, a step taken between physics ticks
## shows up as the exact same simultaneous residual spike (~0.27-0.29
## units) on every leg at once - confirmed directly, three of four legs'
## measured max_residual matched to 5 decimal places in an affected run.
func _physics_process(delta: float) -> void:
	if halted:
		return
	_step_toward_target(delta)
	_turn_toward_travel_direction(delta)


func _step_toward_target(delta: float) -> void:
	var to_target := Vector4(_target_xzw.x - position.x, 0.0, _target_xzw.z - position.z, _target_xzw.w - position.w)
	var dist := to_target.length()
	if dist <= arrival_threshold:
		_pick_new_target()
		return
	var move := to_target.normalized() * minf(speed * delta, dist)
	position.x += move.x
	position.z += move.z
	position.w += move.w


## Horizontal (x/z/w) direction currently being walked, for anything that
## wants to lead slightly ahead of the body (e.g. foot placement) instead of
## targeting directly underneath it. Derived from the same to-target vector
## _step_toward_target already computes, not a separately tracked velocity -
## this body's wander motion IS always a straight line toward _target_xzw,
## so the two are identical by construction.
func get_travel_direction() -> Vector4:
	var to_target := Vector4(_target_xzw.x - position.x, 0.0, _target_xzw.z - position.z, _target_xzw.w - position.w)
	if to_target.length() < 0.0001:
		return Vector4(0, 0, 1, 0) # Arrived/degenerate - arbitrary but stable default direction.
	return to_target.normalized()


## 4 waypoints scattered within waypoint_region_radius * this creature's own
## scale, centered on wherever _apply_creature_class() left this body's
## spawn position (after body-height placement, before any wander motion) -
## called once, from _ready(), before the first _pick_new_target(). Real 4D
## freedom: w varies exactly like x/z, no longer pinned to a fixed slice.
func _generate_waypoints() -> void:
	var r: float = waypoint_region_radius * CREATURE_CLASSES[creature_class]["scale"]
	_waypoints.clear()
	for i in range(4):
		_waypoints.append(position + Vector4(
			randf_range(-r, r), 0.0, randf_range(-r, r), randf_range(-r, r),
		))


## Plain random draw from the fixed 4-waypoint set, repeats allowed - not a
## fresh re-randomization from the current position (that was the old
## continuous-random-walk behavior; this is a patrol between fixed points
## instead).
func _pick_new_target() -> void:
	_target_xzw = _waypoints[randi() % _waypoints.size()]


## Purely visual - eases global_basis toward get_travel_direction() every
## frame, independent of _step_toward_target's own straight-line motion, so
## turning and moving happen together ("turn while walking") rather than as
## a separate phase. get_travel_direction() itself is untouched by this
## (still the exact straight-line-to-target vector ik_chain_controller.gd's
## own hinge-forward reference already reads via this body), so this is a
## pure visual add-on with no effect on leg targeting.
func _turn_toward_travel_direction(delta: float) -> void:
	var current_forward: Vector4 = global_basis.x # This rig's front-back axis - see ik_chain_controller.gd's own root_forward_local comment.
	var desired_forward: Vector4 = get_travel_direction()
	if desired_forward.length() < 0.0001:
		return
	if current_forward.dot(desired_forward) >= 1.0 - 0.0000001:
		return
	var rotor: Rotor4D = _rotor_from_to(current_forward, desired_forward)
	if rotor == null:
		return # Antipodal - no well-defined shortest path this frame; try again next frame.
	var fraction: float = 1.0 - exp(-delta / turn_time_constant_sec)
	global_basis = rotor.slerp_fraction(fraction).rotate_basis(global_basis)


## Same bisector construction duplicated in ik_chain_controller.gd,
## w_targeting.gd, and limb_prototype_foot_segment.gd - see any of those
## for the full derivation.
func _rotor_from_to(from_dir: Vector4, to_dir: Vector4) -> Rotor4D:
	var bisector: Vector4 = from_dir + to_dir
	if bisector.length() < 0.0001:
		return null
	return Rotor4D.vector_product(from_dir, bisector.normalized()).normalized()
