extends Node4D
## Procedurally-built creature for the motion-lab scene. Mirrors limb_
## prototype_body.gd's per-leg construction (same femur/tibia/cannon-style
## chain, same BASE_* placement constants), but instead of that file's own
## random 4D waypoint patrol, this is a literal TREADMILL: the body sits on
## a loose horizontal tether (a restoring spring back toward its spawn x,
## see _physics_process) rather than genuinely walking across the
## platform, while each foot's own GROUND CONTACT point slides backward
## while planted, at a fixed, gait-dependent belt speed (see
## limb_prototype_foot_target.gd's own belt_speed) - exactly how a real
## treadmill works: the belt moves under a roughly-stationary animal, not
## the other way around. The player watches from one spot, the creature
## always appears to be mid-stride, and nobody has to chase a randomly-
## turning (or steadily-drifting) target around a platform.
##
## History: an earlier draft held the body FULLY, rigidly stationary.
## Measured directly, not assumed, to be the actual cause of a reported
## "flicking last segment" symptom: with zero body translation AND no
## belt-style compensation, every single swing's target was EXACTLY the
## same point as before (confirmed: swing displacement measured 0.0% of
## total limb reach across multiple steps, in _verify_motion_lab_flick_
## diagnosis_runner.gd) - a real stride needs the foot target to actually
## move fore/aft relative to the hip for the whole chain to visibly
## articulate. A second draft paced back-and-forth, which fixed that but
## read as pacing, not walking. A third draft had the body genuinely,
## ballistically walk forward and periodically teleport back once it
## wandered far enough (wraparound) - technically correct (confirmed
## numerically: no leg-stretch artifact across the teleport) but VISUALLY
## broken from this scene's side-on camera: a 20-unit position snap reads
## as an obvious sideways jump-cut, not the invisible reset a plain floor
## mesh was assumed (wrongly) to make it. This tether+belt version fixes
## that at the root: the body never travels far enough from spawn to need
## a reset at all, because the "walking forward" illusion lives entirely
## in the belt-scroll applied to foot placement, not in genuine body
## translation.
##
## Builds the WHOLE rig (legs, joints, feet, FootTargets, GaitController)
## fresh via Node4D.new()/add_child() every time a parameter changes, since
## limb_count/segment_count can't be expressed as resizing fixed, scene-
## authored nodes the way creature_class can. Attached to "Body" - the same
## role limb_prototype_body.gd plays in creature_template.tscn; the parent
## node plays "Creature" (owns GaitController + FootTarget* as this node's
## siblings, exactly mirroring that scene's own shape).
##
## Construction order note: ik_chain_controller.gd's `target` and limb_
## prototype_foot_target.gd's `ik_chain` are a genuine MUTUAL reference -
## each needs the other to already exist as a node before its own _ready()
## runs (this is normally resolved for free by ordinary scene loading,
## which assembles the whole tree before firing any _ready() calls - pure
## runtime add_child() has no such grace period, each call fires _ready()
## immediately). Resolved here by giving ik_chain a harmless temporary
## target (its own parent anchor, which already has a real global_position)
## just long enough to get IT attached and real, THEN building the real
## FootTarget (which finds the now-real ik_chain immediately, no trick
## needed on that side), THEN fixing up ik_chain.target directly (a plain
## var, not read-only) before anything ever actually reads it - FootTarget's
## own deferred _seed_spawn_pose (which calls ik_chain.solve_fabrik()) only
## fires at end-of-frame, well after this synchronous fix-up.

const BASE_TOTAL_REACH := 7.5
const BASE_BODY_HEIGHT := 4.5
const BASE_ANCHOR_FORWARD := 1.8
const BASE_ANCHOR_LATERAL := 0.5
const BASE_ANCHOR_DROP := 0.5
const BASE_FOOT_HEIGHT := 0.15 * BASE_TOTAL_REACH

## hop removed for now (per explicit request) - keeps the gait picture
## simple while the basics (belt speed, tether, per-gait pace) are still
## being worked out. gait_controller.gd's own "hop" preset is untouched -
## other scenes may still use it - this file just never selects it.
const FOUR_LEG_GAITS := ["walk", "trot", "canter_right", "canter_left"]
const GENERAL_GAITS := ["walk"] # The only one that generalizes cleanly to an arbitrary even limb count now that hop is out.

