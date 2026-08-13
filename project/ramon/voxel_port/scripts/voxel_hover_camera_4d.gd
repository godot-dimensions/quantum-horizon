class_name VoxelHoverCamera4D
extends Camera4D
## RTS/cozy-style hovering orbit camera for previewing the volumetric
## terrain - recreated from this project's own established camera
## convention (an orbit+pan+4D-rotate rig used elsewhere in this repo, not
## a literal file port - those specific files are gone from the working
## copy as of this session, see the conversation this was built in), not
## a first-person walking controller.
##
## Controls:
##   Left-drag: orbit (azimuth/elevation) around look_at_target, in
##     ordinary 3D - never touches the w axis.
##   Right-drag: rotates rig_path's own basis in the xw/zw planes - this
##     project's established "look at a different 4D cross-section by
##     rotating the OBJECT, not the camera" convention. Applied to rig_path
##     (defaults to the camera's own parent) rather than to this camera,
##     since the camera itself deliberately never carries this rotation -
##     see VoxelTerrain4D._update_chunk_visibility's own comment on why
##     that matters for the slice-culling math.
##   Scroll wheel: zoom (adjusts radius).
##   WASD: pans look_at_target in the horizontal (x/z) plane, relative to
##     the camera's CURRENT azimuth (so "forward" tracks whichever way the
##     camera is currently facing).
##   Q/E: pans look_at_target vertically (y).
##   Left-click (press+release with barely any movement, as opposed to a
##     drag): adds a sphere of ground at look_at_target - see edit_radius.
##   Right-click (same click-vs-drag distinction): carves a sphere of air at
##     look_at_target instead.
##
## Editing targets look_at_target itself rather than a raycast hit point.
## VoxelTerrain4D's own generate_collision is off by default and, even when
## on, AxisAlignedBoxPhysicsEngine4D collapses every shape to one bounding
## box (see that export's own doc comment) - a raycast against the terrain's
## actual surface is not available the way it would be in 3D. look_at_target
## is already "the point this camera is centered on" by construction, which
## makes it a natural, always-available stand-in: aiming the edit is the same
## gesture as aiming the camera (orbit until the highlight sits where you
## want, then click), rather than a second targeting system layered on top.
##
## Raw Input.is_key_pressed() / is_mouse_button_pressed() checks throughout
## rather than InputMap actions - this is a fresh preview scene with no
## project-wide input bindings of its own yet, and adding a handful of new
## global input actions for one dev-tool scene isn't worth the project.godot
## churn.

@export var look_at_target: Vector4 = Vector4.ZERO
@export_range(1.0, 2000.0, 1.0, "or_greater") var radius: float = 60.0
@export_range(1.0, 4000.0, 1.0, "or_greater") var min_radius: float = 4.0
@export_range(1.0, 4000.0, 1.0, "or_greater") var max_radius: float = 2000.0
## The node whose basis carries the 4D right-drag rotation - see this
## script's own header. Defaults to this camera's own parent (the pivot
## node it orbits from) if left empty, so a scene doesn't have to wire this
## explicitly unless it wants the rotation applied somewhere else (e.g.
## directly on VoxelTerrain4D, as voxel_port.tscn does).
@export var rig_path: NodePath
## The VoxelTerrain4D to edit. Left unset, clicking does nothing (and the
## highlight never appears) rather than erroring - the same "unwired means
## no-op, not broken" convention camera_path/rig_path already use elsewhere
## in this feature.
@export var terrain_path: NodePath
@export_range(0.5, 100.0, 0.5, "or_greater", "suffix:m") var edit_radius: float = 6.0

@export_range(0.001, 0.02, 0.0001) var orbit_sensitivity: float = 0.005
@export_range(0.001, 0.02, 0.0001) var rotate_4d_sensitivity: float = 0.006
@export_range(0.05, 1.0, 0.01) var zoom_sensitivity: float = 0.12
@export_range(1.0, 100.0, 1.0) var pan_speed: float = 20.0
## Radians - kept off the exact poles (+-PI/2) so the azimuth angle never
## goes momentarily undefined at the exact top/bottom of the orbit.
const ELEVATION_LIMIT := deg_to_rad(85.0)
## Total mouse movement (pixels) a press+release can accumulate and still
## count as a click rather than a drag. Small enough that a genuine orbit/
## rotate gesture is never mistaken for a click, generous enough that a
## human hand pressing a button without perfect stillness still registers.
const CLICK_DRAG_TOLERANCE_PX := 6.0

