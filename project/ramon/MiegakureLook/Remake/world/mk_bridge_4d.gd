extends Node4D
## Crosswise: a bridge that slides out, one plank at a time, when something tells it to (a plate
## with a crate on it; PLAN.md step 43), and slides back when told the opposite.
##
## It spans `length` along -Z from this node (the near lip), `width` in X and `depth_w` in W. The
## planks wait tucked under the near lip, below the floor, and each one slides out to its place in
## turn, so you watch the way being laid toward the far side. Each plank is a real box with its own
## collider; the colliders move with them (the physics engine re-reads every body's box each frame).
##
## NO class_name (engine_gotchas.md).

signal laid
signal pulled_back

const Build := preload("res://ramon/MiegakureLook/Remake/world/mk_build.gd")

@export var length: float = 4.0
@export var width: float = 2.0
@export var depth_w: float = 1.6
@export var planks: int = 5
@export var thickness: float = 0.3
@export var seconds_per_plank: float = 0.22
@export var tex: String = "white"
@export var tint: Color = Color(1.0, 0.96, 0.86)

var open: bool = false
var _boards: Array = []
var _progress: float = 0.0


func _ready() -> void:
	var plank_len: float = length / float(planks)
	for i in planks:
		var size := Vector4(width, thickness, plank_len - 0.04, depth_w)
		var body: Node4D = Build.box(self, "Plank%d" % i, global_position, size,
			Build.surface(tex, global_position, size, 1.0, {"tint": tint, "side_tint": Color(0.7, 0.66, 0.6)}))
		_boards.append(body)
	_place(0.0)


## Lay it out (true) or pull it back (false).
func set_open(value: bool) -> void:
	if value == open:
		return
	open = value


func _physics_process(delta: float) -> void:
	var target: float = 1.0 if open else 0.0
	if is_equal_approx(_progress, target):
		return
	var rate: float = delta / maxf(seconds_per_plank * float(planks), 0.01)
	var before: float = _progress
	_progress = move_toward(_progress, target, rate)
	_place(_progress)
	if _progress >= 1.0 and before < 1.0:
		laid.emit()
	elif _progress <= 0.0 and before > 0.0:
		pulled_back.emit()


## Each plank's share of the slide, in order from the near lip: plank i moves while the overall
## progress passes through its slot, from tucked under the lip to its place.
func _place(p: float) -> void:
	var plank_len: float = length / float(planks)
	for i in _boards.size():
		var slot: float = clampf(p * float(planks) - float(i), 0.0, 1.0)
		var eased: float = slot * slot * (3.0 - 2.0 * slot)
		var home := Vector4(0, -thickness * 0.5, -plank_len * (float(i) + 0.5), 0)
		var tucked := Vector4(0, -thickness * 1.6, plank_len * 0.6, 0)
		var b: Node4D = _boards[i]
		b.position = tucked.lerp(home, eased)
		b.visible = eased > 0.02


func is_laid() -> bool:
	return _progress >= 1.0