const _IK_CHAIN_SCRIPT := preload("res://scripts/ik_chain_controller.gd")
const _FOOT_TARGET_SCRIPT := preload("res://scripts/limb_prototype_foot_target.gd")
const _FOOT_SEGMENT_SCRIPT := preload("res://scripts/limb_prototype_foot_segment.gd")
const _GAIT_CONTROLLER_SCRIPT := preload("res://scripts/gait_controller.gd")
const _HIP_SUSPENSION_SCRIPT := preload("res://scripts/hip_suspension_solver.gd")

## Read directly by gait_controller.gd every frame to scale period_sec
## relative to reference_speed - deliberately left FIXED at 2.0 forever
## (never touched by _apply_gait()), matching every FOUR_LEG_GAITS
## preset's own reference_speed, so period_sec always equals that
## preset's own already-tuned reference_period_sec exactly. An earlier
## version reused this SAME field as the belt scroll rate too (see
## GAIT_BELT_SPEEDS' own comment for why that measured out to be actively
## counterproductive) - kept as a plain, never-reassigned field instead of
## a const only because gait_controller.gd's own @onready body reference
## expects an ordinary instance property to read.
var speed: float = 2.0

## Per-gait treadmill belt speed (world units/sec, see limb_prototype_
## foot_target.gd's own belt_speed) - halt isn't listed since halted
## freezes movement outright (see _physics_process) regardless of
## whatever current_gait was last set to.
##
## Deliberately INDEPENDENT of body.speed/gait_controller.gd's cadence
## scaling (see that field's own comment for the measured reason this
## used to be a shared field and why that broke) - each preset's own
## reference_period_sec now stays fixed at reference, so PLANTED stance
## duration per cycle is simply reference_period_sec minus gait_
## controller.gd's own FIXED_STEP_DURATION_SEC (0.5): walk ~3.5s, trot
## ~0.7s, canter ~1.7s. Values below were picked to land each gait's own
## peak reach comfortably mid-range (not hugging reach_release_fraction's
## 0.97) - confirmed directly via _verify_motion_lab_lean_diagnosis_
## runner.gd's real per-leg reach trace, not derived from the stance-
## duration arithmetic alone (that arithmetic is only an approximation -
## real stance duration also depends on each leg's own phase_offset
## relative to when a gait was selected).
const GAIT_BELT_SPEEDS := {
	"walk": 1.2,
	"trot": 1.8,
	"canter_right": 2.4,
	"canter_left": 2.4,
}

## Loose horizontal tether - a plain damped spring pulling position.x back
## toward _spawn_x, with no separate forcing term (nothing else pushes the
## body away from spawn_x anymore now that walking is expressed via belt
## scroll on the feet, not real body translation - see this file's own
## header). Not a hard lock: a real disturbance (a future stride-impulse
## mechanic, say) could still nudge the body and have it settle back
## smoothly, exactly what a real tether does. Damping = 2*sqrt(stiffness)
## for critical damping - settles in ~1/sqrt(stiffness) seconds with no
## overshoot wobble.
const TETHER_STIFFNESS := 4.0
const TETHER_DAMPING := 4.0
var _tether_velocity_x: float = 0.0

var _spawn_x: float = 0.0
var _breathing_time: float = 0.0
const BREATHING_AMPLITUDE := 0.08
const BREATHING_PERIOD_SEC := 3.0

var body_scale: float = 1.0
var limb_count: int = 4
var segment_count: int = 3
var current_gait: String = "walk"
## Starts halted (idle, no gait yet applied to any actual leg motion) so
## the lab spawns calm rather than immediately walking - the player picks
## a gait explicitly. Toggled by motion_lab_controller.gd's own KEY_0,
## same convention as gait_controller.gd's own halt key elsewhere in this
## project; read directly by gait_controller.gd's _physics_process every
## frame (frozen phase_progress, so no NEW swing starts, but a leg already
## mid LIFTING/SWINGING finishes normally - unchanged from that file's own
## halt semantics).
var halted: bool = true

