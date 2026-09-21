@tool
extends Node4D

## A procedural pen fence, rebuilt from Inspector numbers.
##
## MODULAR SEGMENTS, NOT A STRETCHED MESH (items 36 and 38). Posts are placed at a fixed
## spacing and rails are cut to length between them, so a wider pen gets MORE posts rather
## than fatter ones. Post proportions and rail thickness never change with pen size, which
## is the difference between a fence that resizes and a fence that is scaled.
##
## ONE SET OF NUMBERS DRIVES EVERYTHING (item 40). The visual fence, its collision and the
## return volume are all derived from the same extents in the same pass. The brief warns
## against a second manually sized box that can drift out of sync, so there is no second
## box: interior_bounds() computes from the same fields the posts were placed from.
##
## FOUR SIDES, FOUR NUMBERS (item 37). Per-side extents rather than width and depth,
## because directional editing is clearer when the pen has to be nudged away from
## something - and because the coop sits against one side, so that side often wants a
## different reach from its opposite.

enum GateSide { NONE, X_POSITIVE, X_NEGATIVE, Z_POSITIVE, Z_NEGATIVE }

@export_group("Extents")
@export_range(1.0, 40.0, 0.1) var extend_x_positive: float = 7.0: set = _set_x_pos
@export_range(1.0, 40.0, 0.1) var extend_x_negative: float = 7.0: set = _set_x_neg
@export_range(1.0, 40.0, 0.1) var extend_z_positive: float = 6.0: set = _set_z_pos
@export_range(1.0, 40.0, 0.1) var extend_z_negative: float = 6.0: set = _set_z_neg

@export_group("Fence")
## Low on purpose (item 41): the player must see the collected chickens over it and be
## able to throw one in.
@export_range(0.3, 3.0, 0.05) var height: float = 0.95: set = _set_height
@export_range(0.5, 6.0, 0.1) var post_spacing: float = 1.6: set = _set_spacing
@export_range(1, 5, 1) var rail_count: int = 2: set = _set_rails
@export_range(0.03, 0.4, 0.01) var post_thickness: float = 0.13: set = _set_post_thickness
@export_range(0.02, 0.3, 0.01) var rail_thickness: float = 0.07: set = _set_rail_thickness

## How far the fence reaches through W, for the meshes AND the collision. Generous,
## because a pen that exists in only one slice would let a chicken walk out of it sideways
## through the fourth axis.
##
## THE MESHES USE IT TOO. They used to be as thin through W as they are thick - a post was
## 0.13 through W because 0.13 was its width - so stepping one slice off zero made the
## whole fence disappear while its collision, which did use w_depth, went on stopping you.
## An invisible wall you cannot see the pen behind is the worst of both, and a player in
## another slice could not even find the pen they were carrying a chicken to.
@export_range(0.5, 12.0, 0.1) var w_depth: float = 6.0: set = _set_w_depth

@export_group("Gate")
@export var gate_side: GateSide = GateSide.Z_POSITIVE: set = _set_gate_side
## Where along that side the gap sits, from -1 at one end to +1 at the other.
@export_range(-1.0, 1.0, 0.05) var gate_position: float = 0.0: set = _set_gate_position
@export_range(0.0, 8.0, 0.1) var gate_width: float = 2.4: set = _set_gate_width

@export_group("Look")
@export var post_color: Color = Color(0.55, 0.40, 0.26): set = _set_post_color
@export var rail_color: Color = Color(0.62, 0.47, 0.31): set = _set_rail_color


func _set_x_pos(v: float) -> void: extend_x_positive = v; _rebuild_later()
func _set_x_neg(v: float) -> void: extend_x_negative = v; _rebuild_later()
func _set_z_pos(v: float) -> void: extend_z_positive = v; _rebuild_later()
func _set_z_neg(v: float) -> void: extend_z_negative = v; _rebuild_later()
func _set_height(v: float) -> void: height = v; _rebuild_later()
func _set_spacing(v: float) -> void: post_spacing = v; _rebuild_later()
func _set_rails(v: int) -> void: rail_count = v; _rebuild_later()
func _set_post_thickness(v: float) -> void: post_thickness = v; _rebuild_later()
func _set_rail_thickness(v: float) -> void: rail_thickness = v; _rebuild_later()
func _set_w_depth(v: float) -> void: w_depth = v; _rebuild_later()
func _set_gate_side(v: GateSide) -> void: gate_side = v; _rebuild_later()
func _set_gate_position(v: float) -> void: gate_position = v; _rebuild_later()
func _set_gate_width(v: float) -> void: gate_width = v; _rebuild_later()
func _set_post_color(v: Color) -> void: post_color = v; _rebuild_later()
func _set_rail_color(v: Color) -> void: rail_color = v; _rebuild_later()


func _ready() -> void:
	rebuild()


func _rebuild_later() -> void:
	# Setters fire while the scene is still loading, before children can be added.
	if is_node_ready():
		rebuild()


## The pen interior, as a pair of corners. The return volume and the penned chickens both
## read this, so none of them can disagree about where the pen is (item 40).
##
## Inset by a post's width so a chicken standing against the rail counts as inside rather
## than hovering on the boundary.
func interior_bounds() -> Array:
	var inset: float = post_thickness
	return [
		Vector4(-extend_x_negative + inset, 0.0, -extend_z_negative + inset, -w_depth * 0.5),
		Vector4(extend_x_positive - inset, height * 2.0, extend_z_positive - inset, w_depth * 0.5),
	]


