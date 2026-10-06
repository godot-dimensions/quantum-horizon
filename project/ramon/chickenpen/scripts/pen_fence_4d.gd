@tool
extends FenceGenerator4D

## The pen's fence: a FenceGenerator4D that also knows where the pen is.
##
## THE GENERATOR BUILDS THE FENCE NOW. This script used to place every post and rail itself,
## as a ring of 3D boxes stretched through W. FenceGenerator4D builds a real 4D fence around
## a footprint on the XZW ground, so the posts, ribs, beams, their spacing and their sizes
## are all the generator's properties. What is left here is what the rest of the pen asks a
## fence: where its inside is, somewhere in it to put a chicken, and walls to stop whoever
## walks into it.
##
## ONE SET OF NUMBERS DRIVES EVERYTHING (item 40). The mesh, the collision and the pen's
## bounds all come from the fence as it was last built - its corners and its post size - so
## there is no second box to drift out of step. To resize the pen, change the generator's
## own shape (box_size for a box) and update the fence; the walls follow on
## fence_mesh_updated.
##
## THE INSIDE IS 4D. The footprint is a volume in X, Z and W, walled on every side, so a
## chicken can leave through W as well as over a rail, and every helper here bounds W the
## same as X and Z.

## The walls, by name under Collision, and the side of the footprint each one closes.
const WALL_SIDES: Dictionary = {
	"WallPosX": Vector4(1, 0, 0, 0),
	"WallNegX": Vector4(-1, 0, 0, 0),
	"WallPosZ": Vector4(0, 0, 1, 0),
	"WallNegZ": Vector4(0, 0, -1, 0),
	"WallPosW": Vector4(0, 0, 0, 1),
	"WallNegW": Vector4(0, 0, 0, -1),
}


func _ready() -> void:
	if not Engine.is_editor_hint():
		_ensure_footprint()
	if not fence_mesh_updated.is_connected(_update_collision):
		fence_mesh_updated.connect(_update_collision)
	_update_collision()


## The box around the footprint, in this node's own space, as [low corner, high corner]: around
## the corners the fence was last built from in X, Z and W, and from the ground to the tops of
## the posts in Y. For a box fence this is the box itself.
func footprint_bounds() -> Array:
	var corners: PackedVector4Array = fence_corners
	if corners.is_empty():
		# A box fence that updates automatically does not save its corners, since the box
		# makes them, so before its first build there are none yet - but there is the box.
		var half: Vector3 = box_size * 0.5
		return [Vector4(-half.x, 0.0, -half.y, -half.z), Vector4(half.x, post_height_meters, half.y, half.z)]
	var lo: Vector4 = corners[0]
	var hi: Vector4 = corners[0]
	for corner in corners:
		lo = lo.min(corner)
		hi = hi.max(corner)
	hi.y += post_height_meters
	return [lo, hi]


## The pen interior, as a pair of corners in this node's own space. The return volume and
## the penned chickens both read this, so none of them can disagree about where the pen is
## (item 40).
##
## Inset by a post's thickness so it stays clear of the rails, and twice the fence's height,
## so a chicken thrown in is in the pen a little before it lands.
func interior_bounds() -> Array:
	var bounds: Array = footprint_bounds()
	var inset := Vector4(post_thickness_meters, 0.0, post_thickness_meters, post_thickness_meters)
	var lo: Vector4 = (bounds[0] as Vector4) + inset
	var hi: Vector4 = (bounds[1] as Vector4) - inset
	hi.y = (bounds[1] as Vector4).y + post_height_meters
	return [lo, hi]


## Whether a global point is in the pen: inside the footprint, whatever its shape, and no
## higher than interior_bounds() reaches.
func contains_point(point: Vector4) -> bool:
	var local: Vector4 = global_to_local(point)
	if not is_local_point_inside(local):
		return false
	var bounds: Array = interior_bounds()
	return local.y >= (bounds[0] as Vector4).y - 1.0 and local.y <= (bounds[1] as Vector4).y