var _leg_anchors: Array[Node4D] = []
var _foot_targets: Array[Node4D] = []
var _gait_controller: Node = null
var _hip_suspension_solver: Node = null
var _body_mesh: MeshInstance4D


func _ready() -> void:
	process_physics_priority = -1
	_spawn_x = position.x
	_body_mesh = MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(4.0, 1.0, 1.2, 1.2)
	_body_mesh.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = Color(0.9, 0.2, 0.6, 1)
	_body_mesh.material_override = material
	add_child(_body_mesh)
	# Deferred, not called directly - this _ready() itself runs DURING the
	# scene's own initial child-setup cascade (Body is one of the children
	# MotionLabCreature is still in the middle of readying), and root.
	# add_child() (called from _build_rig(), for GaitController/FootTarget*)
	# refuses to run synchronously in that window ("Parent node is busy
	# setting up children" - confirmed directly, not guessed at). Every
	# LATER rebuild (triggered from a key handler, well after the scene has
	# finished loading) has no such restriction and calls rebuild()
	# directly - only this first, load-time call needs deferring.
	rebuild.call_deferred()


func _physics_process(delta: float) -> void:
	if halted:
		# Idle rest pose - no locomotion, but not a frozen statue either: a
		# small breathing bob on the body MESH only (never Body's own
		# position, which hip_suspension_solver.gd owns continuously) so
		# halt reads as a living idle animation.
		_breathing_time += delta
		_body_mesh.position.y = BREATHING_AMPLITUDE * sin(_breathing_time * TAU / BREATHING_PERIOD_SEC)
		return
	_body_mesh.position.y = 0.0

	# Pure restoring spring, no forcing term - see TETHER_STIFFNESS' own
	# comment for why. Belt scroll (limb_prototype_foot_target.gd's own
	# belt_speed) is what actually produces the walking illusion; this
	# only keeps the body from drifting away from spawn on its own.
	var offset: float = position.x - _spawn_x
	var accel: float = -TETHER_STIFFNESS * offset - TETHER_DAMPING * _tether_velocity_x
	_tether_velocity_x += accel * delta
	position.x += _tether_velocity_x * delta


## Read by limb_prototype_foot_target.gd's own _compute_live_target (the
## forward-lead probe) and ik_chain_controller.gd's _hinge_forward/plane-
## alignment-twist - always local +X now that motion is one-directional
## (see this file's own header for the two earlier, rejected approaches).
func get_travel_direction() -> Vector4:
	return Vector4(1, 0, 0, 0)


## Called by motion_lab_controller.gd's key handlers - each setter clamps
## then does a full teardown+rebuild. One code path for every parameter
## change (rather than a cheaper in-place rescale for body_scale alone) -
## a brief rebuild flicker is a non-issue for a dev inspection tool, and
## it keeps this file simple.
func set_body_scale(new_scale: float) -> void:
	body_scale = clampf(new_scale, 0.4, 3.0)
	rebuild()


func set_limb_count(delta: int) -> void:
	limb_count = clampi(limb_count + delta * 2, 2, 8) # Even only, ± one pair at a time.
	var valid_gaits: Array = FOUR_LEG_GAITS if limb_count == 4 else GENERAL_GAITS
	if current_gait not in valid_gaits:
		current_gait = "walk" # Always valid in both sets - avoids silently mislabeling a 4-leg-only gait's name once it's re-interpreted as the generalized walk shape below.
	rebuild()


func set_segment_count(delta: int) -> void:
	segment_count = clampi(segment_count + delta, 1, 5)
	rebuild()


