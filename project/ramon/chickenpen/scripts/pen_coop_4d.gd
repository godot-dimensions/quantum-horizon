@tool
extends Node4D

## The chicken house: a readable coop rather than a box (item 45).
##
## Built from a handful of numbers rather than fully proceduralised, which is exactly
## what item 49 asks for - the FENCE needs to resize to any dimensions, the coop only
## needs enough flexibility to sit in the pen it is given. So this has a size, a roof
## pitch and a doorway, and nothing else is parameterised.
##
## WHAT MAKES IT READ AS A COOP rather than a shed is the silhouette (item 46): a body
## that is wider than it is tall, a pitched roof overhanging it, a chicken-sized opening
## low in the front, and a ramp down to the ground. Those four things at low poly are
## enough; texture would add nothing at this size.

@export var body_size: Vector3 = Vector3(2.4, 1.3, 1.8): set = _set_body
@export_range(0.1, 1.5, 0.05) var roof_rise: float = 0.55: set = _set_roof
@export_range(0.2, 1.2, 0.05) var door_width: float = 0.55: set = _set_door_w
@export_range(0.2, 1.5, 0.05) var door_height: float = 0.7: set = _set_door_h
@export_range(0.5, 4.0, 0.1) var ramp_length: float = 1.5: set = _set_ramp
## Legs lift the floor so the ramp has something to lean against, as a real coop does.
@export_range(0.0, 1.0, 0.05) var stilt_height: float = 0.35: set = _set_stilt
## How far it reaches through W. Matches the pen so it exists in the same slices.
@export_range(0.5, 12.0, 0.1) var w_depth: float = 3.0: set = _set_w
## Cap it at both ends of W, so it is a closed hut in four dimensions.
@export var close_in_w: bool = true: set = _set_close
## THE WALLS BY THE FENCE TECH (Ramon, 7 Oct: "ramake penhouse with the fence set where possible. but make
## it look like the original house. no weird stuff. test proper"). The coop's floor plan is a box in x, z
## and W; its six faces are the seed of one FenceGenerator4D, as the town wall's and the range yard's
## are: a post at every corner and either side of the door, a plate along every edge at the eaves, and
## each face filled as a solid wall from the floor to the eaves. So it is the same hut, the same size and
## colours, closed at both ends of W as before, but framed as the fence is, posts that hold as the slice
## turns. The front is two faces either side of the doorway (the door goes through W, as it did), the
## lintel over it a box; roof, ridge, floor, stilts and ramp are boxes as before. Off: the walls as boxes.
@export var fence_walls: bool = true: set = _set_fence_walls

## Weathered planks, as the fence (was 0.72/0.56/0.38, orange under the low sun).
@export var wall_color: Color = Color(0.54, 0.47, 0.39): set = _set_wall_color
@export var roof_color: Color = Color(0.42, 0.26, 0.20): set = _set_roof_color

## Idle targets a penned chicken can be sent to (item 48), as offsets FROM THE COOP.
## Stored as offsets rather than positions because rebuild() can run before the node has
## its final place in the world; idle_points() resolves them when they are actually asked
## for, which cannot be too early.
var interest_points: Array = []


func _set_body(v: Vector3) -> void: body_size = v; _rebuild_later()
func _set_roof(v: float) -> void: roof_rise = v; _rebuild_later()
func _set_door_w(v: float) -> void: door_width = v; _rebuild_later()
func _set_door_h(v: float) -> void: door_height = v; _rebuild_later()
func _set_ramp(v: float) -> void: ramp_length = v; _rebuild_later()
func _set_stilt(v: float) -> void: stilt_height = v; _rebuild_later()
func _set_w(v: float) -> void: w_depth = v; _rebuild_later()
func _set_close(v: bool) -> void: close_in_w = v; _rebuild_later()
func _set_fence_walls(v: bool) -> void: fence_walls = v; _rebuild_later()
func _set_wall_color(v: Color) -> void: wall_color = v; _rebuild_later()
func _set_roof_color(v: Color) -> void: roof_color = v; _rebuild_later()


func _ready() -> void:
	rebuild()


func _rebuild_later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	interest_points.clear()

	var wall := TetraMaterial4D.new()
	wall.albedo_color = wall_color
	var roof := TetraMaterial4D.new()
	roof.albedo_color = roof_color

	var floor_y: float = stilt_height
	var half: Vector3 = body_size * 0.5

	# Four legs, so the coop stands rather than sits.
	if stilt_height > 0.01:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box("Stilt_%d_%d" % [int(sx), int(sz)],
					Vector4(sx * (half.x - 0.12), stilt_height * 0.5, sz * (half.z - 0.12), 0.0),
					Vector3(0.14, stilt_height, 0.14), wall)

	# The body, split either side of the doorway so the opening is a real gap rather
	# than a painted-on rectangle.
	if fence_walls:
		_fence_walls(wall, floor_y, half)
	else:
		_box_walls(wall, floor_y, half)
	_box("Floor", Vector4(0.0, floor_y, 0.0, 0.0), Vector3(body_size.x, 0.12, body_size.z), wall)
	_roof_and_ramp(wall, roof, floor_y, half)


