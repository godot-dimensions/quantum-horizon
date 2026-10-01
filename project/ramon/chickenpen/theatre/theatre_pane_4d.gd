extends Control

## A see-through glow on the chicken's sheet (slide I), drawn in screen space.
##
## THE RENDERER CANNOT DO THIS ONE. The cross-section shader has no translucency: every
## tetrahedron is opaque. The first try at "a bit of a blue gradient from the sides" was
## opaque bands of boxes fading from blue to dark, and Ramon (1 Oct) was right that it was
## broken - the bands stepped, read as a solid mesh, and could not be seen through.
##
## SO THE GLOW IS PAINTED OVER THE PICTURE INSTEAD. The 2D canvas does alpha and smooth
## colour between vertices, so a grid laid on the sheet's plane, projected through the live
## camera every frame and coloured from the edges in, is a genuinely transparent pane that
## stays glued to the sheet as the shot moves. Strongest at the left, the right and the top,
## brightest along the chicken's floor line, clear in the middle.
##
## THE HACK'S ONE CHEAT: a 2D overlay has no depth, so whatever passes IN FRONT of the
## sheet is tinted as if it were behind it. The tint is close to nothing in the middle,
## which is where the ball and the cone come through, so it does not show.

@export var camera_path: NodePath
@export var shot_rig_path: NodePath
@export var glow: Color = Color(0.32, 0.68, 1.0)
## Grid cells across and up. Fine enough that the gradient is smooth and the projection
## follows the plane; the colour between vertices does the rest.
@export var cells: Vector2i = Vector2i(18, 12)
@export_range(0.05, 3.0, 0.05) var fade_seconds: float = 0.6
## How far in from each edge the glow reaches, as fractions of the sheet.
@export_range(0.02, 0.5, 0.01) var side_reach: float = 0.24
@export_range(0.02, 0.5, 0.01) var top_reach: float = 0.18
@export_range(0.0, 1.0, 0.01) var side_alpha: float = 0.42
@export_range(0.0, 1.0, 0.01) var top_alpha: float = 0.30
@export_range(0.0, 1.0, 0.01) var ground_alpha: float = 0.48
## Everywhere, so the middle still reads as a surface rather than as a hole in a frame.
@export_range(0.0, 0.3, 0.005) var base_alpha: float = 0.035

@export_group("Lines")
## The sheet's edges, its floor line and a faint grid, drawn here too rather than as
## meshes, so they can be bright and a little see-through (Ramon, 1 Oct).
@export var edge_color: Color = Color(0.55, 0.90, 1.0, 0.85)
@export var floor_color: Color = Color(0.75, 0.95, 1.0, 0.95)
@export var grid_color: Color = Color(0.50, 0.80, 1.0, 0.28)
@export_range(0, 12, 1) var grid_across: int = 6
@export_range(0, 8, 1) var grid_up: int = 3

var _camera: Camera4D
var _shot_rig: Node
var _piece: Node4D
var _rect := Rect2()
var _floor := 0.12
var _showing: bool = false
var _fade: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Lays the pane on [param piece]'s plane z = 0, over [param rect] in its own (x, y), with
## the chicken's floor line at [param floor_y].
func show_pane(piece: Node4D, rect: Rect2, floor_y: float) -> void:
	_piece = piece
	_rect = rect
	_floor = clampf((floor_y - rect.position.y) / maxf(rect.size.y, 0.01), 0.0, 1.0)
	_showing = true


func hide_pane() -> void:
	_showing = false


func is_showing() -> bool:
	return _showing


func _process(delta: float) -> void:
	if _camera == null:
		_camera = get_node_or_null(camera_path) as Camera4D
	if _shot_rig == null:
		_shot_rig = get_node_or_null(shot_rig_path)
	var was: float = _fade
	_fade = move_toward(_fade, 1.0 if _showing else 0.0, delta / maxf(fade_seconds, 0.01))
	# One more redraw on the way to nothing, or the last faint frame stays on screen.
	if _fade > 0.0 or was > 0.0:
		queue_redraw()