## Direct gait selection (motion_lab_controller.gd's own KEY_1/2/4/5, the
## same digit-to-gait convention as gait_controller.gd's own standalone
## input elsewhere in this project - KEY_3/hop is currently unbound, see
## FOUR_LEG_GAITS' own comment). trot/canter_right/canter_left are
## silently ignored outside exactly limb_count == 4 - see FOUR_LEG_GAITS/
## GENERAL_GAITS's own comment for why those three don't generalize to an
## arbitrary even limb count without inventing new diagonal-pair semantics
## this file has no real basis for.
func select_gait(gait_name: String) -> void:
	var valid_gaits: Array = FOUR_LEG_GAITS if limb_count == 4 else GENERAL_GAITS
	if gait_name not in valid_gaits:
		return
	# Re-selecting the ALREADY-active gait (pressing its key again while
	# already walking, an entirely normal thing to do while testing) used
	# to still reset phase_progress to 0.0 below, forcing the exact same
	# "one leg's own offset already sits past duty_factor at phase 0"
	# early-fire this function's own next comment describes - previously
	# a harmless single-leg twitch, but confirmed directly (_verify_
	# reselect_transient_runner.gd) that today's load_factor-weighted hip
	# suspension turns that same early-fire into a real, visible ~2s body
	# tilt wobble: that leg's load_factor SNAPS to 0 (correctly - it IS
	# now genuinely airborne) instead of easing down, so hip suspension
	# loses its whole contribution in one frame rather than gradually.
	# Nothing about re-selecting the SAME gait should change anything at
	# all, so just don't - this is the actual fix (upstream of load_
	# factor entirely), not a load_factor-specific patch.
	if gait_name == current_gait and not halted:
		return
	current_gait = gait_name
	_apply_gait()
	# Picking a gait means "show me this gait" - halted (the spawn default,
	# and whatever KEY_0 last left it at) would otherwise freeze
	# phase_progress at the 0.0 _apply_gait() just reset it to, and every
	# leg whose own phase_offset already sits past duty_factor at phase 0
	# fires its phase gate exactly once (a single real edge crossing, not a
	# bug) before the frozen phase can ever cross again - reads as "one or
	# two limbs twitch once, then nothing," confirmed directly against the
	# live scene, not guessed at. KEY_0 stays the only way to re-halt.
	halted = false


## Swing timing was a FIXED 0.5s (lift_duration_sec 0.15 + swing_duration_
## sec 0.35, limb_prototype_foot_target.gd's own defaults) regardless of
## gait - fine for the gallery's roaming creatures (that's their own
## already-tuned, verified value), but on this treadmill it meant walk's
## 4.0s cycle spent just 0.5/4.0 = 12.5% of it airborne per leg, vastly
## less than duty_factor's own nominal 40% swing-eligible window - reads
## as "legs glued to the floor," confirmed as the actual, measurable
## cause (not guessed) of a reported "legs barely lift" symptom.
##
## First attempt scaled swing time off the DUTY-FACTOR eligible window
## ((1-duty_factor)*period_sec) - measured directly (_verify_motion_lab_
## swing_scale_runner.gd) to be WRONG: that window only bounds when ONE
## leg's OWN gate can fire, not whether its resulting swing overlaps a
## DIFFERENT leg's swing. Canter measured all 4 legs airborne
## simultaneously at that setting - a real, serious regression, not a
## cosmetic one. The actual constraint is the same one gait_controller.gd
## already computes its own valid_speed_ceiling from: two DIFFERENT legs'
## gate crossings are min_phase_spacing*period_sec apart in time, so
## total swing time must stay safely under THAT gap, not the eligible
## window. Reusing that exact formula (same 30% margin, GaitController's
## own compute_min_phase_spacing) rather than inventing a new one.
##
## Consequence, confirmed by direct recomputation: walk's spacing (0.25)
## leaves real room to grow past the old fixed 0.5s; trot's (0.5) and
## canter's (0.3) do not - both work out to a safe ceiling AT OR BELOW
## the original 0.5s once period_sec is factored in, meaning those two
## presets were already running close to their real timing limit even
## before any of this - not a regression this file introduced, just not
## something this fix can safely improve further. HEADROOM_FRACTION
## stays under the bare theoretical ceiling for real per-frame timing
## jitter, not just the idealized formula.
const SWING_SAFETY_MARGIN_FRACTION := 0.30 # Matches gait_controller.gd's own SAFETY_MARGIN_FRACTION.
const SWING_HEADROOM_FRACTION := 0.85
const LIFT_FRACTION_OF_SWING := 0.3


