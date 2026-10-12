extends Node4D
## Shared building vocabulary for the Miegakure levels in ../levels/.
##
## Extended by each level's builder rather than copied into it, because the three
## levels differ only in where the obstacles are - the floor banding, the rails,
## the goal, the panel construction and the gauge's data feed are identical, and
## keeping three copies in step by hand is how they drift.
##
## No class_name anywhere in this folder, deliberately: global class names resolve
## from .godot/global_script_class_cache.cfg, which only the editor regenerates,
## so a class_name added with the editor closed takes down every script that
## names it (measured - it silently killed the whole v2 HUD). Subclasses use
## `extends "res://..."` by path, which needs no cache.
##
## THE BANDS ARE THE READABILITY DEVICE, and the reason every level here is built
## out of them. The rendered slice at 90 degrees is a constant-z hyperplane, so
## anything thin along z - a wall, a small prop - is simply absent from the view
## you rotate into. The FLOOR is the one surface present in every slice at every
## angle, which makes it the only reliable place to show w. Colouring it in bands
## turns "walk blind toward a number on a gauge" into "walk to the yellow lane".
## This is Marc ten Bosch's own device: "to help players understand the game we
## texture the ground differently at intervals, to group parallel worlds
## together".
##
## Bands are built as separate slabs rather than one slab with a banded texture,
## because a BoxTetraMesh4D carries a fixed PER-CELL UVW unwrap and smears a
## single image across whole cells instead of banding (hub_demo_lessons.md).

const BAND_COUNT := 8
const BAND_W_SIZE := 2.0
const FLOOR_THICKNESS := 1.5

const PLATFORM_X_SIZE := 16.0
const PLATFORM_Z_MIN := -8.0
const PLATFORM_Z_MAX := 8.0

const RAIL_X := 7.0
const RAIL_X_SIZE := 2.0
## 0.6 m against a CharacterBody4D with no step-up logic at all makes this a wall,
## not a kerb - which is exactly what makes it a dependable x-axis fall guard.
const RAIL_HEIGHT := 0.6

const WALL_HEIGHT := 3.0
const WALL_THICKNESS := 0.4

const GOAL_X_SIZE := 6.0
## Square in z and w on purpose. A goal 3 m deep in z but spread across all 16 m
## of w sweeps between two very differently sized cross-sections during the
## rotation and visibly balloons; matching the extents is the same fix that
## stopped the platform itself expanding.
const GOAL_Z_SIZE := 3.0
const GOAL_W_SIZE := 3.0
const GOAL_HEIGHT := 3.0

## Light colours throughout, on purpose: a chasm reads as a hole by showing the
## dark void through it, and dark floor bands would compete with that read.
const TextureBandA := preload("res://textures/dev_finals/ramdev_grey.png")
const TextureBandB := preload("res://textures/dev_finals/ramdev_white.png")
const TextureBridge := preload("res://textures/dev_finals/ramdev_cyan.png")
const TextureGate := preload("res://textures/dev_finals/ramdev_yellow.png")
const TextureRail := preload("res://textures/dev_finals/ramdev_black_metal.png")
const TextureGoal := preload("res://textures/dev_finals/ramdev_red.png")

const LevelFlow = preload("res://ramon/MiegakureLook/scripts/level_flow.gd")
## Long enough to read "LEVEL 2 OF 3 NEXT..." without being a wait.
const GOAL_HOLD_SECONDS := 1.8

## The lane the gauge highlights. Each level sets these in _ready() before it
## builds; w_readout_3.gd reads them back off this node through the getters
## below rather than naming any script type, which is what lets one gauge serve
## every level unchanged.
var highlight_w: float = 0.0
var highlight_half_width: float = BAND_W_SIZE * 0.5
var highlight_color: Color = Color.WHITE

@onready var ball: CharacterBody4D = $"../Ball"
@onready var goal_banner: Control = $"../GoalBanner"

var _completed: bool = false


func w_half_extent() -> float:
	return BAND_COUNT * BAND_W_SIZE * 0.5


## Centre of band [param band_index] along w. Band 0 is the most negative.
func band_center_w(band_index: int) -> float:
	return -w_half_extent() + BAND_W_SIZE * (float(band_index) + 0.5)


func get_w_half_extent() -> float:
	return w_half_extent()


func get_gap_w() -> float:
	return highlight_w


func get_gap_half_width() -> float:
	return highlight_half_width


func get_gap_color() -> Color:
	return highlight_color


## Alternating grey/white so the lanes are countable at a glance from the rotated
## view. Levels override the colour of whichever band is the answer.
func default_band_texture(band_index: int) -> Texture3D:
	return TextureBandA if band_index % 2 == 0 else TextureBandB