## The walls as they were built first: boxes, the front split round the door, two caps in W.
func _box_walls(wall: TetraMaterial4D, floor_y: float, half: Vector3) -> void:
	var front_z: float = half.z
	var side_width: float = (body_size.x - door_width) * 0.5
	for sx in [-1.0, 1.0]:
		_box("Front_%s" % ("L" if sx < 0.0 else "R"),
			Vector4(sx * (door_width * 0.5 + side_width * 0.5), floor_y + half.y, front_z - 0.08, 0.0),
			Vector3(side_width, body_size.y, 0.16), wall)
	# Lintel above the door.
	var lintel: float = body_size.y - door_height
	if lintel > 0.05:
		_box("Lintel", Vector4(0.0, floor_y + door_height + lintel * 0.5, front_z - 0.08, 0.0),
			Vector3(door_width, lintel, 0.16), wall)
	_box("Back", Vector4(0.0, floor_y + half.y, -front_z + 0.08, 0.0),
		Vector3(body_size.x, body_size.y, 0.16), wall)
	for sx in [-1.0, 1.0]:
		_box("Side_%s" % ("L" if sx < 0.0 else "R"),
			Vector4(sx * (half.x - 0.08), floor_y + half.y, 0.0, 0.0),
			Vector3(0.16, body_size.y, body_size.z), wall)

	# THE TWO WALLS A 3D HUT NEVER HAS - the coop was a box open at both ends of W, the
	# same "holey" Trym found in the house. See pen_shed_4d._close_in_w for the whole
	# argument; the short form is that a room in 4D has eight walls and this had six.
	if close_in_w:
		for sw in [-1.0, 1.0]:
			var cap := _box("WWall_%s" % ("P" if sw > 0.0 else "N"),
				Vector4(0.0, floor_y + half.y, 0.0, sw * (w_depth * 0.5 - 0.08)),
				Vector3(body_size.x, body_size.y, body_size.z), wall)
			var mesh := cap.mesh as BoxTetraMesh4D
			var extent: Vector4 = mesh.size
			extent.w = 0.16
			mesh.size = extent


## The walls by the fence tech (see fence_walls): the floor plan's faces as the seed.
func _fence_walls(wall: TetraMaterial4D, floor_y: float, half: Vector3) -> void:
	var hw: float = w_depth * 0.5 - 0.08 if close_in_w else w_depth * 0.5
	var hx: float = half.x - 0.08
	var hz: float = half.z - 0.08
	var thick: float = 0.16
	# THE FRAME SHOWS, ON PURPOSE. The rails (in the farm's slice: the corner posts, the door's frame, the
	# plate under the eaves) were first 0.19 against walls 0.16, then as thick, then thinner and inside:
	# every time a centimetre or two from the walls' faces, and at that the cross-section's depth cannot
	# tell them apart and draws dashes down every corner (frames coop, 7 Oct). 6 cm wider than the walls,
	# 3 cm proud each side, they read as what a coop has, a frame, a touch darker, as the fence's posts
	# are against its rails; and nothing flickers.
	var rail: float = thick + 0.06
	var post: float = rail / 0.95
	# The rails either side of the door stand on its edges: half a rail out, so the opening is door_width.
	var dx: float = door_width * 0.5 + rail * 0.5
	var seed := ArrayPolyMesh4D.new()
	var verts: Dictionary = {}
	var edges: Dictionary = {}
	var vert := func(x: float, z: float, w: float) -> int:
		var key := "%.3f|%.3f|%.3f" % [x, z, w]
		if not verts.has(key):
			verts[key] = seed.append_vertex(Vector4(x, 0.0, z, w))
		return verts[key]
	var face := func(loop: Array) -> void:
		var ids: Array = []
		for p in loop:
			ids.append(vert.call(p.x, p.y, p.z))
		var cell := PackedInt32Array()
		for i in ids.size():
			var a: int = ids[i]
			var b: int = ids[(i + 1) % ids.size()]
			var key := "%d|%d" % [mini(a, b), maxi(a, b)]
			if not edges.has(key):
				edges[key] = seed.append_edge_indices(a, b)
			cell.append(edges[key])
		seed.append_poly_cell(2, cell)
	# The sides (x), the back, the front either side of the door (z), and, closed in W, the two ends.
	for sx in [-1.0, 1.0]:
		face.call([Vector3(sx * hx, -hz, -hw), Vector3(sx * hx, hz, -hw), Vector3(sx * hx, hz, hw), Vector3(sx * hx, -hz, hw)])
	face.call([Vector3(-hx, -hz, -hw), Vector3(hx, -hz, -hw), Vector3(hx, -hz, hw), Vector3(-hx, -hz, hw)])
	face.call([Vector3(-hx, hz, -hw), Vector3(-dx, hz, -hw), Vector3(-dx, hz, hw), Vector3(-hx, hz, hw)])
	face.call([Vector3(dx, hz, -hw), Vector3(hx, hz, -hw), Vector3(hx, hz, hw), Vector3(dx, hz, hw)])
	if close_in_w:
		for sw in [-1.0, 1.0]:
			face.call([Vector3(-hx, -hz, sw * hw), Vector3(hx, -hz, sw * hw), Vector3(hx, hz, sw * hw), Vector3(dx, hz, sw * hw),
				Vector3(-dx, hz, sw * hw), Vector3(-hx, hz, sw * hw)])
	var f := FenceGenerator4D.new()
	f.name = "Walls"
	f.update_automatically = false
	f.output_mesh_type = FenceGenerator4D.OUTPUT_MESH_TETRA
	f.input_shape_type = FenceGenerator4D.INPUT_SHAPE_SEED_MESH_4D
	f.seed_mesh_4d = seed
	f.post_height_meters = body_size.y
	f.post_thickness_meters = post
	f.rib_height_ratio = 0.999
	f.rib_thickness_ratio = 0.95
	f.beam_count = 1
	f.beam_max_height_ratio = 0.999
	f.beam_coverage = 1.0
	f.beam_thickness_ratio = thick / rail
	f.desired_spacing_meters = 0.0
	var frame := TetraMaterial4D.new()
	frame.albedo_color = wall_color.darkened(0.1)
	f.post_material = frame
	f.rib_material = frame
	f.beam_material = wall
	add_child(f)
	f.position = Vector4(0.0, floor_y, 0.0, 0.0)
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		f.owner = get_tree().edited_scene_root
	f.update_fence_mesh_now()
	# The lintel over the door, through W as the door is.
	var lintel: float = body_size.y - door_height
	if lintel > 0.05:
		_box("Lintel", Vector4(0.0, floor_y + door_height + lintel * 0.5, half.z - 0.08, 0.0),
			Vector3(door_width, lintel, thick), wall)