func _apply_gait() -> void:
	var belt_speed: float = GAIT_BELT_SPEEDS.get(current_gait, GAIT_BELT_SPEEDS["walk"])
	for foot_target in _foot_targets:
		foot_target.belt_speed = belt_speed
	if _gait_controller == null:
		return
	if limb_count == 4 and current_gait in FOUR_LEG_GAITS:
		_gait_controller.apply_preset(current_gait)
	else:
		# Generalized case (limb_count != 4) - GENERAL_GAITS only has
		# "walk" in it now that hop is out, so this is always the walk
		# shape: evenly spaced phase offsets around the cycle.
		var offsets: Array = []
		for i in range(limb_count):
			offsets.append(float(i) / float(limb_count))
		_gait_controller.duty_factor = 0.6
		_gait_controller.phase_offsets = offsets
		_gait_controller.reference_speed = 2.0
		_gait_controller.reference_period_sec = 4.0
		_gait_controller.period_sec = 4.0
		_gait_controller.phase_progress = 0.0
		_gait_controller.preset = current_gait

	var min_phase_spacing: float = _GAIT_CONTROLLER_SCRIPT.compute_min_phase_spacing(_gait_controller.phase_offsets)
	var safe_swing_ceiling: float = min_phase_spacing * _gait_controller.reference_period_sec / (1.0 + SWING_SAFETY_MARGIN_FRACTION)
	var total_swing_time: float = safe_swing_ceiling * SWING_HEADROOM_FRACTION
	var lift_time: float = total_swing_time * LIFT_FRACTION_OF_SWING
	var swing_time: float = total_swing_time * (1.0 - LIFT_FRACTION_OF_SWING)
	for foot_target in _foot_targets:
		foot_target.lift_duration_sec = lift_time
		foot_target.swing_duration_sec = swing_time


func rebuild() -> void:
	_teardown_rig()
	_build_rig()


## Immediate .free() (NOT queue_free()) - _build_rig() runs synchronously
## right after this, reusing the exact same node NAMES ("GaitController",
## "FootTarget0", ...) that every hand-built NodePath in this file assumes
## resolve correctly. queue_free()'s normal end-of-frame deferral was tried
## first and measured to break exactly that: the new same-named nodes get
## silently auto-renamed ("GaitController2") to avoid colliding with the
## still-alive-until-end-of-frame old ones, and any OLD leg node still
## processing this same frame holds a now-stale reference into the
## already-torn-down old rig. Safe here specifically because rebuild() is
## always called from OUTSIDE any of these nodes' own callbacks (a key
## handler or this node's own _ready()), never from within a leg/
## GaitController/FootTarget's own signal or process callback.
func _teardown_rig() -> void:
	for anchor in _leg_anchors:
		anchor.free()
	_leg_anchors.clear()
	for foot_target in _foot_targets:
		foot_target.free()
	_foot_targets.clear()
	if _gait_controller != null:
		_gait_controller.free()
		_gait_controller = null
	if _hip_suspension_solver != null:
		_hip_suspension_solver.free()
		_hip_suspension_solver = null


