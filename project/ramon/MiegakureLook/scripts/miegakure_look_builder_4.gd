extends Node4D
## "The Bridge in Another World" - the second Miegakure-style level, and the one
## that fixes the readability hole the wall level could not.
##
## THE PUZZLE. A chasm cuts the platform in two across its whole x width. At most
## w the chasm is genuinely open and walking into it drops you. In ONE 2 m band of
## w the floor continues straight across. So: walk to the chasm edge, rotate 90
## degrees so the ground you see is x-by-w instead of x-by-z, walk along w until
## you are standing in the band where the bridge exists, rotate back, and walk
## across ground that was not there a moment ago.
##
## WHY THIS LEVEL AND NOT ANOTHER WALL. In miegakure_look_builder_3.gd the
## obstacle is a wall thin along z. At 90 degrees the rendered slice is a
## constant-z hyperplane through the ball, and collision stops the ball 0.5 m
## short of the wall, so the wall is NEVER in the slice you rotate into -
## measured, and it renders as a bare grey diamond with no information on it at
## all. The player is asked to walk to a specific w while blind.
##
## Here the puzzle-relevant geometry is the FLOOR, and the floor is the one
## surface present in every slice, at every angle. After rotating you are looking
## straight at the thing you need to navigate. That is the whole reason to prefer
## this shape of puzzle, and it is Marc ten Bosch's own device: "to help players
## understand the game we texture the ground differently at intervals, to group
## parallel worlds together".
##
## FLOOR BANDING. The floor is built as 8 separate 2 m slabs along w rather than
## one slab with a clever texture. That is deliberate: a BoxTetraMesh4D carries a
## fixed PER-CELL UVW unwrap, so a single image gets smeared across whole cells
## instead of banding (hub_demo_lessons.md records that the hard way). Separate
## slabs use the same _add_panel path everything else here already uses. Bands
## alternate grey and white and the bridge band is cyan - light colours
## throughout on purpose, because the chasm reads as a hole by showing the dark
## void through it, and dark floor bands would compete with that read.
##
## THE RAILS also fix a finding the wall level left open. A landmark only survives
## a zw rotation if it spans the range of both z and w, since those are the two
## axes the rotation trades; builder_3's landmark was 1 m deep in z and so
## vanished from the rotated view exactly when it was supposed to be a stable
## reference. These rails span the full z and full w, so they read as the same
## pair of side rails at both angles. They double as the x-axis fall guard, which
## leaves the chasm as the only way to fall - i.e. the only fall is the puzzle.

const BAND_COUNT := 8
const BAND_W_SIZE := 2.0
const W_HALF_EXTENT := BAND_COUNT * BAND_W_SIZE * 0.5
## Band 1 spans w -6..-4, so its centre is w = -5.
const BRIDGE_BAND_INDEX := 1

const PLATFORM_X_SIZE := 16.0
const FLOOR_THICKNESS := 1.5
const PLATFORM_Z_MIN := -8.0
const PLATFORM_Z_MAX := 8.0
## The chasm, 4 m across. Wide enough that it cannot be crossed by accident and
## reads unmistakably as a hole from the diorama camera.
const CHASM_Z_MIN := -5.0
const CHASM_Z_MAX := -1.0

const RAIL_X := 7.0
const RAIL_X_SIZE := 2.0
## 0.6 m with no step-up logic anywhere in CharacterBody4D means this is a wall,
## not a kerb - which is what makes it a reliable x-axis barrier.
const RAIL_HEIGHT := 0.6

const GOAL_X_SIZE := 6.0
## Square in z and w on purpose. builder_3's goal pad is 3 m in z but 16 m in w,
## and an oblique slice therefore sweeps between two very differently sized
## cross-sections and visibly balloons mid-rotation. Matching the two extents is
## the same fix that stopped the platform itself expanding.
const GOAL_Z_SIZE := 3.0
const GOAL_W_SIZE := 3.0
const GOAL_HEIGHT := 3.0

const BandTextureA := preload("res://textures/dev_finals/ramdev_grey.png")
const BandTextureB := preload("res://textures/dev_finals/ramdev_white.png")
const BridgeTexture := preload("res://textures/dev_finals/ramdev_cyan.png")
const RailTexture := preload("res://textures/dev_finals/ramdev_black_metal.png")
const GoalTexture := preload("res://textures/dev_finals/ramdev_red.png")

## Cyan, matching the bridge band's own floor texture, so the marker on the gauge
## and the lane on the ground are recognisably the same thing.
const BRIDGE_GAUGE_COLOR := Color(0.35, 0.85, 0.9, 0.85)

@onready var ball: CharacterBody4D = $"../Ball"
@onready var goal_banner: Control = $"../GoalBanner"

var _goal_area: Area4D


func _ready() -> void:
	for band_index in BAND_COUNT:
		_build_band(band_index)
	_build_rails()
	_build_goal()


## Centre of band [param band_index] along w. Band 0 is the most negative.
func band_center_w(band_index: int) -> float:
	return -W_HALF_EXTENT + BAND_W_SIZE * (float(band_index) + 0.5)


