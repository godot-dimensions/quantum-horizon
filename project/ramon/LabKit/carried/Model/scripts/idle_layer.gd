# CARRIED OVER from res://ramon/Model/scripts/idle_layer.gd on 4 Oct 2026, so the lab owns this copy: the original can change without breaking the lab, and the other way round (LabKit/carried/README.md).
extends Node
## What the creature's BODY does when it is standing still: breathe continuously, and
## swish its tail now and then.
##
## This is step 8 of PROCEDURAL_CREATURE_ANIMATION_SYSTEM.md's stack, the
## "secondary/idle/action layer (when active) - overrides or blends specific chain
## targets". It only runs while the gait driver is halted, and while it runs it owns
## three channels the other solvers deliberately expose for it:
##
##   gait.breath_offset  - added to the body height by the gait driver, so the body has
##                         exactly one writer rather than two fighting over it
##   spine.flex_scale    - eased to 0, because the gait clock freezes when halted and a
##                         frozen clock would leave the back stuck mid-arch
##   tail.sway_scale     - briefly raised for a swish
##
## THE HEAD IS NOT HERE. It used to be, and then three more behaviours wanted it -
## glancing at a passing player, hunting for a player behind the creature, and the odd
## head shake. Four would-be writers of one basis is a race, so the head moved out to
## head_attention.gd, which owns it alone and decides between them by priority. This
## script keeps the body.
##
## RUNS AT PRIORITY -2, ahead of the gait driver at -1, so the channels it sets are the
## ones that frame's drivers read.
##
## Timing is random within a range rather than on a fixed beat. A creature that does
## something exactly every four seconds reads as a machine; not looking scheduled is the
## whole point of an idle.

@export var gait_driver_path: NodePath = NodePath("../IKGaitDriver")
@export var spine_solver_path: NodePath = NodePath("../SpineNeckSolver")
@export var tail_solver_path: NodePath = NodePath("../TailSway")

@export_group("Breathing")
## Continuous, and the only idle behaviour that never stops - a still creature that is
## completely motionless reads as a statue or a bug.
@export_range(0.0, 0.2, 0.005) var breath_amplitude: float = 0.035
@export_range(0.5, 10.0, 0.1, "suffix:s") var breath_period: float = 3.6

@export_group("Tail swish")
@export_range(1.0, 5.0, 0.1) var swish_scale: float = 2.4
@export_range(0.5, 20.0, 0.5, "suffix:s") var swish_interval_min: float = 2.5
@export_range(0.5, 30.0, 0.5, "suffix:s") var swish_interval_max: float = 7.0
@export_range(0.2, 4.0, 0.1, "suffix:s") var swish_duration: float = 1.3

var _gait: Node = null
var _spine: Node = null
var _tail: Node = null

var _breath_clock: float = 0.0
var _swish_timer: float = 0.0
var _swish_elapsed: float = -1.0


func _ready() -> void:
	# Ahead of the gait driver, so the channels below are set before it reads them.
	process_physics_priority = -2
	_gait = get_node_or_null(gait_driver_path)
	_spine = get_node_or_null(spine_solver_path)
	_tail = get_node_or_null(tail_solver_path)
	if _gait == null:
		push_warning("IdleLayer: gait_driver_path does not resolve - cannot tell idle from moving.")
		set_physics_process(false)
		return
	_swish_timer = randf_range(swish_interval_min, swish_interval_max)


func _physics_process(delta: float) -> void:
	var idle: bool = bool(_gait.halted)
	# Easing rather than switching: a gait change should not snap the back flat or knock
	# the breath out of the creature.
	var blend: float = clampf(delta * 4.0, 0.0, 1.0)
	if _spine != null:
		_spine.flex_scale = lerpf(float(_spine.flex_scale), 0.0 if idle else 1.0, blend)

	if not idle:
		# Hand the channels back and let the gait have the creature.
		_gait.breath_offset = lerpf(float(_gait.breath_offset), 0.0, blend)
		if _tail != null:
			_tail.sway_scale = lerpf(float(_tail.sway_scale), 1.0, blend)
		_swish_elapsed = -1.0
		return

	_breathe(delta)
	_swish_tail(delta)


## A slow rise and fall. Deliberately not a pure sine: a real breath spends longer
## easing out than drawing in, and skewing the curve is what stops it reading as a
## floating bob.
func _breathe(delta: float) -> void:
	_breath_clock = fposmod(_breath_clock + delta / maxf(breath_period, 0.01), 1.0)
	var raw: float = sin(_breath_clock * TAU)
	var skewed: float = raw * (0.7 + 0.3 * absf(raw))
	_gait.breath_offset = skewed * breath_amplitude


## An occasional flick, done by leaning on the tail solver's own figure-8 rather than
## driving the segments here. Two scripts writing the same bases would just race.
func _swish_tail(delta: float) -> void:
	if _tail == null:
		return
	if _swish_elapsed < 0.0:
		_swish_timer -= delta
		if _swish_timer > 0.0:
			_tail.sway_scale = lerpf(float(_tail.sway_scale), 1.0, clampf(delta * 4.0, 0.0, 1.0))
			return
		_swish_elapsed = 0.0
		_swish_timer = randf_range(swish_interval_min, swish_interval_max)
	_swish_elapsed += delta
	if _swish_elapsed >= swish_duration:
		_swish_elapsed = -1.0
		return
	# Up and back down over the burst, so it swells rather than switching on.
	var t: float = _swish_elapsed / maxf(swish_duration, 0.0001)
	_tail.sway_scale = 1.0 + (swish_scale - 1.0) * sin(t * PI)
