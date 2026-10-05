@tool
extends Node4D

## Stones set in a ring, or piled in a cairn, somewhere off the farm's slice (6 Oct 2026, layout
## A's easter eggs, PenLayout/PLAN_A.md steps 29-30). Where a bag of azoth is hidden, so the
## place reads as a place when you find it and not as a pickup lying in an empty field.
##
## OFF THE SLICE ON PURPOSE. Put the node at a W of its own: the stones are only as deep in W as
## [member w_depth], so from the farm's slice there is nothing there, and in volume view
## (Combined) they show as a faint ghost, which is the clue.
##
## Merged into one mesh per colour; each standing stone gets a box collider (physics here is
## boxes that do not turn, so the stones are not turned either: their jitter is in size only).

enum Shape { RING, CAIRN }

@export var shape: Shape = Shape.RING: set = _set_shape
## Ring: how many stones and how far out. Cairn: how many stones in the pile.
@export_range(1, 24) var count: int = 9: set = _set_count
@export_range(0.5, 12.0, 0.1, "suffix:m") var radius: float = 3.0: set = _set_radius
@export_range(0.2, 3.0, 0.05, "suffix:m") var stone_size: float = 0.7: set = _set_size
## Ring stones stand this tall (times their size, give or take).
@export_range(0.5, 4.0, 0.05) var stand: float = 1.8: set = _set_stand
@export_range(0.2, 4.0, 0.05, "suffix:m") var w_depth: float = 1.2: set = _set_w
@export var colours: Array[Color] = [Color(0.50, 0.48, 0.44), Color(0.42, 0.41, 0.38), Color(0.58, 0.55, 0.50)]: set = _set_colours
@export var stone_seed: int = 3: set = _set_seed
@export var solid: bool = true: set = _set_solid

const OWN := &"_stones_part"

var _pending: bool = false


func _set_shape(v: Shape) -> void: shape = v; _later()
func _set_count(v: int) -> void: count = v; _later()
func _set_radius(v: float) -> void: radius = v; _later()
func _set_size(v: float) -> void: stone_size = v; _later()
func _set_stand(v: float) -> void: stand = v; _later()
func _set_w(v: float) -> void: w_depth = v; _later()
func _set_colours(v: Array[Color]) -> void: colours = v; _later()
func _set_seed(v: int) -> void: stone_seed = v; _later()
func _set_solid(v: bool) -> void: solid = v; _later()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if not is_node_ready() or _pending:
		return
	_pending = true
	rebuild.call_deferred()


func rebuild() -> void:
	_pending = false
	for c in get_children():
		if c.has_meta(OWN):
			remove_child(c)
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = stone_seed
	var batches: Array = []
	for i in maxi(colours.size(), 1):
		batches.append(ArrayTetraMesh4D.new())
	var boxes: Array = []
	if shape == Shape.RING:
		for i in count:
			# Half a step round, so there is a gap (not a stone) due south, +z, where a path comes in.
			var angle: float = TAU * (float(i) + 0.5) / float(count) + rng.randf_range(-0.1, 0.1)
			var s: float = stone_size * rng.randf_range(0.8, 1.2)
			var h: float = s * stand * rng.randf_range(0.75, 1.15)
			var at := Vector4(sin(angle) * radius, h * 0.5, cos(angle) * radius, rng.randf_range(-0.08, 0.08))
			boxes.append([at, Vector4(s, h, s * rng.randf_range(0.5, 0.8), w_depth * rng.randf_range(0.75, 1.0))])
	else:
		var y: float = 0.0
		for i in count:
			var s: float = stone_size * lerpf(1.0, 0.45, float(i) / maxf(float(count - 1), 1.0)) * rng.randf_range(0.9, 1.1)
			var h: float = s * rng.randf_range(0.45, 0.6)
			var at := Vector4(rng.randf_range(-0.06, 0.06) * stone_size, y + h * 0.5, rng.randf_range(-0.06, 0.06) * stone_size, 0.0)
			boxes.append([at, Vector4(s, h, s * rng.randf_range(0.85, 1.0), w_depth * lerpf(1.0, 0.6, float(i) / maxf(float(count - 1), 1.0)))])
			y += h * 0.96
	for i in boxes.size():
		var b: Array = boxes[i]
		var box := BoxTetraMesh4D.new()
		box.size = b[1]
		(batches[i % batches.size()] as ArrayTetraMesh4D).merge_with(box.to_array_tetra_mesh(), b[0], Projection.IDENTITY)
	for i in batches.size():
		var node := MeshInstance4D.new()
		node.name = "Stones%d" % i
		node.mesh = batches[i]
		var m := TetraMaterial4D.new()
		m.albedo_color = colours[i] if i < colours.size() else Color(0.5, 0.48, 0.44)
		node.material_override = m
		_own(node)
	if solid:
		var body := StaticBody4D.new()
		body.name = "Solid"
		for b in boxes:
			var holder := CollisionShape4D.new()
			var box_shape := BoxShape4D.new()
			box_shape.size = b[1]
			holder.shape = box_shape
			holder.position = b[0]
			body.add_child(holder)
		_own(body)


func _own(node: Node) -> void:
	node.set_meta(OWN, true)
	add_child(node)