## Read by w_readout_3.gd, which is shared with the wall level - it asks the
## builder node for these rather than naming a script type, so the same gauge
## works for both levels with no changes. Here the "gap" is the bridge band.
func get_w_half_extent() -> float:
	return W_HALF_EXTENT


func get_gap_w() -> float:
	return band_center_w(BRIDGE_BAND_INDEX)


func get_gap_half_width() -> float:
	return BAND_W_SIZE * 0.5


func get_gap_color() -> Color:
	return BRIDGE_GAUGE_COLOR


## The bridge band gets one unbroken slab spanning the whole platform. Every other
## band gets two, with the chasm's width simply absent between them - the hole is
## missing geometry, not a hole cut into geometry.
func _build_band(band_index: int) -> void:
	var center_w: float = band_center_w(band_index)
	var floor_y: float = -FLOOR_THICKNESS * 0.5

	if band_index == BRIDGE_BAND_INDEX:
		var full_z_size: float = PLATFORM_Z_MAX - PLATFORM_Z_MIN
		var full_z_center: float = (PLATFORM_Z_MAX + PLATFORM_Z_MIN) * 0.5
		_add_panel(
			Vector4(0.0, floor_y, full_z_center, center_w),
			Vector4(PLATFORM_X_SIZE, FLOOR_THICKNESS, full_z_size, BAND_W_SIZE),
			_make_material(BridgeTexture))
		return

	var texture: Texture3D = BandTextureA if band_index % 2 == 0 else BandTextureB
	var material := _make_material(texture)

	var near_size: float = PLATFORM_Z_MAX - CHASM_Z_MAX
	var near_center: float = (PLATFORM_Z_MAX + CHASM_Z_MAX) * 0.5
	_add_panel(
		Vector4(0.0, floor_y, near_center, center_w),
		Vector4(PLATFORM_X_SIZE, FLOOR_THICKNESS, near_size, BAND_W_SIZE),
		material)

	var far_size: float = CHASM_Z_MIN - PLATFORM_Z_MIN
	var far_center: float = (CHASM_Z_MIN + PLATFORM_Z_MIN) * 0.5
	_add_panel(
		Vector4(0.0, floor_y, far_center, center_w),
		Vector4(PLATFORM_X_SIZE, FLOOR_THICKNESS, far_size, BAND_W_SIZE),
		material)


## Full z and full w, so they are the same rails from either slice - the "stable
## reference" the technical paper asks for, done properly this time.
func _build_rails() -> void:
	var material := _make_material(RailTexture)
	var z_size: float = PLATFORM_Z_MAX - PLATFORM_Z_MIN
	var z_center: float = (PLATFORM_Z_MAX + PLATFORM_Z_MIN) * 0.5
	var w_size: float = W_HALF_EXTENT * 2.0
	for side in [-1.0, 1.0]:
		_add_panel(
			Vector4(RAIL_X * side, RAIL_HEIGHT * 0.5, z_center, 0.0),
			Vector4(RAIL_X_SIZE, RAIL_HEIGHT, z_size, w_size),
			material)


## Sits on the far side, inside the bridge band's own w range, so crossing the
## bridge lands on it. Deliberately NOT spread across every w: a goal that exists
## at all w would balloon during the rotation, and would also stop the puzzle
## being about arriving at a particular place in 4D.
func _build_goal() -> void:
	var goal_z: float = (CHASM_Z_MIN + PLATFORM_Z_MIN) * 0.5
	var goal_w: float = band_center_w(BRIDGE_BAND_INDEX)

	var pad_mesh := MeshInstance4D.new()
	var pad_box := BoxTetraMesh4D.new()
	pad_box.size = Vector4(GOAL_X_SIZE, 0.1, GOAL_Z_SIZE, GOAL_W_SIZE)
	pad_box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	pad_mesh.mesh = pad_box
	pad_mesh.material_override = _make_material(GoalTexture)
	pad_mesh.position = Vector4(0.0, 0.05, goal_z, goal_w)
	add_child(pad_mesh)

	_goal_area = Area4D.new()
	_goal_area.position = Vector4(0.0, GOAL_HEIGHT * 0.5, goal_z, goal_w)
	add_child(_goal_area)
	var collision_shape := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = Vector4(GOAL_X_SIZE, GOAL_HEIGHT, GOAL_Z_SIZE, GOAL_W_SIZE)
	collision_shape.shape = shape
	_goal_area.add_child(collision_shape)
	_goal_area.body_entered_self.connect(_on_goal_entered)


func _make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	material.albedo_texture_3d = texture
	return material


func _add_panel(position: Vector4, size: Vector4, material: TetraMaterial4D) -> void:
	var body := StaticBody4D.new()
	body.position = position
	add_child(body)

	var collision_shape := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)

	var mesh_instance := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	mesh.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)


func _on_goal_entered(body: PhysicsBody4D) -> void:
	if body != ball:
		return
	goal_banner.show_goal_reached()
