extends FenceGenerator4D

## The pen's fence: Aaron's FenceGenerator4D (4 Oct), answering the questions the pen's scripts
## asked the old GDScript fence (pen_fence_4d.gd, no longer used), so the return volume, the
## crows, the slice diagram, the celebration, the wolf's leap and the debug keys work again
## without each being rewritten (Ramon, 6 Oct: "you mentioned some gameplay elements were broken
## due to the fence swap. fix them ... keep the new fence and discard the old").
##
## THE FOOTPRINT IS BUILT WHEN THE PEN LOADS. The fence is saved with update_automatically off
## (its mesh is baked into the scene), and the generator then never builds its footprint, so
## is_global_point_inside() said no even at the pen's middle, and Nike's fence logic never saw the
## pen. One update at load builds it; the mesh that update makes on a worker thread is the same as
## the baked one.
##
## A BOX HAS TWO EQUAL SIDES PER AXIS. The old fence had four extents of its own; this one's box is
## centred on the node, so setting one side sets both (only the debug keys set them). For a
## footprint that is not a box, the extents are its corners' bounds and "inside" is the footprint.
##
## NO class_name (engine_gotchas.md).

## The pen's reach from its middle, metres, side by side, as the old fence named them.
var extend_x_positive: float:
	get:
		return float(_bounds()[1])
	set(v):
		_resize(0, v)
var extend_x_negative: float:
	get:
		return -float(_bounds()[0])
	set(v):
		_resize(0, v)
var extend_z_positive: float:
	get:
		return float(_bounds()[3])
	set(v):
		_resize(1, v)
var extend_z_negative: float:
	get:
		return -float(_bounds()[2])
	set(v):
		_resize(1, v)
## The top of the top rail, metres: where a crow sits and what the wolf leaps (the posts stand
## higher, post_height_meters).
var height: float:
	get:
		return post_height_meters * rib_height_ratio * beam_max_height_ratio
## How deep the pen reaches through W, metres.
var w_depth: float:
	get:
		return float(_bounds()[5]) - float(_bounds()[4])
var post_thickness: float:
	get:
		return post_thickness_meters


func _ready() -> void:
	queue_update_fence_mesh()


## The pen inside, as a pair of corners in this node's space, inset by a post's thickness so a
## chicken against a rail counts as inside (the old fence's own rule, item 40).
func interior_bounds() -> Array:
	var b: Array = _bounds()
	var inset: float = post_thickness_meters
	return [
		Vector4(float(b[0]) + inset, 0.0, float(b[2]) + inset, float(b[4])),
		Vector4(float(b[1]) - inset, height * 2.0, float(b[3]) - inset, float(b[5])),
	]


## Whether a global point is in the pen: within the inside's corners (and, for a footprint that is
## not a box, within the footprint itself).
func contains_point(point: Vector4) -> bool:
	var b: Array = interior_bounds()
	var lo: Vector4 = global_position + b[0]
	var hi: Vector4 = global_position + b[1]
	var in_box: bool = point.x >= lo.x and point.x <= hi.x and point.z >= lo.z and point.z <= hi.z \
		and point.w >= lo.w and point.w <= hi.w and point.y >= lo.y - 1.0 and point.y <= hi.y
	if not in_box or input_shape_type == INPUT_SHAPE_BOX:
		return in_box
	return is_global_point_inside(point)


## A global point inside the pen, kept 0.6 m off the rails, at W 0 (items 44 and 78).
func random_interior_point(rng: RandomNumberGenerator) -> Vector4:
	var b: Array = interior_bounds()
	var margin: float = 0.6
	var at := Vector4.ZERO
	for i in 30:
		at = global_position + Vector4(rng.randf_range(b[0].x + margin, b[1].x - margin), 0.0,
			rng.randf_range(b[0].z + margin, b[1].z - margin), 0.0)
		if input_shape_type == INPUT_SHAPE_BOX or is_global_point_inside(at):
			break
	return at


## [x min, x max, z min, z max, w min, w max] of the footprint, in this node's space.
func _bounds() -> Array:
	if input_shape_type == INPUT_SHAPE_BOX:
		var h: Vector3 = box_size * 0.5
		return [-h.x, h.x, -h.y, h.y, -h.z, h.z]
	var out: Array = [INF, -INF, INF, -INF, INF, -INF]
	for c in fence_corners:
		out = [minf(out[0], c.x), maxf(out[1], c.x), minf(out[2], c.z), maxf(out[3], c.z), minf(out[4], c.w), maxf(out[5], c.w)]
	if fence_corners.is_empty():
		return [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	return out


## Sets the box's reach along x (axis 0) or z (axis 1) on both sides, rebuilds, and moves the box
## walls under Collision to match (only the debug keys resize the pen).
func _resize(axis: int, reach: float) -> void:
	if input_shape_type != INPUT_SHAPE_BOX:
		push_warning("PenFence: only a box fence can be resized by its extents.")
		return
	var s: Vector3 = box_size
	if axis == 0:
		s.x = reach * 2.0
	else:
		s.y = reach * 2.0
	box_size = s
	if is_inside_tree():
		queue_update_fence_mesh()
		_fit_walls()


## The six box walls under Collision, fitted to the box: four round the sides, two closing it in W.
## Their height and thickness stay as they were set.
func _fit_walls() -> void:
	var body: Node = get_node_or_null("Collision")
	if body == null:
		return
	var h: Vector3 = box_size * 0.5
	for c in body.get_children():
		var cs := c as CollisionShape4D
		if cs == null or not (cs.shape is BoxShape4D):
			continue
		var box := cs.shape as BoxShape4D
		var t: float = minf(minf(box.size.x, box.size.z), box.size.w)
		var tall: float = box.size.y
		match String(cs.name):
			"WallPosZ", "WallNegZ":
				cs.position = Vector4(0.0, tall * 0.5, h.y * (1.0 if cs.name == "WallPosZ" else -1.0), 0.0)
				box.size = Vector4(box_size.x, tall, t, box_size.z)
			"WallPosX", "WallNegX":
				cs.position = Vector4(h.x * (1.0 if cs.name == "WallPosX" else -1.0), tall * 0.5, 0.0, 0.0)
				box.size = Vector4(t, tall, box_size.y, box_size.z)
			"WallPosW", "WallNegW":
				cs.position = Vector4(0.0, tall * 0.5, 0.0, h.z * (1.0 if cs.name == "WallPosW" else -1.0))
				box.size = Vector4(box_size.x, tall, box_size.y, t)