var _azimuth: float = 0.0
var _elevation: float = deg_to_rad(35.0)
var _dragging_orbit := false
var _dragging_rotate_4d := false
var _last_mouse_pos := Vector2.ZERO
## Accumulated mouse movement since the button currently held (if any) was
## pressed - reset on press, compared against CLICK_DRAG_TOLERANCE_PX on
## release to tell a click from a drag. Both mouse buttons share one
## accumulator since only one can be meaningfully "the one just pressed" at
## a time for this purpose.
var _press_drag_distance := 0.0
var _highlight: MeshInstance4D


func _get_rig() -> Node4D:
	if not rig_path.is_empty():
		return get_node_or_null(rig_path) as Node4D
	return get_parent() as Node4D


func _get_terrain() -> Node4D:
	return get_node_or_null(terrain_path) as Node4D


func _ready() -> void:
	_apply_orbit()
	_highlight = MeshInstance4D.new()
	_highlight.name = "EditHighlight"
	var wire_mesh := OrthoplexWireMesh4D.new()
	_highlight.mesh = wire_mesh
	var highlight_material := TetraMaterial4D.new()
	highlight_material.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_SINGLE_COLOR
	highlight_material.albedo_color = Color(1.0, 0.9, 0.2, 0.9)
	_highlight.material_override = highlight_material
	var terrain: Node4D = _get_terrain()
	if terrain != null:
		terrain.add_child(_highlight)
	_update_highlight()


func _update_highlight() -> void:
	if _highlight == null:
		return
	_highlight.position = look_at_target
	var mesh: OrthoplexWireMesh4D = _highlight.mesh
	mesh.half_extents = Vector4.ONE * edit_radius


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_drag_distance = 0.0
			elif _press_drag_distance <= CLICK_DRAG_TOLERANCE_PX:
				_try_edit(true)
			_dragging_orbit = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_press_drag_distance = 0.0
			elif _press_drag_distance <= CLICK_DRAG_TOLERANCE_PX:
				_try_edit(false)
			_dragging_rotate_4d = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			radius = maxf(min_radius, radius * (1.0 - zoom_sensitivity))
			_apply_orbit()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			radius = minf(max_radius, radius * (1.0 + zoom_sensitivity))
			_apply_orbit()
		_last_mouse_pos = mb.position
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		var delta: Vector2 = mm.position - _last_mouse_pos
		_last_mouse_pos = mm.position
		if _dragging_orbit or _dragging_rotate_4d:
			_press_drag_distance += delta.length()
		if _dragging_orbit:
			_azimuth -= delta.x * orbit_sensitivity
			_elevation = clampf(_elevation - delta.y * orbit_sensitivity, -ELEVATION_LIMIT, ELEVATION_LIMIT)
			_apply_orbit()
		elif _dragging_rotate_4d:
			var rig: Node4D = _get_rig()
			if rig != null:
				# xw first, then zw - matches this project's own established
				# right-drag convention (mixes x/w and z/w only, never
				# touching y, so "straight down" stays meaningful for any
				# ground-probe raycast regardless of current rig rotation).
				var step: Projection = Basis4D.from_xw(delta.x * rotate_4d_sensitivity) * Basis4D.from_zw(delta.y * rotate_4d_sensitivity)
				rig.basis = rig.basis * step


func _try_edit(is_add: bool) -> void:
	var terrain: Node4D = _get_terrain()
	if terrain == null:
		return
	terrain.edit_sphere(look_at_target, edit_radius, is_add)


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_D):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_A):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_S):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_W):
		pan.y -= 1.0
	var vertical := 0.0
	if Input.is_key_pressed(KEY_E):
		vertical += 1.0
	if Input.is_key_pressed(KEY_Q):
		vertical -= 1.0

	if pan != Vector2.ZERO or vertical != 0.0:
		# Pan directions relative to the camera's CURRENT azimuth, projected
		# onto the horizontal (x/z) plane - "forward" tracks whichever way
		# the camera is currently facing, same as this project's own
		# established pan convention.
		var forward := Vector2(sin(_azimuth), cos(_azimuth))
		var right := Vector2(forward.y, -forward.x)
		var move: Vector2 = (right * pan.x - forward * pan.y) * pan_speed * delta
		look_at_target.x += move.x
		look_at_target.z += move.y
		look_at_target.y += vertical * pan_speed * delta
		_apply_orbit()


func _apply_orbit() -> void:
	var horizontal_radius: float = radius * cos(_elevation)
	var offset := Vector3(
		horizontal_radius * sin(_azimuth),
		radius * sin(_elevation),
		horizontal_radius * cos(_azimuth),
	)
	position = look_at_target + Vector4(offset.x, offset.y, offset.z, 0.0)
	look_at(Vector4(look_at_target.x, look_at_target.y, look_at_target.z, position.w), Vector4(0, 1, 0, 0))
	_update_highlight()
