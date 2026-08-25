extends Node4D
## Ground-responsive "foot" segment (hoof/pastern) - the final bit of leg
## beyond the FABRIK-solved chain (e.g. femur/tibia/cannon). Deliberately
## NOT in ik_chain_controller.gd's joint_paths, so its solve never touches
## this node - its POSITION tracks the chain's last joint for free via
## ordinary forward kinematics (this node is parented to that last joint,
## e.g. Joint3, at that joint's own tip - the same convention
## ExtensionMesh3 already uses for its own mesh); only its ORIENTATION is
## independently driven here, every physics frame, from foot_target's own
## FootState:
##
##   PLANTED  - point at the real ground-contact point
##              (foot_target.locked_ground_point), slope-aware via that
##              raycast's own normal, held fixed while planted (matching
##              FootTarget's own "frozen while planted" convention - no
##              per-frame jitter from a live raycast).
##   LIFTING  - blend from the held planted direction toward a neutral
##              "continue the leg's own line" default (the parent joint's
##              own global_basis.y), plus a brief decaying wobble right at
##              the start - the "overshoot spring" immediately after
##              leaving the ground.
##   SWINGING - hold the neutral direction until the last
##              ground_prediction_fraction of the swing, then blend toward
##              pointing at the KNOWN landing spot
##              (foot_target.swing_target_ground_point) - "ground
##              prediction," reaching the foot toward the ground ahead of
##              actually arriving there.
##
## Direction blending uses plain lerp+normalize (not true slerp - Vector4
## has no slerp() in this engine), acceptable for these fairly small-angle
## blends; the actual per-frame ROTATION toward that blended direction
## reuses the same shortest-arc rotor snap already established in
## ik_chain_controller.gd's _snap_joint_toward/_rotor_from_to (duplicated
## here, not shared - see that file's own header for why this codebase
## keeps per-file copies of this small helper rather than factoring it out).

@export var foot_target_path: NodePath
@export var rest_length: float = 0.5 ## Visual only - the child mesh's own length, set per-class.

## "Overshoot spring" right after lift-off - a brief, decaying wobble
## nudged into the blended direction. Placeholder-tuned (this whole
## feature is explicitly a stylistic flourish, not measured against any
## real reference), not derived from anything.
@export var spring_duration_sec: float = 0.12
@export var spring_magnitude_deg: float = 20.0
@export var spring_frequency: float = 18.0 # rad/sec.
@export var spring_decay_tau: float = 0.04

## The last fraction of swing_duration_sec during which the foot blends
## toward the known landing spot instead of holding neutral.
@export var ground_prediction_fraction: float = 0.3

const DEGENERATE_LENGTH_EPSILON := 0.0001
const SNAP_ANGLE_EPSILON := 0.0000001

@onready var foot_target: Node = get_node(foot_target_path)

var _prev_state: int = -1
## Captured once at the PLANTED->LIFTING edge (whatever this node's own
## global_basis.y already was, which by continuity is the direction it was
## just holding while planted) - NOT re-read every frame, so the LIFTING
## blend has a fixed start point to ease away from.
var _lift_start_dir: Vector4 = Vector4(0, -1, 0, 0)


## After ik_chain_controller.gd's own priority (1) - reads this frame's
## fully resolved FootTarget state (which itself runs after this frame's
## Body/GaitController updates), not a frame-stale one. Same reasoning as
## that file's own _ready(), applied one link further down the chain.
func _ready() -> void:
	process_physics_priority = 2


func _physics_process(_delta: float) -> void:
	var state: int = foot_target.state
	if state != _prev_state and state == foot_target.FootState.LIFTING:
		_lift_start_dir = global_basis.y
	_prev_state = state

	_snap_toward(_compute_desired_dir(state))


func _compute_desired_dir(state: int) -> Vector4:
	var parent_joint: Node4D = get_parent()

	if state == foot_target.FootState.PLANTED:
		return _safe_normalized(foot_target.locked_ground_point - global_position, Vector4(0, -1, 0, 0))

	if state == foot_target.FootState.LIFTING:
		var neutral_dir: Vector4 = parent_joint.global_basis.y
		var t: float = foot_target.state_elapsed_sec
		var blend: float = clampf(t / foot_target.lift_duration_sec, 0.0, 1.0)
		var base_dir: Vector4 = _blend_dir(_lift_start_dir, neutral_dir, blend)
		if t < spring_duration_sec:
			var wobble: float = deg_to_rad(spring_magnitude_deg) * exp(-t / spring_decay_tau) * sin(t * spring_frequency)
			return _safe_normalized(base_dir + Vector4(0, 0, wobble, 0), base_dir)
		return base_dir

	if state == foot_target.FootState.SWINGING:
		var neutral_dir: Vector4 = parent_joint.global_basis.y
		var t: float = foot_target.state_elapsed_sec / foot_target.swing_duration_sec
		var predict_start: float = 1.0 - ground_prediction_fraction
		if t < predict_start:
			return neutral_dir
		var blend: float = clampf((t - predict_start) / ground_prediction_fraction, 0.0, 1.0)
		var landing_dir: Vector4 = _safe_normalized(foot_target.swing_target_ground_point - global_position, neutral_dir)
		return _blend_dir(neutral_dir, landing_dir, blend)

	return global_basis.y


func _safe_normalized(v: Vector4, fallback: Vector4) -> Vector4:
	return v.normalized() if v.length() > DEGENERATE_LENGTH_EPSILON else fallback


func _blend_dir(a: Vector4, b: Vector4, t: float) -> Vector4:
	return _safe_normalized(a.lerp(b, t), b)


func _snap_toward(desired_dir: Vector4) -> void:
	var current_dir: Vector4 = global_basis.y
	if current_dir.dot(desired_dir) >= 1.0 - SNAP_ANGLE_EPSILON:
		return
	var rotor: Rotor4D = _rotor_from_to(current_dir, desired_dir)
	if rotor != null:
		global_basis = rotor.rotate_basis(global_basis)


## Same bisector construction duplicated in ik_chain_controller.gd and
## w_targeting.gd - see either file's own header for the full derivation.
func _rotor_from_to(from_dir: Vector4, to_dir: Vector4) -> Rotor4D:
	var bisector: Vector4 = from_dir + to_dir
	if bisector.length() < 0.0001:
		var arbitrary_axis := Vector4(1, 0, 0, 0)
		if absf(from_dir.dot(arbitrary_axis)) > 0.9:
			arbitrary_axis = Vector4(0, 0, 1, 0)
		var perp: Vector4 = (arbitrary_axis - from_dir * from_dir.dot(arbitrary_axis)).normalized()
		return Rotor4D.vector_product(from_dir, perp).normalized()
	return Rotor4D.vector_product(from_dir, bisector.normalized()).normalized()
