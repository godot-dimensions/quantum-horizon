extends Node4D
## Walks a two-legged lofted creature - a chicken - on Motion Lab's gait clock.
##
## WHY NOT ik_gait_driver.gd, which already does this for Trym's creature: that driver
## does not discover legs, it enumerates eight hard-coded names -
##
##     for station in ["Fore", "Hind"]: for side in ["L", "R"]: for w_half in ["A", "K"]
##
## - and reads the body plan straight out of the resulting string ("tag[4] == L",
## "tag[5] == K") to index a four-element offsets table. A biped has no fore/hind, no
## ana/kata half and two legs, so every one of those assumptions fails. Generalising it
## is the right long-term move and is a contained job; this is the narrow version that
## proves a biped works at all.
##
## A CHICKEN IS NOT A SMALL QUADRUPED. Two differences drive everything here:
##
##   * Two legs alternate at exactly half a cycle. There is no diagonal pair to keep in
##     step, so the gait table's four offsets have nothing to say.
##   * The body pitches and the head counter-rotates. A quadruped's trunk bobs twice per
##     stride, once per diagonal pair; a biped's rocks ONCE, over whichever foot is
##     planted, and a bird holds its head still against that rocking - the "chicken
##     head" effect Trym's own design doc names in section 4.4 as a thing to build.
##
## The legs are driven as loft balls rather than as rigid bones, because the chicken was
## authored as a model and not as a bone rig. That costs a re-loft of the two small leg
## rigs each frame; see _physics_process for what that actually measures.

const _GaitController = preload("res://scripts/gait_controller.gd")

## The two leg rigs. Each must be its OWN rig with mirroring off - while they are a
## single mirrored rig they are the same limb, and cannot hold different phases.
@export var left_leg_path: NodePath = NodePath("../LegL")
@export var right_leg_path: NodePath = NodePath("../LegR")
@export var body_path: NodePath = NodePath("../Body")
@export var neck_path: NodePath = NodePath("../NeckHead")

## Small numbers: a chicken's stride is a fraction of its leg, and its leg is already
## nearly straight standing still (hip 0.70, foot 0.03, segments totalling 0.67), so
## there is very little slack for a solver to bend into.
@export var stride_length: float = 0.13
@export var step_height: float = 0.055
@export var body_bob: float = 0.018
@export var body_pitch: float = 0.035
@export var head_stabilise: float = 0.9

var halted: bool = false
var speed: float = 1.2

var _gait: Node
var _legs: Array = []
var _body: Node
var _neck: Node
var _body_rest: Vector4
var _neck_rest: Vector4


func _ready() -> void:
	for path in [left_leg_path, right_leg_path]:
		var rig: Node = get_node_or_null(path)
		if rig == null or not rig.has_method("build"):
			continue
		var balls: Array = []
		for child in rig.get_children():
			if child.has_method("get_loft_section"):
				balls.append(child)
		if balls.size() < 3:
			continue
		# Authored bottom-up: Ball1 is the foot, Ball3 the hip. Sort by height so the
		# code does not depend on the order they happen to sit in the scene tree.
		balls.sort_custom(func(a, b): return a.position.y < b.position.y)
		_legs.append({
			"rig": rig, "foot": balls[0], "knee": balls[1], "hip": balls[2],
			"hip_pos": balls[balls.size() - 1].position,
			"rest_foot": balls[0].position,
			"upper": balls[2].position.distance_to(balls[1].position),
			"lower": balls[1].position.distance_to(balls[0].position),
		})
	if _legs.size() < 2:
		push_warning("ChickenWalker: needs two independent leg rigs, found %d." % _legs.size())
		set_physics_process(false)
		return

	_body = get_node_or_null(body_path)
	_neck = get_node_or_null(neck_path)
	if _body != null:
		_body_rest = _body.position
	if _neck != null:
		_neck_rest = _neck.position

	_gait = Node.new()
	_gait.set_script(_GaitController)
	_gait.name = "GaitController"
	_gait.standalone_input = false
	_gait.body_path = NodePath("..")
	add_child(_gait)
	if _gait.has_method("apply_preset"):
		_gait.apply_preset("walk")


func _physics_process(_delta: float) -> void:
	# Only the two LEG rigs re-loft, and they are the cheapest rigs on the bird. The
	# body, neck, wings and wattle never rebuild - they are moved as whole nodes, which
	# is the rigid approach Trym's creature uses throughout. A chicken authored as bones
	# rather than as a model would not re-loft at all.
	var phase: float = float(_gait.phase_progress)
	var duty: float = float(_gait.duty_factor)

	for index in range(_legs.size()):
		# Two legs, half a cycle apart. That is the whole of a biped gait.
		var local_phase: float = fposmod(phase + (0.0 if index == 0 else 0.5), 1.0)
		_place_leg(_legs[index], _foot_position(_legs[index], local_phase, duty))

	# ONE rock per stride, not two: a biped leans over whichever foot is planted.
	if _body != null:
		var rock: float = sin(phase * TAU)
		_body.position = _body_rest + Vector4(0.0, absf(rock) * body_bob, rock * body_pitch, 0.0)
	# And the head holds still against it - a bird's gaze stabilisation.
	if _neck != null and _body != null:
		var drift: Vector4 = _body.position - _body_rest
		_neck.position = _neck_rest - drift * head_stabilise


func _foot_position(leg: Dictionary, local_phase: float, duty: float) -> Vector4:
	var rest: Vector4 = leg["rest_foot"]
	var forward := Vector4(0.0, 0.0, 1.0, 0.0)
	var lift_off: Vector4 = rest - forward * (stride_length * 0.5)
	var landing: Vector4 = rest + forward * (stride_length * 0.5)
	if local_phase < duty:
		return landing.lerp(lift_off, local_phase / maxf(duty, 0.0001))
	var swing: float = (local_phase - duty) / maxf(1.0 - duty, 0.0001)
	var eased: float = swing * swing * (3.0 - 2.0 * swing)
	var apex: Vector4 = (lift_off + landing) * 0.5 + Vector4(0.0, step_height * 2.0, 0.0, 0.0)
	return lift_off.lerp(apex, eased).lerp(apex.lerp(landing, eased), eased)


## Closed-form two-bone IK, knee bending FORWARD - a bird's visible joint is the ankle,
## which folds the opposite way to a mammal's knee, and getting it backwards is the
## single most obvious way to make a chicken look wrong.
func _place_leg(leg: Dictionary, goal: Vector4) -> void:
	var hip: Vector4 = leg["hip_pos"]
	var upper: float = float(leg["upper"])
	var lower: float = float(leg["lower"])
	var to_goal: Vector4 = goal - hip
	var reach: float = to_goal.length()
	if reach < 0.0001:
		return
	reach = clampf(reach, absf(upper - lower) + 0.005, upper + lower - 0.005)
	var direction: Vector4 = to_goal.normalized()
	var along: float = (reach * reach + upper * upper - lower * lower) / (2.0 * reach)
	var out: float = sqrt(maxf(upper * upper - along * along, 0.0))

	var bend := Vector4(0.0, 0.0, 1.0, 0.0)
	bend -= direction * bend.dot(direction)
	if bend.length() < 0.001:
		bend = Vector4(1.0, 0.0, 0.0, 0.0)
		bend -= direction * bend.dot(direction)
	bend = bend.normalized()

	(leg["knee"] as Node4D).position = hip + direction * along + bend * out
	(leg["foot"] as Node4D).position = hip + direction * reach
