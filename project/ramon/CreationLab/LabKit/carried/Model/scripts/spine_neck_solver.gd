# CARRIED OVER from res://ramon/Model/scripts/spine_neck_solver.gd on 4 Oct 2026, so the lab owns this copy: the original can change without breaking the lab, and the other way round (LabKit/carried/README.md).
extends Node
## Spine flex, and a neck that holds the head roughly still while the shoulders bob.
##
## These are steps 5 and 6 of PROCEDURAL_CREATURE_ANIMATION_SYSTEM.md's processing
## stack - "spine IK chain, applies gait-phase-driven flex" and "neck/head IK chain,
## applies lag/damping plus counter-rotation (gaze stabilization)". Kept in one script
## because the neck's correction depends on where the spine flex just put the shoulders,
## and running them in sequence in one pass is the simplest way to guarantee that.
##
## ORDER IS THE WHOLE TRICK: priority 0 puts this AFTER the gait driver at -1, which has
## already bobbed the body and placed the foot targets, and BEFORE the leg chains at 1.
## That matters in both directions. The neck has to read shoulders that have finished
## moving, and the legs have to solve against hips this script has finished rotating -
## flexing the spine after the legs solved would drag every planted foot off its target.
##
## The doc calls hip suspension "explicitly one-frame-delayed against limb state" to keep
## the tick acyclic. Nothing here needs that: the spine is driven by the gait clock
## rather than by limb reach, so it reads no output of its own.

@export var creature_path: NodePath = NodePath("../Creature")

## The gait driver, for its phase. Flex is locked to the footfall cycle rather than run
## on its own clock: a back that arches out of step with the legs reads as a limp.
@export var gait_driver_path: NodePath = NodePath("../IKGaitDriver")

## Peak arch at each spine joint. Small by design - a walking quadruped's back barely
## moves, and overdoing it looks like a cat stretching.
@export_range(0.0, 20.0, 0.5, "suffix:°") var spine_flex_degrees: float = 3.5

## Chest and rump counter-rotate, so the back arches and flattens rather than the whole
## body pitching. Off, they pitch together and the flex disappears into the body bob.
@export var counter_rotate_rump: bool = true

## How much of the shoulder bob the neck cancels. 1.0 holds the head dead still, which
## looks uncannily mechanical; a little residual movement is what reads as alive.
@export_range(0.0, 1.0, 0.05) var head_stabilisation: float = 0.85

## Per-frame fraction of the remaining correction the neck takes up. Below 1 it lags
## behind the bob, which is the damping the design doc asks for - and a real neck lags.
@export_range(0.05, 1.0, 0.05) var neck_follow_rate: float = 0.45

## Ceiling on the total correction, so a big disturbance cannot fold the neck over.
@export_range(1.0, 60.0, 1.0, "suffix:°") var neck_limit_degrees: float = 25.0

@export var show_label: bool = true

## Multiplied into the spine flex. idle_layer.gd drops this toward 0 while halted: the
## gait clock freezes when the creature stops, and a frozen clock would otherwise leave
## the back stuck at whatever arch it held mid-stride.
var flex_scale: float = 1.0

## A world direction head_attention.gd wants the neck to lean toward, and how much of
## the way to lean. Applied AFTER stabilisation, so the two compose rather than fight:
## stabilisation holds the head's height, this swings it round to look at something.
## Zero weight leaves the neck exactly as it was.
var aim_direction: Vector4 = Vector4.ZERO
var aim_weight: float = 0.0

var _gait: Node = null
var _chest: Node4D = null
var _rump: Node4D = null
var _neck: Array[Node4D] = []
var _head: Node4D = null
var _chest_rest: Projection = Projection.IDENTITY
var _rump_rest: Projection = Projection.IDENTITY
var _head_rest_y: float = 0.0
var _label: Label = null
var _worst_error: float = 0.0


