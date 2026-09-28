@tool
extends Node4D

## A wooden shed for Trym to work in. Solid panel walls, a pitched roof, and a doorway in
## one gable end.
##
## PANELS, NOT PLANKS. An earlier version built every wall from board courses. It looked
## better standing outside it and it is the wrong thing while the inside is being staged:
## fifty boxes per wall to iterate on, and none of it visible once the walls come off for
## the interior shot. One box per wall until the staging is settled.
##
## THE ROOF HANGS OFF A PIVOT AT THE RIDGE. The first version positioned each slab at its
## own centre and rotated it in place, and came out visibly lopsided - the offset and the
## rotation sign had to be right together and one of them was not. Each plane is now a
## child of a pivot sitting on the ridge line, offset along its own local axis, so the two
## sides are mirror images by construction. This engine's rotation signs are
## counter-intuitive enough that block_gait_4d.gd keeps a note about it; building the
## symmetry in beats re-deriving it.
##
## NO GABLE FILL, WHICH IS THE COOP'S ANSWER TOO. An earlier version stepped a triangle out
## of three boxes and read exactly as badly as that sounds. The two roof planes meeting at
## the ridge close the silhouette on their own; what is left is a small triangular gap under
## the ridge, which pen_coop_4d.gd has had since it was built without anybody minding. A
## genuine wedge needs a hand-tetrahedralised ArrayTetraMesh4D - about thirty boundary
## cells - which is worth its own piece of work rather than being squeezed in here.
##
## THE CUTAWAY FOLLOWS THE CAMERA. set_cutaway(true) takes the roof off and hides whichever
## walls stand between the camera and the inside, recomputed each frame from the dot product
## of each wall's outward normal with the direction to the camera.
##
## Animal Crossing gets away with a permanently missing wall because its interior camera
## never moves. This one orbits, so a fixed hole only works from one angle - walk round and
## you are looking at the back of a wall again. Four dot products a frame works from
## everywhere, which means the player keeps their own camera, and keeps seeing what happens
## inside.
##
## REAL DEPTH THROUGH W, or the building vanishes the instant the viewer slices away from
## it, which reads as the shed being deleted rather than as the shed being elsewhere.
##
## NO COLLISION, ON PURPOSE. You walk in through the door.

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export_group("Size")
## Along the ridge. The gable ends, and the door, are on the X faces.
@export_range(1.5, 14.0, 0.1) var length: float = 6.2: set = _set_length
@export_range(1.5, 14.0, 0.1) var width: float = 4.8: set = _set_width
@export_range(1.2, 5.0, 0.1) var wall_height: float = 2.6: set = _set_wall_height
@export_range(0.3, 3.0, 0.05) var ridge_rise: float = 1.2: set = _set_ridge
@export_range(0.0, 1.2, 0.01) var eaves: float = 0.46: set = _set_eaves
## How far the whole roof is dropped so its eaves overlap the wall tops instead of resting
## exactly on them. A roof that meets its walls on a perfect line reads as two objects
## stacked; a small overlap reads as one building.
@export_range(0.0, 0.6, 0.01) var roof_drop: float = 0.16: set = _set_roof_drop
@export_range(0.05, 0.4, 0.01) var wall_thick: float = 0.14: set = _set_thick
## Roof planks: how wide each one is, and how much shorter the ones near the ends get.
## The ragged edge is at the EAVES, never at the ridge - a roof with gaps along its ridge
## leaks, and reads as broken rather than as hand-built.
@export_range(0.08, 1.5, 0.01) var roof_plank_width: float = 0.58: set = _set_plank_w
@export_range(0.0, 0.5, 0.01) var roof_ragged: float = 0.2: set = _set_ragged

## The floorboards. Thin, so the step up from the grass is barely a step.
@export_range(0.02, 0.4, 0.01) var floor_thick: float = 0.06: set = _set_floor_thick
@export_range(0.5, 8.0, 0.1) var w_depth: float = 3.4: set = _set_w_depth
## Cap the shed at both ends of W, so it is a closed room in four dimensions and not a
## 3D shed stretched through the fourth. See _close_in_w.
@export var close_in_w: bool = true: set = _set_close

