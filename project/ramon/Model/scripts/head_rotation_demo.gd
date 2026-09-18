extends Node
## Swings the head +-30 degrees in each of the XZ, XY, XW and ZW planes in turn,
## returning to rest before it reverses.
##
## MOVES THE RIG'S NODE BASIS AND NOTHING ELSE, which is the whole reason the
## creature was split into rigs. Measured on this creature: rotating a node costs
## 16.67 ms against a 16.94 ms idle frame - free, inside the noise. Moving the rig's
## BALLS instead re-lofts the mesh at 133 ms, and rewriting vertex positions costs
## 114 ms because the engine regenerates its whole 3D proxy mesh. A node transform is
## the only one of the three that fits in a frame.
##
## The head pivots about its rig's origin, which sits at the head/neck joint, so the
## nose swings with it - nose and head are one rig.

## The rig to rotate. Anything running loft_rig_4d.gd, or any Node4D.
@export var target_path: NodePath

@export_range(0.0, 90.0, 1.0, "suffix:°") var degrees: float = 30.0

## Seconds for one leg of the swing: rest to peak, or peak back to rest.
@export_range(0.1, 5.0, 0.05, "suffix:s") var seconds_per_move: float = 0.9

## A pause at each end, so the extreme is readable rather than flashing past.
@export_range(0.0, 2.0, 0.05, "suffix:s") var hold_seconds: float = 0.25

@export var show_label: bool = true

## W IS INCLUDED DELIBERATELY. XZ and XY are ordinary 3D turns - yaw and pitch. XW and
## ZW rotate through the axis the player cannot see, so the head does not appear to
## turn at all: it changes shape, thins out, and can leave the slice entirely. That
## contrast is the point of running all four.
const PLANES: PackedStringArray = ["XZ", "XY", "XW", "ZW"]

## rest -> +A, +A -> rest, rest -> -A, -A -> rest. Returning to rest before reversing
## is what makes the direction change readable instead of one continuous sweep.
const LEGS: Array = [[0.0, 1.0], [1.0, 0.0], [0.0, -1.0], [-1.0, 0.0]]

var _target: Node4D = null
var _label: Label = null
var _elapsed: float = 0.0
var _leg: int = 0
var _plane: int = 0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node4D
	if _target == null:
		push_warning("HeadRotationDemo: target_path does not point at a Node4D - nothing to rotate.")
		set_physics_process(false)
		return
	if show_label:
		var layer := CanvasLayer.new()
		add_child(layer)
		_label = Label.new()
		_label.position = Vector2(14, 64)  # clear of player.tscn's own position readout
		_label.add_theme_font_size_override("font_size", 19)
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		layer.add_child(_label)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	var leg_length: float = seconds_per_move + hold_seconds
	if _elapsed >= leg_length:
		_elapsed -= leg_length
		_leg += 1
		if _leg >= LEGS.size():
			_leg = 0
			_plane = (_plane + 1) % PLANES.size()

	# Smoothstep rather than linear, so the head eases in and out of each end
	# instead of starting and stopping abruptly.
	var raw: float = clampf(_elapsed / maxf(seconds_per_move, 0.0001), 0.0, 1.0)
	var eased: float = raw * raw * (3.0 - 2.0 * raw)
	var from: float = float(LEGS[_leg][0])
	var to: float = float(LEGS[_leg][1])
	var amount: float = lerpf(from, to, eased)
	var angle: float = deg_to_rad(amount * degrees)
	_target.basis = _plane_basis(PLANES[_plane], angle)

	if _label != null:
		_label.text = "head rotation: %s plane   %+.1f deg%s" % [
			PLANES[_plane], amount * degrees,
			"      (W planes change the head's SHAPE, not its facing)" if PLANES[_plane].contains("W") else ""]


## The rotation for one coordinate plane. Y is left out of the pair names the engine
## exposes for XZ, so from_zx covers it - the same plane, opposite sense.
func _plane_basis(plane: String, angle: float) -> Projection:
	match plane:
		"XY":
			return Basis4D.from_xy(angle)
		"XW":
			return Basis4D.from_xw(angle)
		"ZW":
			return Basis4D.from_zw(angle)
	return Basis4D.from_zx(angle)