func _build_rig() -> void:
	var mesh: BoxTetraMesh4D = _body_mesh.mesh
	mesh.size = Vector4(4.0, 1.0, 1.2, 1.2) * body_scale

	var total_reach: float = BASE_TOTAL_REACH * body_scale
	# hip_suspension_solver.gd's own resting_extension_fraction (0.8) - see
	# that export's own comment (A/B-screenshot evidence the old ~0.53
	# ratio left too much slack). Unlike limb_prototype_body.gd's hopper
	# class, this rig's legs are always uniform (no front/back asymmetry),
	# so there's no per-class reason to hold this back - confirmed directly
	# via _verify_motion_lab_reach_check_runner.gd (0 reach-backstop fires
	# in a real 10s walk-gait window at this ratio).
	var standing_utilization_ratio: float = 0.8
	# +BASE_FOOT_HEIGHT*body_scale - see the identical fix/comment in
	# limb_prototype_body.gd's own _apply_creature_class(). Only the
	# spawn-frame seed now that hip_suspension_solver.gd owns position.y
	# continuously afterward, but matching it avoids a visible one-time pop.
	position.y = BASE_ANCHOR_DROP * body_scale + BASE_FOOT_HEIGHT * body_scale + standing_utilization_ratio * total_reach

	var root: Node = get_parent()
	_gait_controller = Node.new()
	_gait_controller.name = "GaitController"
	_gait_controller.set_script(_GAIT_CONTROLLER_SCRIPT)
	_gait_controller.body_path = NodePath("../Body")
	_gait_controller.standalone_input = false
	root.add_child(_gait_controller)

	var segment_length: float = total_reach / segment_count
	var pair_count: int = limb_count / 2
	var foot_height: float = BASE_FOOT_HEIGHT * body_scale

	# pair_index=0 must be the FRONTMOST pair (forward_pos highest) so
	# resulting leg_index order is FL,FR,BL,BR,... - matching gait_
	# controller.gd's own documented convention ("Leg order (index 0-3) is
	# FL, FR, BL, BR") that its PRESETS' phase_offsets are written against.
	# Confirmed this was backwards before (lerp(-FORWARD,FORWARD,...) put
	# pair_index=0 at the BACK instead) via a direct leg-index-to-position
	# trace, not assumed. Turned out to be phase-structure-preserving for
	# every currently-used preset (walk/trot/canter's own overlap pattern
	# is unchanged by which physical leg holds which offset value - it's a
	# relabeling, not a real timing bug) but still worth fixing: it silently
	# swaps which diagonal leads for trot/canter, and would be a REAL bug
	# for any future front/back-asymmetric leg class (this rig's own
	# uniform legs happen to hide it).
	for pair_index in range(pair_count):
		var forward_pos: float = 0.0
		if pair_count > 1:
			forward_pos = lerp(BASE_ANCHOR_FORWARD, -BASE_ANCHOR_FORWARD, float(pair_index) / float(pair_count - 1)) * body_scale
		for side in range(2): # 0 = left, 1 = right.
			_build_leg(pair_index * 2 + side, forward_pos, 1.0 if side == 0 else -1.0, segment_length, foot_height, root)

	# Built LAST, after every leg's own FootTarget already exists for real -
	# hip_suspension_solver.gd's @onready reads (body + each foot target)
	# need those nodes to already be attached, same requirement every other
	# cross-reference in this file already has to satisfy.
	_hip_suspension_solver = Node.new()
	_hip_suspension_solver.name = "HipSuspensionSolver"
	_hip_suspension_solver.set_script(_HIP_SUSPENSION_SCRIPT)
	_hip_suspension_solver.body_path = NodePath("../Body")
	var leg_paths: Array[NodePath] = []
	for i in range(limb_count):
		leg_paths.append(NodePath("../FootTarget%d" % i))
	_hip_suspension_solver.leg_foot_target_paths = leg_paths
	# Opt-in explicitly - hip_suspension_solver.gd's own reach_response_
	# weight defaults to 0.0 precisely because it's unsafe for the
	# gallery's real-wandering creatures that share this same script
	# (confirmed: 28-64 degree max tilt at 0.4 there). This scene's
	# tethered, belt-driven setup was separately confirmed safe with it
	# on - see that field's own comment.
	#
	# 0.4 measured a real ~2.3 degree peak tilt when hip_suspension_
	# solver.gd's regression still hard-filtered by PLANTED state.
	# Re-measured at ~4.5 degrees (roughly double) after that regression
	# switched to weighting by load_factor instead - the SAME reach
	# asymmetry now gets picked up continuously through each leg's own
	# settle/shed ramp, not just at the instant, so the same weight
	# produces more visible net tilt. Dialed back to keep the peak closer
	# to the originally-tuned range - load_factor's own smooth weight-
	# transfer benefit is independent of this value, so this only trims
	# how strongly reach asymmetry itself drives tilt, not whether the
	# transfer between legs stays smooth.
	_hip_suspension_solver.reach_response_weight = 0.25
	root.add_child(_hip_suspension_solver)

	_apply_gait()