func _roof_and_ramp(wall: TetraMaterial4D, roof: TetraMaterial4D, floor_y: float, half: Vector3) -> void:
	var front_z: float = half.z
	# A pitched roof in two slabs, overhanging on every side.
	var eave: float = 0.18
	var roof_y: float = floor_y + body_size.y
	for sz in [-1.0, 1.0]:
		var slab := _box("Roof_%s" % ("F" if sz > 0.0 else "B"),
			Vector4(0.0, roof_y + roof_rise * 0.5, sz * (half.z * 0.5), 0.0),
			Vector3(body_size.x + eave * 2.0, 0.12, body_size.z * 0.62), roof)
		# Tilted so the two slabs meet at the ridge.
		var pitch: float = atan2(roof_rise, body_size.z * 0.5) * sz
		slab.basis = Basis4D.from_yz(pitch)

	_box("Ridge", Vector4(0.0, roof_y + roof_rise + 0.04, 0.0, 0.0),
		Vector3(body_size.x + eave * 2.0, 0.1, 0.16), roof)

	# The ramp, from the doorway down to the ground.
	#
	# THE SIGN WAS THE WRONG WAY ROUND AND IT SHOWED. A negative from_yz lifts the +Z end,
	# which is the note theatre_stage_4d carries about its aisle and which is right THERE,
	# because the theatre's aisle climbs towards +Z. This one runs the other way: the
	# doorway is at front_z and the plank reaches OUT from it, so its +Z end is the end
	# lying in the grass. Lifting that one put the high end in the field and the low end
	# at the door - a plank sloping away from the coop, not touching it, which is exactly
	# what Ramon reported seeing: "weird, inverted, doesn't lead to the entry doorway".
	#
	# So the angle is positive here and negative there, and neither is a typo. The rule is
	# about which END is uphill, not about which function you called.
	if ramp_length > 0.1 and stilt_height > 0.01:
		var ramp := _box("Ramp",
			Vector4(0.0, floor_y * 0.5, front_z + ramp_length * 0.45, 0.0),
			Vector3(door_width * 1.2, 0.08, ramp_length), wall)
		ramp.basis = Basis4D.from_yz(atan2(floor_y, ramp_length))

	# Item 48: a few places a penned chicken can choose to stand, near the ramp and the
	# doorway, so the coop is somewhere they relate to rather than scenery.
	interest_points = [
		Vector4(0.0, 0.0, front_z + ramp_length * 0.9, 0.0),
		Vector4(-half.x * 0.7, 0.0, front_z + 0.5, 0.0),
		Vector4(half.x * 0.7, 0.0, front_z + 0.5, 0.0),
	]


## Where a penned chicken might choose to stand, in world space (item 48). Turned with the coop (7 Oct:
## layout B turned it a quarter to the west, and the points stayed east of it, by the fence).
func idle_points() -> Array:
	var here: Vector4 = global_position
	var turn: Projection = global_basis
	return interest_points.map(func(offset: Vector4) -> Vector4: return here + turn * offset)


func _box(part: String, at: Vector4, size: Vector3, material: TetraMaterial4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(size.x, size.y, size.z, w_depth)
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.position = at
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
	return node