func _ready() -> void:
	# Between the gait driver (-1) and the leg chains (1). See the note above.
	process_physics_priority = 0
	var creature: Node4D = get_node_or_null(creature_path) as Node4D
	if creature == null:
		push_warning("SpineNeckSolver: creature_path does not resolve.")
		set_physics_process(false)
		return
	_gait = get_node_or_null(gait_driver_path)
	_chest = creature.get_node_or_null("Barrel/Chest") as Node4D
	_rump = creature.get_node_or_null("Barrel/Rump") as Node4D
	for path in ["Barrel/Chest/Neck1", "Barrel/Chest/Neck1/Neck2"]:
		var segment: Node4D = creature.get_node_or_null(path) as Node4D
		if segment != null:
			_neck.append(segment)
	_head = creature.get_node_or_null("Barrel/Chest/Neck1/Neck2/Head") as Node4D
	if _chest == null or _head == null or _neck.is_empty():
		push_warning("SpineNeckSolver: expected Barrel/Chest/Neck1/Neck2/Head under the creature.")
		set_physics_process(false)
		return
	_chest_rest = _chest.basis
	if _rump != null:
		_rump_rest = _rump.basis
	# Captured before anything has moved, so it is the height the head should hold.
	_head_rest_y = _head.global_position.y
	if show_label:
		var layer := CanvasLayer.new()
		add_child(layer)
		_label = Label.new()
		_label.position = Vector2(14, 88)
		_label.add_theme_font_size_override("font_size", 17)
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		layer.add_child(_label)


func _physics_process(_delta: float) -> void:
	_flex_spine()
	_stabilise_head()
	if _label != null:
		var error: float = absf(_head.global_position.y - _head_rest_y)
		_worst_error = maxf(_worst_error, error)
		_label.text = "spine flex %.1f deg   head height error %.3f (worst %.3f)" % [
			spine_flex_degrees, error, _worst_error]


## Arch at twice the gait frequency - once per diagonal pair, the same rate the body
## bobs at, because both are driven by the same pair of legs pushing off.
func _flex_spine() -> void:
	var phase: float = float(_gait.phase) if _gait != null and "phase" in _gait else 0.0
	var flex: float = deg_to_rad(spine_flex_degrees * flex_scale) * sin(phase * TAU * 2.0)
	# XY is the pitch plane for a body lying along X, so this arches the back rather
	# than swinging it sideways.
	_chest.basis = _chest_rest * Basis4D.from_xy(flex)
	if _rump != null:
		_rump.basis = _rump_rest * Basis4D.from_xy(-flex if counter_rotate_rump else flex)


## Rotates the neck so the head returns toward the height it started at.
##
## A CCD SWEEP RATHER THAN A CHOSEN ROTATION PLANE: aiming each joint so the head moves
## toward its target needs no decision about which plane to bend in, which matters in 4D
## where a rotation has no axis to pick. It also generalises for free - add a third neck
## segment and it participates without changing anything here.
##
## Only the HEIGHT is corrected. Pinning the head's full position would fight the
## creature's forward travel and the spine flex both, and a real animal stabilises its
## gaze vertically while letting it ride along horizontally.
func _stabilise_head() -> void:
	_apply_neck_aim()
	for joint in _neck:
		var joint_pos: Vector4 = joint.global_position
		var head_pos: Vector4 = _head.global_position
		var corrected_y: float = lerpf(head_pos.y, _head_rest_y, head_stabilisation)
		var desired_head := Vector4(head_pos.x, corrected_y, head_pos.z, head_pos.w)
		var current_dir: Vector4 = head_pos - joint_pos
		var desired_dir: Vector4 = desired_head - joint_pos
		if current_dir.length() < 0.0001 or desired_dir.length() < 0.0001:
			continue
		# Take only part of the correction each frame: that is the lag, and it is why
		# the head eases rather than snapping to height.
		desired_dir = current_dir.normalized().lerp(desired_dir.normalized(), neck_follow_rate)
		if desired_dir.length() < 0.0001:
			continue
		var rotation: Projection = _rotation_between(current_dir, desired_dir)
		var parent: Node4D = joint.get_parent() as Node4D
		var proposed: Projection = parent.global_basis.inverse() * (rotation * joint.global_basis)
		# Clamp against the joint's own rest, so repeated frames cannot wind the neck
		# round: the limit is on total deflection, not on this frame's step.
		joint.basis = _limited(proposed, deg_to_rad(neck_limit_degrees))