func _build_leg(leg_index: int, forward_pos: float, lateral_sign: float, segment_length: float, foot_height: float, root: Node) -> void:
	var anchor := Node4D.new()
	anchor.name = "LegAnchor%d" % leg_index
	anchor.position = Vector4(forward_pos, -BASE_ANCHOR_DROP * body_scale, lateral_sign * BASE_ANCHOR_LATERAL * body_scale, 0.0)
	add_child(anchor)
	_leg_anchors.append(anchor)

	var ik_chain := Node4D.new()
	ik_chain.name = "IKChain"
	ik_chain.set_script(_IK_CHAIN_SCRIPT)

	var joint_paths: Array[NodePath] = []
	var link_lengths: Array[float] = []
	var prev_joint: Node4D = ik_chain
	var path_str: String = ""
	var last_joint: Node4D = null
	for seg in range(segment_count):
		var joint := Node4D.new()
		joint.name = "Joint%d" % (seg + 1)
		if seg > 0:
			joint.position = Vector4(0, segment_length, 0, 0)
		prev_joint.add_child(joint)
		path_str = "Joint%d" % (seg + 1) if seg == 0 else "%s/Joint%d" % [path_str, seg + 1]
		joint_paths.append(NodePath(path_str))
		link_lengths.append(segment_length)

		var ext_mesh := MeshInstance4D.new()
		ext_mesh.position = Vector4(0, segment_length * 0.5, 0, 0)
		var seg_mesh := OrthoplexTetraMesh4D.new()
		var thickness: float = segment_length * 0.4
		seg_mesh.size = Vector4(thickness, segment_length, thickness, thickness)
		ext_mesh.mesh = seg_mesh
		var seg_material := TetraMaterial4D.new()
		seg_material.albedo_color = Color.from_hsv(float(seg) / float(segment_count), 0.6, 0.85)
		ext_mesh.material_override = seg_material
		joint.add_child(ext_mesh)

		last_joint = joint
		prev_joint = joint

	ik_chain.joint_paths = joint_paths
	ik_chain.link_lengths = link_lengths
	ik_chain.forward_direction_provider = NodePath("../..") # anchor -> Body (this node).
	ik_chain.enable_plane_alignment_twist = true
	# Temporary, harmless target - anchor is already real/attached and has
	# a real global_position, which is all this one-time @onready read
	# needs; fixed up to the real FootTarget right after it's built below.
	ik_chain.target_path = NodePath("..")
	anchor.add_child(ik_chain)

	var foot_target := Node4D.new()
	foot_target.name = "FootTarget%d" % leg_index
	foot_target.set_script(_FOOT_TARGET_SCRIPT)
	foot_target.body_path = NodePath("../Body")
	foot_target.anchor_path = NodePath("../Body/%s" % anchor.name)
	foot_target.ik_chain_path = NodePath("../Body/%s/IKChain" % anchor.name)
	foot_target.gait_controller_path = NodePath("../GaitController")
	foot_target.leg_index = leg_index
	foot_target.reach_release_fraction = 0.97
	foot_target.foot_height = foot_height
	# belt_speed gets its real value from _apply_gait() (called at the end
	# of _build_rig(), once every leg - and therefore _foot_targets - is
	# built) rather than here - see that export's own comment for why it's
	# a separate field from body.speed.
	root.add_child(foot_target)
	_foot_targets.append(foot_target)

	# Fix up the mutual reference now that both sides are real - see this
	# file's own header comment for why this is needed at all.
	ik_chain.target = foot_target
	ik_chain.target_path = NodePath("../../../%s" % foot_target.name)

	var foot := Node4D.new()
	foot.name = "Foot"
	foot.set_script(_FOOT_SEGMENT_SCRIPT)
	foot.position = Vector4(0, segment_length, 0, 0)
	foot.rest_length = foot_height
	var up_count: int = segment_count + 4 # Foot -> JointM -> ... -> Joint1 -> IKChain -> anchor -> Body -> root.
	foot.foot_target_path = NodePath("../".repeat(up_count) + foot_target.name)
	last_joint.add_child(foot)

	var foot_mesh := MeshInstance4D.new()
	foot_mesh.position = Vector4(0, foot_height * 0.5, 0, 0)
	var foot_shape := OrthoplexTetraMesh4D.new()
	foot_shape.size = Vector4(foot_height * 0.6, foot_height, foot_height * 0.6, foot_height * 0.6)
	foot_mesh.mesh = foot_shape
	var foot_material := TetraMaterial4D.new()
	foot_material.albedo_color = Color(0.15, 0.1, 0.08, 1)
	foot_mesh.material_override = foot_material
	foot.add_child(foot_mesh)
