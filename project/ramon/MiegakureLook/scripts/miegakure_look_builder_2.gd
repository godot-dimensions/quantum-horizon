extends Node4D
class_name MiegakureLookBuilder2
## "Wall Around the Fourth" mechanic - the technical paper's own worked
## example (see project/ramon/follow_up/, and chat history) on the SAME
## bounded platform as miegakure_look_builder.gd, now paired with
## MiegakureCamera2's discrete 90-degree rotation instead of continuous
## dragging: a wall blocks the direct path at w=0, rotate 90 degrees so
## "forward" means walking along w instead of z, cross the wall's w-gap,
## rotate back, walk through where the wall no longer is.
##
## Same finite-w "solid everywhere except a window" trick as PhaseMaze's
## gates and ImpossibleBypass's wall (impossible_bypass_builder.gd) -
## reused directly rather than reinvented. Uses real lighting (Aaron's
## WorldEnvironment4D/DirectionalLight4D, same as miegakure_look.tscn),
## not the flat-shaded unlit trick.

const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.4
## "Keep the endpoints square-ish" - matching this to the platform's own
## x/z extent (16) is the fix for a real artifact Ramon spotted: with a
## LARGER w-extent (24, the original value) than z-extent (16), rotating
## from a pure-z view toward a pure-w view necessarily grows the visible
## footprint from 16-wide to 24-wide along the way, since you're sweeping
## between two differently-sized cross-sections of the same box. Matching
## them removes that asymmetry, so the platform should read as stationary
## through the rotation instead of visibly expanding.
const STRUCTURE_W_HALF_EXTENT := 8.0
const PLATFORM_SIZE := Vector4(16.0, 1.5, 16.0, STRUCTURE_W_HALF_EXTENT * 2.0)
const GATE_GAP_HALF_WIDTH := 1.5
## Rotate, walk forward (= walk in w) to roughly here, then rotate back.
## NEGATIVE: Basis4D::from_zw's generated matrix (basis.z.w = sin, basis.w.z
## = -sin - see engine/modules/4d/math/basis_4d.cpp's FROM_SINGLE_ANGLE
## macro) sends the camera's z-column (used as "backward" for movement,
## per this codebase's forward = -basis.z convention) toward +w at a +90
## degree rotation. Since "forward" is the NEGATION of that column, walking
## forward after rotating actually moves toward -w, not +w - confirmed by
## tracing the exact matrix, not assumed. The gap has to sit on the -w side
## to be reachable by walking forward.
const GATE_GAP_W := -6.0
const GOAL_CENTER_Z := -5.0

## A fixed reference point near spawn, on the x/z plane the zw rotation
## NEVER touches - the paper's own "stable references" recommendation for
## fighting disorientation (section 6): at least one landmark that stays
## recognizable through the transition. Tall enough to stay visible over
## the wall from either side. Uses the SAME "match z and w extent" fix that
## solved the platform's own expansion artifact, so its shape stays as
## constant as the platform's does, not just its x/z position.
const LANDMARK_HEIGHT := 5.0
const LANDMARK_FOOTPRINT := 1.0
const LANDMARK_POSITION := Vector2(6.0, 6.0) # x, z - same side as spawn.

## Grey, not blue - matches hub_palette.gd's established convention
## (structure/floors = grey, blue is reserved for signage only).
const FloorTexture := preload("res://textures/dev_finals/ramdev_grey.png")
const WallTexture := preload("res://textures/dev_finals/ramdev_yellow.png")
const GoalTexture := preload("res://textures/dev_finals/ramdev_red.png")
const LandmarkTexture := preload("res://textures/dev_finals/ramdev_black_metal.png")

@onready var ball: CharacterBody4D = $"../Ball"
@onready var goal_banner: Control = $"../GoalBanner"

var _goal_area: Area4D


func _ready() -> void:
	_add_panel(Vector4(0, -0.75, 0, 0), PLATFORM_SIZE, _make_material(FloorTexture))
	_build_bypass_wall()
	_build_goal()
	_build_landmark()


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
## PhaseMaze/ImpossibleBypass's gate walls, just placed on this platform.
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
