@tool
extends Node4D

## A dry stone wall that is thin in W: the pen's first lesson in the fourth direction (6 Oct 2026,
## layout A, PenLayout/PLAN_A.md step 19). It runs across the field's west side from the cave
## hill to the field's edge, so on the farm's slice there is no way round it; step a metre and a
## half ana (or kata) and it is not there. The long way round is east, past the meadow.
##
## STONES, NOT A SLAB. Each stone has its own length, height and depth in W (between
## [member w_stone_min] and the wall's [member w_depth]), so as you step through W the wall
## does not vanish all at once: the shallow stones go first and it thins to a few ragged ones
## before it is gone. That is what tells you it is thin in W rather than simply not there.
## Merged into one mesh per colour, as the watchtower is (lookout_tower_4d.gd), so a wall of a
## hundred-odd stones is three draws.
##
## ONE COLLIDER: physics here is boxes that do not turn, so the wall is a single box as long,
## tall, thick and deep in W as the wall. Keep the node unturned or turned in 90 degree steps.
##
## It teaches itself: a marker in the group "tutor_spot" (pen_tutor_4d.gd) at the wall's middle
## says what to do the first time you come up to it on its slice.

@export_range(2.0, 80.0, 0.5, "suffix:m") var length: float = 42.0: set = _set_length
@export_range(0.5, 3.0, 0.05, "suffix:m") var height: float = 1.5: set = _set_height
@export_range(0.3, 2.0, 0.05, "suffix:m") var thickness: float = 0.7: set = _set_thickness
## How deep in W the wall is, all of it: past half this, ana or kata, it is gone.
@export_range(0.2, 3.0, 0.05, "suffix:m") var w_depth: float = 0.9: set = _set_w_depth
## The shallowest a stone may be in W, so some go before the wall's edge.
@export_range(0.1, 3.0, 0.05, "suffix:m") var w_stone_min: float = 0.45: set = _set_w_min
@export_range(0.3, 2.0, 0.05, "suffix:m") var stone_length: float = 0.9: set = _set_stone
@export_range(1, 6) var courses: int = 3: set = _set_courses
@export var colours: Array[Color] = [Color(0.47, 0.45, 0.41), Color(0.39, 0.38, 0.35), Color(0.55, 0.52, 0.46)]: set = _set_colours
@export var stone_seed: int = 7: set = _set_seed
## Where along the wall (metres from its middle, along x) the tutor marker stands; the path
## crosses there.
@export var tutor_at: float = 12.0: set = _set_tutor_at
@export var tutor_text: String = "This wall is thin in W. Hold {ana} to step ana past it."

const OWN := &"_stone_wall_part"

var _pending: bool = false


func _set_length(v: float) -> void: length = v; _later()
func _set_height(v: float) -> void: height = v; _later()
func _set_thickness(v: float) -> void: thickness = v; _later()
func _set_w_depth(v: float) -> void: w_depth = v; _later()
func _set_w_min(v: float) -> void: w_stone_min = v; _later()
func _set_stone(v: float) -> void: stone_length = v; _later()
func _set_courses(v: int) -> void: courses = v; _later()
func _set_colours(v: Array[Color]) -> void: colours = v; _later()
func _set_seed(v: int) -> void: stone_seed = v; _later()
func _set_tutor_at(v: float) -> void: tutor_at = v; _later()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


## Everything this script made, taken down and put up again. Children it did not make stay.
func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var batches: Array = []
	for i in colours.size():
		batches.append(ArrayTetraMesh4D.new())
	if batches.is_empty():
		batches.append(ArrayTetraMesh4D.new())
	var cache: Dictionary = {}
	var course_h: float = height / float(courses)
	for c in courses:
		var x: float = -length * 0.5
		# Every other course starts half a stone in, as a wall is laid.
		if c % 2 == 1:
			x += stone_length * 0.5 * rng.randf_range(0.6, 1.0)
		var top: bool = c == courses - 1
		while x < length * 0.5 - 0.05:
			var l: float = minf(stone_length * rng.randf_range(0.7, 1.3), length * 0.5 - x)
			var h: float = course_h * rng.randf_range(0.88, 1.0)
			# The top course a little proud of the faces, as coping stones are.
			var t: float = thickness * (1.08 if top else rng.randf_range(0.9, 1.0))
			var wd: float = rng.randf_range(w_stone_min, w_depth)
			var at := Vector4(x + l * 0.5, course_h * c + h * 0.5, rng.randf_range(-0.03, 0.03),
				rng.randf_range(-1.0, 1.0) * (w_depth - wd) * 0.5)
			var size := Vector4(l - 0.03, h - 0.02, t, wd)
			var key: String = "%.2f,%.2f,%.2f,%.2f" % [size.x, size.y, size.z, size.w]
			if not cache.has(key):
				var box := BoxTetraMesh4D.new()
				box.size = size
				cache[key] = box.to_array_tetra_mesh()
			(batches[rng.randi() % batches.size()] as ArrayTetraMesh4D).merge_with(cache[key], at, Projection.IDENTITY)
			x += l
	for i in batches.size():
		var node := MeshInstance4D.new()
		node.name = "Stones%d" % i
		node.mesh = batches[i]
		var m := TetraMaterial4D.new()
		m.albedo_color = colours[i] if i < colours.size() else Color(0.45, 0.43, 0.4)
		node.material_override = m
		_own(node)
	var body := StaticBody4D.new()
	body.name = "Solid"
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = Vector4(length, height, thickness, w_depth)
	holder.shape = shape
	holder.position = Vector4(0.0, height * 0.5, 0.0, 0.0)
	body.add_child(holder)
	_own(body)
	var spot := Node4D.new()
	spot.name = "TutorSpot"
	spot.position = Vector4(clampf(tutor_at, -length * 0.5, length * 0.5), 1.0, 0.0, 0.0)
	spot.add_to_group(&"tutor_spot")
	spot.set_meta(&"tutor_key", "stone_wall")
	spot.set_meta(&"tutor_text", tutor_text)
	spot.set_meta(&"tutor_radius", 6.0)
	spot.set_meta(&"tutor_w", w_depth * 0.5 + 0.3)
	spot.set_meta(&"tutor_when", "in")
	_own(spot)


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)