## One band's floor, covering [param z_spans] - an array of Vector2(z_min, z_max).
## A band with two spans has a chasm between them; a band with one full span is a
## bridge across it. The hole is missing geometry, not geometry with a hole cut
## into it.
func build_floor_band(band_index: int, texture: Texture3D, z_spans: Array) -> void:
	var center_w: float = band_center_w(band_index)
	var material := make_material(texture)
	for span: Vector2 in z_spans:
		var z_size: float = span.y - span.x
		if z_size <= 0.01:
			continue
		add_panel(
			Vector4(0.0, -FLOOR_THICKNESS * 0.5, (span.x + span.y) * 0.5, center_w),
			Vector4(PLATFORM_X_SIZE, FLOOR_THICKNESS, z_size, BAND_W_SIZE),
			material)


## A full-height wall segment across one band, at [param z_center]. Levels build
## this for every band except the one that is the way through, so the gap lines up
## exactly with a floor lane rather than sitting at an arbitrary w.
func build_wall_band(band_index: int, z_center: float) -> void:
	add_panel(
		Vector4(0.0, WALL_HEIGHT * 0.5, z_center, band_center_w(band_index)),
		Vector4(PLATFORM_X_SIZE, WALL_HEIGHT, WALL_THICKNESS, BAND_W_SIZE),
		make_material(TextureGate))


## Rails spanning the full z AND full w. A landmark only survives a zw rotation if
## it covers the range of both axes the rotation trades - an earlier version was
## 1 m deep in z and so vanished from the rotated view exactly when it was meant
## to be the stable reference. These read as the same pair of side rails at either
## angle, and they double as the x-axis fall guard so that the only way to fall is
## whatever the level intends.
func build_rails() -> void:
	var material := make_material(TextureRail)
	var z_size: float = PLATFORM_Z_MAX - PLATFORM_Z_MIN
	var z_center: float = (PLATFORM_Z_MAX + PLATFORM_Z_MIN) * 0.5
	var w_size: float = w_half_extent() * 2.0
	for side in [-1.0, 1.0]:
		add_panel(
			Vector4(RAIL_X * side, RAIL_HEIGHT * 0.5, z_center, 0.0),
			Vector4(RAIL_X_SIZE, RAIL_HEIGHT, z_size, w_size),
			material)


func build_goal(goal_z: float, goal_w: float) -> void:
	var pad_mesh := MeshInstance4D.new()
	var pad_box := BoxTetraMesh4D.new()
	pad_box.size = Vector4(GOAL_X_SIZE, 0.1, GOAL_Z_SIZE, GOAL_W_SIZE)
	pad_box.cell_texture_map = BoxTetraMesh4D.BOX_CELL_TEXTURE_MAP_FILL_EACH_SIDE
	pad_mesh.mesh = pad_box
	pad_mesh.material_override = make_material(TextureGoal)
	pad_mesh.position = Vector4(0.0, 0.05, goal_z, goal_w)
	add_child(pad_mesh)

	var goal_area := Area4D.new()
	goal_area.position = Vector4(0.0, GOAL_HEIGHT * 0.5, goal_z, goal_w)
	add_child(goal_area)
	var collision_shape := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = Vector4(GOAL_X_SIZE, GOAL_HEIGHT, GOAL_Z_SIZE, GOAL_W_SIZE)
	collision_shape.shape = shape
	goal_area.add_child(collision_shape)
	goal_area.body_entered_self.connect(_on_goal_entered)


func make_material(texture: Texture3D) -> TetraMaterial4D:
	var material := TetraMaterial4D.new()
	material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	material.albedo_texture_3d = texture
	return material


func add_panel(position: Vector4, size: Vector4, material: TetraMaterial4D) -> void:
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
	if _completed:
		return # Area4D can report the same body more than once; only win once.
	_completed = true

	var this_scene: String = _current_scene_path()
	var next_scene: String = LevelFlow.next_scene_path(this_scene)
	var number: int = LevelFlow.level_number(this_scene)

	if next_scene.is_empty():
		goal_banner.show_goal_reached("" if number == 0 else "ALL %d CLEAR" % LevelFlow.total())
		return

	goal_banner.show_goal_reached("LEVEL %d OF %d NEXT..." % [number + 1, LevelFlow.total()])
	_advance_to(next_scene)


## Loads [param next_scene] after a beat, so the banner is actually readable
## rather than a single frame of green.
##
## NOT called straight from the signal. body_entered_self fires inside the
## physics step, and changing scene frees the current scene immediately -
## including the Area4D running this callback and the body the solver is still
## iterating over. That crashes; hub_demo_lessons.md records it from the hub
## gates. A SceneTreeTimer's timeout lands on an idle frame, which is outside the
## physics step, so this is safe as well as being the delay we wanted anyway.
func _advance_to(next_scene: String) -> void:
	var timer := get_tree().create_timer(GOAL_HOLD_SECONDS)
	timer.timeout.connect(func() -> void:
		if not is_inside_tree():
			return # Level was left another way (return-to-hub) before the beat elapsed.
		var error := get_tree().change_scene_to_file(next_scene)
		if error != OK:
			push_error("Level flow: could not load %s (error %d)" % [next_scene, error]))


## The path of the .tscn this node belongs to. Read off the scene's ROOT, because
## scene_file_path is only set there, not on children.
func _current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	return scene.scene_file_path if scene != null else ""