@export_group("Door")
@export_range(0.5, 3.0, 0.05) var door_width: float = 1.3: set = _set_door_w
@export_range(1.0, 3.0, 0.05) var door_height: float = 2.05: set = _set_door_h
## Which gable the door is in: +1 for the +X end, -1 for the -X end.
@export_enum("Plus X:1", "Minus X:-1") var door_side: int = -1: set = _set_door_side

## Where the doorway is, in world space, a step OUTSIDE the wall.
##
## OUTSIDE, NOT ON THE THRESHOLD. Whatever uses this parks itself here, and a point in the
## plane of the wall is a point inside the keep-out that surrounds the building - so a cat
## sent to the threshold gets shoved back out of it on the same frame and stands there
## jittering against its own front door.
func door_point(step_out: float = 0.55) -> Vector4:
	var reach: float = length * 0.5 + step_out
	return global_position + global_basis * Vector4(float(door_side) * reach, 0.0, 0.0, 0.0)


## Half the footprint, in the building's own frame, for anything that has to stay out of
## it. Walls are thin and centred on these, so this is the middle of the wall rather than
## its outside face - close enough for keeping an animal out, and the clearance the caller
## adds covers the difference.
func footprint_half() -> Vector2:
	return Vector2(length * 0.5, width * 0.5)


@export_group("Cutaway")
## The camera to hide walls away from. Without it, the cutaway takes the roof and the door
## wall and leaves the rest - still better than a closed box, but only from one side.
@export var camera_path: NodePath

@export_group("Look")
@export var wall_color: Color = Color(0.26, 0.20, 0.18): set = _set_a
@export var frame_color: Color = Color(0.19, 0.15, 0.14): set = _set_b
@export var roof_color: Color = Color(0.17, 0.13, 0.12): set = _set_c
@export var floor_color: Color = Color(0.22, 0.17, 0.16): set = _set_d

## Filled by rebuild. The roof always goes while open; a wall goes only when it is in the
## way. Each entry is {node, out} - the part and the direction it faces outwards, in local
## space, which is all the test needs.
var _roof_parts: Array[Node4D] = []
var _walls: Array = []
var _door_wall: Node4D
var _open: bool = false
var _camera: Node4D


