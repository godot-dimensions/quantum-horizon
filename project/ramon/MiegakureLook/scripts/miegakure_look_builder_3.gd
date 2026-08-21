extends Node4D
## v3 of the "Wall Around the Fourth" level. Geometry is UNCHANGED from
## miegakure_look_builder_2.gd - same platform, same wall with a finite w-gap,
## same goal pad, same landmark, same numbers. Only two things differ, and both
## are about the level being readable by other scripts rather than about the
## level itself:
##
## 1. No class_name. See w_readout_3.gd for the measured failure.
## 2. The three numbers the HUD needs are exposed as getter METHODS, so the HUD
##    reads them off this node at runtime instead of naming this script at parse
##    time.
##
## Deliberately NOT fixed here, because they are separate findings and were not
## part of the three changes asked for (all recorded in
## follow_up/miegakure_look.md): the goal pad's z extent (3) still does not
## match its w extent (16), so it balloons mid-rotation; the landmark is still
## only 1 m deep in z, so it drops out of the rotated slice exactly when it is
## supposed to be a stable reference; and the floor is still uniform grey rather
## than banded along w.

const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.4
## Matching the w extent to the platform's own x/z extent (16) is what stops the
## platform visibly expanding from 16-wide to 24-wide mid-rotation, which is what
## a larger w extent than z extent necessarily causes.
const STRUCTURE_W_HALF_EXTENT := 8.0
const PLATFORM_SIZE := Vector4(16.0, 1.5, 16.0, STRUCTURE_W_HALF_EXTENT * 2.0)
const GATE_GAP_HALF_WIDTH := 1.5
## NEGATIVE: Basis4D::from_zw's generated matrix (basis.z.w = sin, basis.w.z =
## -sin - see engine/modules/4d/math/basis_4d.cpp's FROM_SINGLE_ANGLE macro)
## sends the camera's z-column toward +w at a +90 degree rotation. Forward is the
## NEGATION of that column, so walking forward after rotating moves toward -w.
## The gap has to sit on the -w side to be reachable by walking forward.
const GATE_GAP_W := -6.0
const GOAL_CENTER_Z := -5.0

const LANDMARK_HEIGHT := 5.0
const LANDMARK_FOOTPRINT := 1.0
const LANDMARK_POSITION := Vector2(6.0, 6.0) # x, z - same side as spawn.

## Grey, not blue - matches hub_palette.gd's convention (structure/floors = grey,
## blue is reserved for signage only).
const FloorTexture := preload("res://textures/dev_finals/ramdev_grey.png")
const WallTexture := preload("res://textures/dev_finals/ramdev_yellow.png")
const GoalTexture := preload("res://textures/dev_finals/ramdev_red.png")
const LandmarkTexture := preload("res://textures/dev_finals/ramdev_black_metal.png")

## Matches ramdev_yellow, the wall's own texture colour.
const GAP_GAUGE_COLOR := Color(0.886, 0.949, 0.322, 0.85)

@onready var ball: CharacterBody4D = $"../Ball"
@onready var goal_banner: Control = $"../GoalBanner"

var _goal_area: Area4D


func _ready() -> void:
	_add_panel(Vector4(0, -0.75, 0, 0), PLATFORM_SIZE, _make_material(FloorTexture))
	_build_bypass_wall()
	_build_goal()
	_build_landmark()


## The three numbers w_readout_3.gd needs to draw its gauge. Methods rather than
## direct const reads so the HUD never has to name this script's type - a
## cross-script `class_name` constant read is a PARSE-time dependency, and it
## took the entire v2 HUD down when the global class cache did not have the
## builder registered.
func get_w_half_extent() -> float:
	return STRUCTURE_W_HALF_EXTENT


func get_gap_w() -> float:
	return GATE_GAP_W


func get_gap_half_width() -> float:
	return GATE_GAP_HALF_WIDTH


## The wall's own yellow, so the band on the gauge and the wall on the ground read
## as the same object. Added so w_readout_3.gd can serve this level and the chasm
## level (builder_4, where the highlighted band is a cyan bridge) without either
## one hard-coding the other's colour.
func get_gap_color() -> Color:
	return GAP_GAUGE_COLOR


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


## Solid across the full platform width at every w except a
## GATE_GAP_HALF_WIDTH*2 window centred on GATE_GAP_W - same trick as
## PhaseMaze/ImpossibleBypass's gate walls.
func _build_bypass_wall() -> void:
	var material := _make_material(WallTexture)
	var near_half: float = (GATE_GAP_W + STRUCTURE_W_HALF_EXTENT - GATE_GAP_HALF_WIDTH) * 0.5
	var far_half: float = (STRUCTURE_W_HALF_EXTENT - GATE_GAP_W - GATE_GAP_HALF_WIDTH) * 0.5
	if near_half > 0.01:
		var near_center_w: float = -STRUCTURE_W_HALF_EXTENT + near_half
		_add_panel(Vector4(0, WALL_HEIGHT * 0.5, 0, near_center_w), Vector4(PLATFORM_SIZE.x, WALL_HEIGHT, WALL_THICKNESS, near_half * 2.0), material)
	if far_half > 0.01:
		var far_center_w: float = GATE_GAP_W + GATE_GAP_HALF_WIDTH + far_half
		_add_panel(Vector4(0, WALL_HEIGHT * 0.5, 0, far_center_w), Vector4(PLATFORM_SIZE.x, WALL_HEIGHT, WALL_THICKNESS, far_half * 2.0), material)


func _build_goal() -> void:
	var full_w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0
	var footprint := Vector2(PLATFORM_SIZE.x - 2.0, 3.0)

	var pad_mesh := MeshInstance4D.new()
	var pad_box := BoxTetraMesh4D.new()
	pad_box.size = Vector4(footprint.x, 0.1, footprint.y, full_w_size)
	pad_box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	pad_mesh.mesh = pad_box
	pad_mesh.material_override = _make_material(GoalTexture)
	pad_mesh.position = Vector4(0, 0.05, GOAL_CENTER_Z, 0)
	add_child(pad_mesh)

	_goal_area = Area4D.new()
	_goal_area.position = Vector4(0, WALL_HEIGHT * 0.5, GOAL_CENTER_Z, 0)
	add_child(_goal_area)
	var collision_shape := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = Vector4(footprint.x, WALL_HEIGHT, footprint.y, full_w_size)
	collision_shape.shape = shape
	_goal_area.add_child(collision_shape)
	_goal_area.body_entered_self.connect(_on_goal_entered)


func _build_landmark() -> void:
	var full_w_size: float = STRUCTURE_W_HALF_EXTENT * 2.0
	var size := Vector4(LANDMARK_FOOTPRINT, LANDMARK_HEIGHT, LANDMARK_FOOTPRINT, full_w_size)
	_add_panel(Vector4(LANDMARK_POSITION.x, LANDMARK_HEIGHT * 0.5, LANDMARK_POSITION.y, 0), size, _make_material(LandmarkTexture))


func _on_goal_entered(body: PhysicsBody4D) -> void:
	if body != ball:
		return
	goal_banner.show_goal_reached()