## Whichever camera is rendering: the shot camera once you sit, your own before that.
func _live() -> Camera4D:
	if _shot_rig != null and _shot_rig.has_method("live_camera"):
		var shot: Camera4D = _shot_rig.call("live_camera") as Camera4D
		if shot != null and shot.is_current():
			return shot
	return _camera


## How opaque the pane is at (u, v), both 0 to 1 across and up the sheet.
func _alpha(u: float, v: float) -> float:
	var side: float = 1.0 - smoothstep(0.0, side_reach, minf(u, 1.0 - u))
	var top: float = 1.0 - smoothstep(0.0, top_reach, 1.0 - v)
	# The ground: lit under the floor line, brightest at the line, with a little of it
	# spilling up into the world above.
	var ground: float = lerpf(0.55, 1.0, v / maxf(_floor, 0.01)) if v < _floor \
		else 1.0 - smoothstep(0.0, 0.09, v - _floor)
	return clampf(maxf(maxf(side * side_alpha, top * top_alpha), ground * ground_alpha) + base_alpha,
		0.0, 1.0)


func _draw() -> void:
	if _fade <= 0.01 or _piece == null or not is_instance_valid(_piece):
		return
	var eye: Camera4D = _live()
	if eye == null:
		return
	var forward: Vector4 = -eye.global_basis.z
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for j in cells.y + 1:
		for i in cells.x + 1:
			var u: float = float(i) / float(cells.x)
			var v: float = float(j) / float(cells.y)
			var local := Vector4(_rect.position.x + u * _rect.size.x, _rect.position.y + v * _rect.size.y,
				0.0, 0.0)
			var world: Vector4 = _piece.global_position + _piece.global_basis * local
			# Anything behind the lens projects to nonsense; the slide never puts the camera
			# behind the sheet, so stop rather than draw something wrong.
			if forward.dot(world - eye.global_position) <= 0.05:
				return
			points.append(eye.world_to_viewport(world))
			colours.append(Color(glow, _alpha(u, v) * _fade))
	var row: int = cells.x + 1
	for j in cells.y:
		for i in cells.x:
			var a: int = j * row + i
			var quad := PackedVector2Array([points[a], points[a + 1], points[a + row + 1], points[a + row]])
			var tint := PackedColorArray([colours[a], colours[a + 1], colours[a + row + 1], colours[a + row]])
			draw_polygon(quad, tint)
	_draw_lines(eye)


## A point of the sheet, (u, v) across and up, on screen.
func _at(eye: Camera4D, u: float, v: float) -> Vector2:
	var local := Vector4(_rect.position.x + u * _rect.size.x, _rect.position.y + v * _rect.size.y, 0.0, 0.0)
	return eye.world_to_viewport(_piece.global_position + _piece.global_basis * local)


## The lines the mesh frame used to be: a faint grid over the world above the floor, the
## four edges, and the floor line, brightest, last. A straight line in a plane stays
## straight in a perspective picture, so each is just its two ends projected.
func _draw_lines(eye: Camera4D) -> void:
	var h: float = get_viewport_rect().size.y
	var px: float = maxf(1.0, h / 720.0)
	var f: float = _fade
	for i in range(1, grid_across):
		var u: float = float(i) / float(grid_across)
		draw_line(_at(eye, u, 0.0), _at(eye, u, 1.0), Color(grid_color, grid_color.a * f), 1.2 * px, true)
	for j in range(1, grid_up):
		var v: float = lerpf(_floor, 1.0, float(j) / float(grid_up))
		draw_line(_at(eye, 0.0, v), _at(eye, 1.0, v), Color(grid_color, grid_color.a * f), 1.2 * px, true)
	var corners: Array = [_at(eye, 0.0, 0.0), _at(eye, 1.0, 0.0), _at(eye, 1.0, 1.0), _at(eye, 0.0, 1.0)]
	for k in 4:
		draw_line(corners[k], corners[(k + 1) % 4], Color(edge_color, edge_color.a * f), 2.2 * px, true)
	draw_line(_at(eye, 0.0, _floor), _at(eye, 1.0, _floor), Color(floor_color, floor_color.a * f), 3.2 * px, true)
