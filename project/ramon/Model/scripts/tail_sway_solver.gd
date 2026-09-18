extends Node
## A gentle figure-8 tail sway, adapted to four dimensions.
##
## WHAT MAKES A DOG'S TAIL A FIGURE-8: it is not one oscillation but two at different
## rates - a side-to-side sway, and a vertical bob at TWICE the sway's frequency. Seen
## from behind, the tip traces a lying-down 8. Matching frequencies would just give a
## diagonal line, and that is the whole trick.
##
## THE 4D ADAPTATION: the sway is not confined to the visible side-to-side axis. The
## horizontal half of the 8 precesses through the (Z, W) plane - Z and W a quarter cycle
## apart - so the tail swings out through the axis the player cannot see and back. In
## the w = 0 slice this reads as a sway whose reach PULSES: wide when the tail is in the
## slice, narrow when it has swung into W. A purely Z sway would look identical from
## every W, which is the failure mode this whole project keeps running into.
##
## The wave also LAGS down the chain, each segment a fraction of a cycle behind the one
## before it, so the tail whips rather than swinging rigidly as one plank.
##
## Only node bases are written, so this costs nothing - the same reason the creature was
## split into rigs. It deliberately does not read the gait: a tail that is exactly
## phase-locked to the footfalls looks mechanical. Set period_seconds to the gait's
## period if you want them synchronised.

@export var creature_path: NodePath = NodePath("../Creature")

## The chain, root to tip. Rotations compose down it, so the tip accumulates all four.
@export var segment_names: PackedStringArray = ["Tail1", "Tail2", "Tail3", "Tail4"]

## Total side-to-side sway at the TIP. Each segment takes a share of this, so no single
## joint bends anywhere near this far.
@export_range(0.0, 90.0, 1.0, "suffix:°") var sway_degrees: float = 30.0

## The vertical half of the 8, at twice the sway frequency. Smaller than the sway, as
## a real tail's is.
@export_range(0.0, 45.0, 1.0, "suffix:°") var bob_degrees: float = 12.0

## How far the sway leans into the unseen axis. At 0 this is an ordinary 3D dog tail.
@export_range(0.0, 60.0, 1.0, "suffix:°") var w_sway_degrees: float = 18.0

@export_range(0.2, 6.0, 0.05, "suffix:s") var period_seconds: float = 1.6

## How far behind each segment runs from the one before it, as a fraction of a cycle.
## Zero makes the tail a rigid plank; too much coils it up.
@export_range(0.0, 0.3, 0.01) var lag_per_segment: float = 0.08

## Share of the total each segment carries, root to tip. Weighted toward the tip so the
## motion grows along the tail instead of hinging at the rump.
@export var segment_weights: PackedFloat32Array = [0.15, 0.20, 0.30, 0.35]

## Multiplied into every amplitude. idle_layer.gd raises this briefly for a swish;
## left at 1 it changes nothing, so the walking behaviour is untouched.
var sway_scale: float = 1.0

var _segments: Array[Node4D] = []
var _elapsed: float = 0.0


func _ready() -> void:
	var creature: Node4D = get_node_or_null(creature_path) as Node4D
	if creature == null:
		push_warning("TailSway: creature_path does not resolve.")
		set_physics_process(false)
		return
	# The tail hangs off the rump, each segment nested in the one before it.
	var path: String = "Barrel/Rump"
	for name in segment_names:
		path = "%s/%s" % [path, name]
		var segment: Node4D = creature.get_node_or_null(path) as Node4D
		if segment == null:
			break
		_segments.append(segment)
	if _segments.is_empty():
		push_warning("TailSway: found no tail segments under Barrel/Rump.")
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var cycle: float = _elapsed / maxf(period_seconds, 0.01)
	for i in range(_segments.size()):
		var weight: float = segment_weights[i] if i < segment_weights.size() else 1.0 / float(_segments.size())
		var phase: float = TAU * (cycle - float(i) * lag_per_segment)
		# Sway and bob at a 1:2 ratio - that ratio IS the figure-8.
		var sway: float = deg_to_rad(sway_degrees * weight * sway_scale) * sin(phase)
		var bob: float = deg_to_rad(bob_degrees * weight * sway_scale) * sin(phase * 2.0)
		# A quarter cycle behind the sway, so the horizontal half of the 8 sweeps
		# through W rather than staying in the visible plane.
		var w_sway: float = deg_to_rad(w_sway_degrees * weight * sway_scale) * cos(phase)
		# The tail runs along +X, so these three planes each move the tip on one axis:
		# ZX sideways, XY up and down, XW through the axis that cannot be seen.
		_segments[i].basis = (Basis4D.from_zx(sway)
			* Basis4D.from_xy(bob)
			* Basis4D.from_xw(w_sway))