func _set_close(v: bool) -> void: close_in_w = v; _later()
func _set_length(v: float) -> void: length = v; _later()
func _set_width(v: float) -> void: width = v; _later()
func _set_wall_height(v: float) -> void: wall_height = v; _later()
func _set_ridge(v: float) -> void: ridge_rise = v; _later()
func _set_eaves(v: float) -> void: eaves = v; _later()
func _set_roof_drop(v: float) -> void: roof_drop = v; _later()
func _set_thick(v: float) -> void: wall_thick = v; _later()
func _set_floor_thick(v: float) -> void: floor_thick = v; _later()
func _set_plank_w(v: float) -> void: roof_plank_width = v; _later()
func _set_ragged(v: float) -> void: roof_ragged = v; _later()
func _set_w_depth(v: float) -> void: w_depth = v; _later()
func _set_door_w(v: float) -> void: door_width = v; _later()
func _set_door_h(v: float) -> void: door_height = v; _later()
func _set_door_side(v: int) -> void: door_side = v; _later()
func _set_a(v: Color) -> void: wall_color = v; _later()
func _set_b(v: Color) -> void: frame_color = v; _later()
func _set_c(v: Color) -> void: roof_color = v; _later()
func _set_d(v: Color) -> void: floor_color = v; _later()


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Node4D
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_roof_parts.clear()
	_walls.clear()
	_door_wall = null

	var half_x: float = length * 0.5
	var half_z: float = width * 0.5

	_box(self, "Floor", Vector4(0.0, floor_thick * 0.5, 0.0, 0.0),
		Vector3(length, floor_thick, width), floor_color)

	# The two long walls. Each remembers which way it faces out, which is all the cutaway
	# needs in order to decide whether it is in the way.
	for sz in [-1.0, 1.0]:
		var long_wall: Node4D = _box(self, "LongWall%s" % _tag(sz),
			Vector4(0.0, wall_height * 0.5, sz * half_z, 0.0),
			Vector3(length, wall_height, wall_thick), wall_color)
		_walls.append({"node": long_wall, "out": Vector4(0.0, 0.0, sz, 0.0)})

	# The gable ends. The door side is three pieces around the opening.
	for sx in [-1.0, 1.0]:
		var near: bool = int(sx) == door_side
		var group := Node4D.new()
		group.name = "GableEnd%s" % _tag(sx)
		add_child(group)
		_own(group)
		group.position = Vector4(sx * half_x, 0.0, 0.0, 0.0)
		if near:
			var side: float = (width - door_width) * 0.5
			if side > 0.02:
				for sz in [-1.0, 1.0]:
					_box(group, "Jamb%s" % _tag(sz),
						Vector4(0.0, wall_height * 0.5, sz * (door_width * 0.5 + side * 0.5), 0.0),
						Vector3(wall_thick, wall_height, side), wall_color)
			_box(group, "Header",
				Vector4(0.0, (wall_height + door_height) * 0.5, 0.0, 0.0),
				Vector3(wall_thick, wall_height - door_height, door_width), wall_color)
			_door_wall = group
		else:
			_box(group, "Panel", Vector4(0.0, wall_height * 0.5, 0.0, 0.0),
				Vector3(wall_thick, wall_height, width), wall_color)
			_walls.append({"node": group, "out": Vector4(sx, 0.0, 0.0, 0.0)})

	if close_in_w:
		_close_in_w()
	_roof()
	_update_cutaway()


## THE TWO WALLS A 3D BUILDING NEVER HAS. A room in 4D is bounded by eight walls, not four:
## minus and plus x, y, z AND w. This shed had six of them - four walls, a floor and a roof,
## each stretched through W - and nothing capping it at either end of W. So stepping along
## W out of its slab, or turning the slice so W came into view, looked straight out of the
## side of the building into the field: Trym, 25 Sept, "the house suffers the same fate as
## the pen in terms of being 'holey' in 4D".
##
## These are the other two. Each is the shed's whole footprint, full height, but thin in W,
## sitting just inside the ends of the slab. From the home slice you never see them - they
## are nowhere near w = 0 - which is right, since nothing is missing from there. Strafe to
## the shed's edge in W and one fills the view the way a wall does when you walk into it;
## turn the slice a quarter through W and they stand where the gable walls stood, closing
## the room from that side too. They go into the cutaway list like the others, with normals
## along W, and the cutaway's dot product is already four-dimensional, so it hides the near
## one from a rotated camera exactly as it hides a near side wall from an ordinary one.
func _close_in_w() -> void:
	var half_w: float = w_depth * 0.5 - wall_thick * 0.5
	for sw in [-1.0, 1.0]:
		var cap: Node4D = _box(self, "WWall%s" % _tag(sw), Vector4(0.0, wall_height * 0.5, 0.0, sw * half_w),
			Vector3(length, wall_height, width), wall_color)
		var mesh := (cap as MeshInstance4D).mesh as BoxTetraMesh4D
		var extent: Vector4 = mesh.size
		extent.w = wall_thick
		mesh.size = extent
		_walls.append({"node": cap, "out": Vector4(0.0, 0.0, 0.0, sw)})


