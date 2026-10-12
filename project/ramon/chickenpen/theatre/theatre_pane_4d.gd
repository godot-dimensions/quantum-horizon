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
## What the pane was last drawn for: the camera, the sheet, the fade and the window. A
## canvas keeps its drawing until it is redrawn, so a held shot costs nothing at all.
var _drawn_for: Array = []


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
		var eye: Camera4D = _live()
		var now: Array = [_fade, get_viewport_rect().size]
		if eye != null:
			now.append_array([eye.global_basis, eye.global_position])
		if _piece != null and is_instance_valid(_piece):
			now.append_array([_piece.global_basis, _piece.global_position])
		if now != _drawn_for:
			_drawn_for = now
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


## ONE BATCH OF TRIANGLES, FROM FOUR CORNERS. The pane was 216 polygons a frame, each its
## own draw command, with every grid point put through the camera - a millisecond and a half
## a frame (measured 10 Oct, _measure_slide1_parts_runner), more than the rest of the slide.
## The sheet is flat, and a flat thing seen in perspective is a homography of its own square:
## project its four corners and every other point of it follows exactly, so the grid and the
## lines are mapped from the corners and the whole gradient goes out as one triangle array.
func _draw() -> void:
	if _fade <= 0.01 or _piece == null or not is_instance_valid(_piece):
		return
	var eye: Camera4D = _live()
	if eye == null:
		return
	var forward: Vector4 = -eye.global_basis.z
	var corners := PackedVector2Array()
	for c in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
		var world: Vector4 = _piece.global_position + _piece.global_basis * Vector4(
			_rect.position.x + c.x * _rect.size.x, _rect.position.y + c.y * _rect.size.y, 0.0, 0.0)
		# Anything behind the lens projects to nonsense; the slide never puts the camera
		# behind the sheet, so stop rather than draw something wrong.
		if forward.dot(world - eye.global_position) <= 0.05:
			return
		corners.append(eye.world_to_viewport(world))
	var h: PackedFloat32Array = _square_to_quad(corners)
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for j in cells.y + 1:
		for i in cells.x + 1:
			var u: float = float(i) / float(cells.x)
			var v: float = float(j) / float(cells.y)
			points.append(_map(h, u, v))
			colours.append(Color(glow, _alpha(u, v) * _fade))
	var row: int = cells.x + 1
	var indices := PackedInt32Array()
	for j in cells.y:
		for i in cells.x:
			var a: int = j * row + i
			indices.append_array([a, a + 1, a + row + 1, a, a + row + 1, a + row])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)
	_draw_lines(h)


## The homography taking the unit square onto [param quad] (corners at (0,0), (1,0), (1,1),
## (0,1), in that order): eight numbers, Heckbert's square-to-quad.
static func _square_to_quad(quad: PackedVector2Array) -> PackedFloat32Array:
	var p0: Vector2 = quad[0]
	var p1: Vector2 = quad[1]
	var p2: Vector2 = quad[2]
	var p3: Vector2 = quad[3]
	var s: Vector2 = p0 - p1 + p2 - p3
	if s.length_squared() < 1e-10:
		return PackedFloat32Array([p1.x - p0.x, p3.x - p0.x, p0.x, p1.y - p0.y, p3.y - p0.y, p0.y, 0.0, 0.0])
	var d1: Vector2 = p1 - p2
	var d2: Vector2 = p3 - p2
	var den: float = d1.x * d2.y - d2.x * d1.y
	var g: float = (s.x * d2.y - d2.x * s.y) / den
	var k: float = (d1.x * s.y - s.x * d1.y) / den
	return PackedFloat32Array([p1.x - p0.x + g * p1.x, p3.x - p0.x + k * p3.x, p0.x,
		p1.y - p0.y + g * p1.y, p3.y - p0.y + k * p3.y, p0.y, g, k])


## A point of the sheet, (u, v) across and up, on screen.
static func _map(h: PackedFloat32Array, u: float, v: float) -> Vector2:
	var q: float = h[6] * u + h[7] * v + 1.0
	return Vector2((h[0] * u + h[1] * v + h[2]) / q, (h[3] * u + h[4] * v + h[5]) / q)


## The lines the mesh frame used to be: a faint grid over the world above the floor, the
## four edges, and the floor line, brightest, last.
func _draw_lines(h: PackedFloat32Array) -> void:
	var height: float = get_viewport_rect().size.y
	var px: float = maxf(1.0, height / 720.0)
	var f: float = _fade
	for i in range(1, grid_across):
		var u: float = float(i) / float(grid_across)
		draw_line(_map(h, u, 0.0), _map(h, u, 1.0), Color(grid_color, grid_color.a * f), 0.8 * px, true)
	for j in range(1, grid_up):
		var v: float = lerpf(_floor, 1.0, float(j) / float(grid_up))
		draw_line(_map(h, 0.0, v), _map(h, 1.0, v), Color(grid_color, grid_color.a * f), 0.8 * px, true)
	var corners: Array = [_map(h, 0.0, 0.0), _map(h, 1.0, 0.0), _map(h, 1.0, 1.0), _map(h, 0.0, 1.0)]
	for k in 4:
		draw_line(corners[k], corners[(k + 1) % 4], Color(edge_color, edge_color.a * f), 1.7 * px, true)
	draw_line(_map(h, 0.0, _floor), _map(h, 1.0, _floor), Color(floor_color, floor_color.a * f), 1.8 * px, true)