func contains_point(point: Vector4) -> bool:
	var b: Array = interior_bounds()
	var lo: Vector4 = global_position + b[0]
	var hi: Vector4 = global_position + b[1]
	return point.x >= lo.x and point.x <= hi.x \
		and point.z >= lo.z and point.z <= hi.z \
		and point.w >= lo.w and point.w <= hi.w \
		and point.y >= lo.y - 1.0 and point.y <= hi.y


## A point inside the pen a penned chicken can be sent to (items 44 and 78).
func random_interior_point(rng: RandomNumberGenerator) -> Vector4:
	var b: Array = interior_bounds()
	# Kept off the rails so twelve birds do not pile into a corner.
	var margin: float = 0.6
	return global_position + Vector4(
		rng.randf_range(b[0].x + margin, b[1].x - margin),
		0.0,
		rng.randf_range(b[0].z + margin, b[1].z - margin),
		0.0)


func rebuild() -> void:
	for child in get_children():
		child.free()
	if extend_x_positive + extend_x_negative < 0.5 or extend_z_positive + extend_z_negative < 0.5:
		push_warning("PenFence: the pen is smaller than a chicken - check the extents (item 82).")
		return

	var post_mesh := BoxTetraMesh4D.new()
	post_mesh.size = Vector4(post_thickness, height, post_thickness, w_depth)
	var post_mat := TetraMaterial4D.new()
	post_mat.albedo_color = post_color
	var rail_mat := TetraMaterial4D.new()
	rail_mat.albedo_color = rail_color

	var body := StaticBody4D.new()
	body.name = "Collision"
	add_child(body)
	_own(body)

	# side = [along axis is X?, fixed coordinate, from, to]
	var sides := [
		[true, extend_z_positive, -extend_x_negative, extend_x_positive, GateSide.Z_POSITIVE],
		[true, -extend_z_negative, -extend_x_negative, extend_x_positive, GateSide.Z_NEGATIVE],
		[false, extend_x_positive, -extend_z_negative, extend_z_positive, GateSide.X_POSITIVE],
		[false, -extend_x_negative, -extend_z_negative, extend_z_positive, GateSide.X_NEGATIVE],
	]
	for i in sides.size():
		var side: Array = sides[i]
		# The side's index goes into every child name. Without it the two X-running sides
		# produce identical names, Godot silently renames the clashes, and anything that
		# looks children up by name quietly finds the wrong one.
		_build_side(i, side[0], side[1], side[2], side[3], side[4], post_mesh, post_mat, rail_mat, body)


func _build_side(index: int, along_x: bool, fixed: float, from: float, to: float,
		which: GateSide, post_mesh: BoxTetraMesh4D, post_mat: TetraMaterial4D,
		rail_mat: TetraMaterial4D, body: StaticBody4D) -> void:
	var span: float = to - from
	# MORE posts when the pen grows, never longer ones - that is what stops it looking
	# stretched (item 38).
	var count: int = maxi(int(ceil(span / post_spacing)), 1)
	var step: float = span / float(count)
	var gap_centre: float = from + span * 0.5 + gate_position * span * 0.5
	var gap_half: float = gate_width * 0.5 if which == gate_side else 0.0

	for i in count + 1:
		var at: float = from + step * float(i)
		if gap_half > 0.0 and absf(at - gap_centre) < gap_half:
			continue
		var post := MeshInstance4D.new()
		post.name = "Post_%d_%d" % [index, i]
		post.mesh = post_mesh
		post.material_override = post_mat
		post.position = Vector4(at if along_x else fixed, height * 0.5, fixed if along_x else at, 0.0)
		add_child(post)
		_own(post)

	# Rails run between the posts, skipping the gateway, and are cut to length rather
	# than scaled - a rail is its own box with its own size.
	var runs: Array = []
	if gap_half > 0.0:
		runs.append([from, gap_centre - gap_half])
		runs.append([gap_centre + gap_half, to])
	else:
		runs.append([from, to])

	for run_index in runs.size():
		var run: Array = runs[run_index]
		var length: float = run[1] - run[0]
		if length <= 0.05:
			continue
		var centre: float = (run[0] + run[1]) * 0.5
		for r in rail_count:
			var y: float = height * (float(r + 1) / float(rail_count + 1))
			var rail := MeshInstance4D.new()
			rail.name = "Rail_%d_%d_%d" % [index, run_index, r]
			var mesh := BoxTetraMesh4D.new()
			mesh.size = Vector4(length if along_x else rail_thickness, rail_thickness,
				rail_thickness if along_x else length, w_depth)
			rail.mesh = mesh
			rail.material_override = rail_mat
			rail.position = Vector4(centre if along_x else fixed, y, fixed if along_x else centre, 0.0)
			add_child(rail)
			_own(rail)

		# Item 39: one collision wall per RUN, generated in the same pass from the same
		# numbers, so it cannot describe a fence that is no longer there. Per run rather
		# than per rail: the rails are what you see, the wall is what you cannot walk
		# through, and a gateway needs a real gap in both.
		var shape := CollisionShape4D.new()
		shape.name = "Wall_%d_%d" % [index, run_index]
		var box := BoxShape4D.new()
		box.size = Vector4(length if along_x else post_thickness, height,
			post_thickness if along_x else length, w_depth)
		shape.shape = box
		shape.position = Vector4(centre if along_x else fixed, height * 0.5,
			fixed if along_x else centre, 0.0)
		body.add_child(shape)
		_own(shape)


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