## Two planes leaning on the ridge, each a child of a pivot ON the ridge line.
func _roof() -> void:
	var reach: float = width * 0.5 + eaves
	var run: float = sqrt(reach * reach + ridge_rise * ridge_rise)
	var slope: float = atan2(ridge_rise, reach)

	for sz in [-1.0, 1.0]:
		var pivot := Node4D.new()
		pivot.name = "RoofPivot%s" % _tag(sz)
		add_child(pivot)
		_own(pivot)
		pivot.position = Vector4(0.0, wall_height + ridge_rise - roof_drop, 0.0, 0.0)
		# Opposite signs on the two sides, which is the whole of the symmetry.
		pivot.basis = Basis4D.from_yz(sz * slope)
		_plank_roof(pivot, sz, run)
		pivot.visible = not _open
		_roof_parts.append(pivot)

	var ridge: Node4D = _box(self, "Ridge",
		Vector4(0.0, wall_height + ridge_rise - roof_drop + 0.05, 0.0, 0.0),
		Vector3(length + eaves * 2.0, 0.13, 0.20), frame_color)
	ridge.visible = not _open
	_roof_parts.append(ridge)


## Open the building up, or close it again. WHICH walls are hidden is decided every frame
## by _process; this only says whether to.
func set_cutaway(on: bool) -> void:
	_open = on
	for part in _roof_parts:
		if is_instance_valid(part):
			part.visible = not on
	if not on:
		if _door_wall != null and is_instance_valid(_door_wall):
			_door_wall.visible = true
		for wall in _walls:
			var node: Node4D = wall["node"]
			if is_instance_valid(node):
				node.visible = true
		return
	_update_cutaway()


func is_cutaway() -> bool:
	return _open


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _open:
		return
	_update_cutaway()


## A wall is in the way when its outward normal points towards the camera. Four dot
## products a frame; cheaper than reasoning about angles, and right from every side.
func _update_cutaway() -> void:
	if not _open:
		return
	# The doorway is a hole you can see through from anywhere, so it goes regardless -
	# leaving it standing while its neighbours vanish looks like a bug, not a doorway.
	if _door_wall != null and is_instance_valid(_door_wall):
		_door_wall.visible = false
	if _camera == null or not is_instance_valid(_camera):
		return
	var to_camera: Vector4 = _camera.global_position - global_position
	for wall in _walls:
		var node: Node4D = wall["node"]
		if not is_instance_valid(node):
			continue
		var outward: Vector4 = global_basis * (wall["out"] as Vector4)
		node.visible = outward.dot(to_camera) <= 0.0


## One slope, as planks running from the ridge down to the eaves.
##
## Each plank starts AT the ridge and is shortened at its lower end, so the ragged edge
## falls along the eaves where a hand-cut roof would be uneven and the ridge line stays
## straight. Shortening is a repeating pattern plus a bias towards the ends rather than
## anything random: random lengths read as damage, a pattern reads as a roof somebody built
## out of what they had.
func _plank_roof(pivot: Node4D, sz: float, run: float) -> void:
	var span: float = length + eaves * 2.0
	var count: int = maxi(3, int(round(span / roof_plank_width)))
	var step: float = span / float(count)
	for i in count:
		var x: float = -span * 0.5 + step * (float(i) + 0.5)
		# 0 in the middle of the slope, 1 at either end.
		var toward_end: float = absf(x) / (span * 0.5)
		var pattern: float = [0.0, 0.05, 0.02, 0.08][i % 4]
		var short: float = clampf(pattern + pow(toward_end, 3.0) * roof_ragged, 0.0, 0.6)
		var plank_run: float = run * (1.0 - short)
		# A shade per plank, so the seams read without needing a second material.
		var tint: float = 0.02 * float(i % 3) - 0.02
		var colour := Color(
			clampf(roof_color.r + tint, 0.0, 1.0),
			clampf(roof_color.g + tint, 0.0, 1.0),
			clampf(roof_color.b + tint, 0.0, 1.0))
		_box(pivot, "Plank%d" % i,
			Vector4(x, 0.0, sz * plank_run * 0.5, 0.0),
			Vector3(step * 0.93, 0.10, plank_run), colour)


func _tag(sign: float) -> String:
	return "P" if sign > 0.0 else "N"


func _box(parent: Node, part: String, at: Vector4, size: Vector3, colour: Color) -> Node4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(maxf(size.x, 0.01), maxf(size.y, 0.01), maxf(size.z, 0.01), w_depth)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	_own(node)
	node.position = at
	return node


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