## A point inside the pen a penned chicken can be sent to (items 44 and 78). On the ground,
## and at the fence's own W, so the birds are in the slice the pen is seen in.
func random_interior_point(rng: RandomNumberGenerator) -> Vector4:
	var bounds: Array = interior_bounds()
	var lo: Vector4 = bounds[0]
	var hi: Vector4 = bounds[1]
	# Kept off the rails so twelve birds do not pile into a corner.
	var margin: float = 0.6
	for _attempt in 16:
		var local := Vector4(rng.randf_range(lo.x + margin, hi.x - margin), 0.0,
			rng.randf_range(lo.z + margin, hi.z - margin), 0.0)
		# The bounds of a footprint that is not a box have corners outside the fence.
		if seed_mesh_4d == null or is_local_point_inside(local):
			return local_to_global(local)
	return global_position


## A global point moved into the pen's bounds, at least [param margin] in from every wall, at
## its own height. The bounds rather than the footprint, which for a box fence are the same.
func clamp_inside(point: Vector4, margin: float) -> Vector4:
	var bounds: Array = footprint_bounds()
	var lo: Vector4 = bounds[0]
	var hi: Vector4 = bounds[1]
	var middle: Vector4 = (lo + hi) * 0.5
	var reach: Vector4 = ((hi - lo) * 0.5 - Vector4.ONE * margin).maxf(0.0)
	var local: Vector4 = global_to_local(point)
	var clamped: Vector4 = local.clamp(middle - reach, middle + reach)
	clamped.y = local.y
	return local_to_global(clamped)


## How high the top of the rails is, for anything that perches on them: the top of the topmost
## beam, or of the ribs on a fence with no beams. The posts stand taller than either.
func rail_height() -> float:
	var rib_height: float = post_height_meters * rib_height_ratio
	if beam_count > 0 and beam_coverage > 0.0:
		return rib_height * beam_max_height_ratio
	return rib_height


## WITH MANUAL UPDATES THE FENCE LOADS WITHOUT A FOOTPRINT. FenceGenerator4D saves the mesh
## and the corners it was built from, but only builds the footprint in an update, so until
## one runs is_global_point_inside() is false everywhere - no chicken is ever in the pen, and
## Nike never meets the rails. The footprint is rebuilt here from the saved corners, which
## is cheap, rather than rebuilding the whole fence, which is what the saved mesh is there to
## avoid.
func _ensure_footprint() -> void:
	if update_automatically or seed_mesh_4d != null:
		return
	if input_shape_type == INPUT_SHAPE_SEED_MESH_3D:
		# Its footprint is the mesh's own faces, not the hull of its corners, so only an
		# update gives it.
		update_fence_mesh_now()
	elif fence_corners.size() >= 4:
		seed_mesh_4d = build_seed_mesh_from_corners()


## The walls: one box per side of the footprint's bounds, as long as that side, a post thick
## across it and a post high (item 39).
##
## BOXES, because physics here is axis-aligned boxes only (hub_demo_lessons.md). They close a
## box fence exactly; a footprint of another shape gets the box around it, which is as near
## as this physics can come.
##
## UPDATED IN PLACE. The walls are found under Collision by name, so the ones saved with the
## scene are moved and resized rather than replaced, and only a missing one is made.
func _update_collision() -> void:
	var body := get_node_or_null(^"Collision") as StaticBody4D
	if body == null:
		body = StaticBody4D.new()
		body.name = "Collision"
		add_child(body)
		_own(body)
	var bounds: Array = footprint_bounds()
	var lo: Vector4 = bounds[0]
	var hi: Vector4 = bounds[1]
	var middle: Vector4 = (lo + hi) * 0.5
	var half: Vector4 = (hi - lo) * 0.5
	for wall_name: String in WALL_SIDES:
		var side: Vector4 = WALL_SIDES[wall_name]
		var wall := body.get_node_or_null(NodePath(wall_name)) as CollisionShape4D
		if wall == null:
			wall = CollisionShape4D.new()
			wall.name = wall_name
			body.add_child(wall)
			_own(wall)
		var box := wall.shape as BoxShape4D
		if box == null:
			box = BoxShape4D.new()
			wall.shape = box
		box.size = Vector4(
			post_thickness_meters if side.x != 0.0 else half.x * 2.0,
			half.y * 2.0,
			post_thickness_meters if side.z != 0.0 else half.z * 2.0,
			post_thickness_meters if side.w != 0.0 else half.w * 2.0)
		wall.position = middle + side * half


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