## Leans the neck's base toward whatever head_attention.gd is looking at.
##
## Applied to the FIRST segment only, deliberately: turning at the base swings the whole
## neck and the head with it, which is what a creature actually does to look behind
## itself. Spreading it over both segments bends the neck into an S instead.
##
## Runs BEFORE stabilisation so the height correction gets the last word - a look should
## not cost the creature its level gaze.
func _apply_neck_aim() -> void:
	if aim_weight <= 0.001 or aim_direction.length() < 0.0001 or _neck.is_empty():
		return
	var joint: Node4D = _neck[0]
	var current: Vector4 = _head.global_position - joint.global_position
	if current.length() < 0.0001:
		return
	var wanted: Vector4 = current.normalized().lerp(aim_direction.normalized(), clampf(aim_weight, 0.0, 1.0))
	if wanted.length() < 0.0001:
		return
	var parent: Node4D = joint.get_parent() as Node4D
	var rotation: Projection = _rotation_between(current, wanted)
	joint.basis = parent.global_basis.inverse() * (rotation * joint.global_basis)


## [param candidate] if it is within [param limit] of no rotation at all, otherwise
## scaled back toward identity. Measured on the basis's own y axis, which is the bone
## direction this rig convention uses.
func _limited(candidate: Projection, limit: float) -> Projection:
	var bone: Vector4 = candidate * Vector4(0, 1, 0, 0)
	var cos_t: float = clampf(bone.normalized().dot(Vector4(0, 1, 0, 0)), -1.0, 1.0)
	var angle: float = acos(cos_t)
	if angle <= limit:
		return candidate
	return _rotation_between(Vector4(0, 1, 0, 0),
		Vector4(0, 1, 0, 0).lerp(bone.normalized(), limit / maxf(angle, 0.0001)))


## The rotation taking direction [param from] onto direction [param to]. In 4D a
## rotation lives in a PLANE rather than about an axis, so this builds it in the plane
## the two directions span and leaves everything perpendicular untouched.
func _rotation_between(from: Vector4, to: Vector4) -> Projection:
	if from.length() < 0.000001 or to.length() < 0.000001:
		return Projection.IDENTITY
	var a: Vector4 = from.normalized()
	var target: Vector4 = to.normalized()
	var cos_t: float = clampf(a.dot(target), -1.0, 1.0)
	if cos_t > 0.999999:
		return Projection.IDENTITY
	var b: Vector4 = target - a * cos_t
	if b.length() < 0.000001:
		b = _any_perpendicular(a)
	b = b.normalized()
	var sin_t: float = sqrt(maxf(1.0 - cos_t * cos_t, 0.0))
	return Projection(
		_rotate_vector(Vector4(1, 0, 0, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 1, 0, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 0, 1, 0), a, b, cos_t, sin_t),
		_rotate_vector(Vector4(0, 0, 0, 1), a, b, cos_t, sin_t))


func _rotate_vector(x: Vector4, a: Vector4, b: Vector4, cos_t: float, sin_t: float) -> Vector4:
	var ax: float = a.dot(x)
	var bx: float = b.dot(x)
	return x + a * ((cos_t - 1.0) * ax - sin_t * bx) + b * ((cos_t - 1.0) * bx + sin_t * ax)


func _any_perpendicular(a: Vector4) -> Vector4:
	for candidate in [Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1)]:
		var p: Vector4 = candidate - a * a.dot(candidate)
		if p.length() > 0.001:
			return p
	return Vector4(0, 1, 0, 0)
