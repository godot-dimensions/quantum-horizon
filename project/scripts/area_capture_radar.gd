extends Control
## Fork of slice_radar.gd for area_capture_test.tscn - same player-centered
## ellipse/off-plane-stem readout, but tracking this scene's target cluster
## cubes instead of shooting_gallery.tscn's gallery target/duck/contest
## spawners (which don't exist here). Forked rather than generalizing the
## original: this project's own established convention for per-range
## variants (e.g. bullseye_weapon.gd as "a fork of hitscan_weapon.gd") is to
## fork, not to thread every range's data source through one shared script.
##
## Exported NodePaths rather than slice_radar.gd's hardcoded @onready
## "../../FlatPlane/..." paths - this scene's tree shape is different (no
## FlatPlane container), and export paths are the pattern the rest of this
## scene's own components (area_capture_controller.gd, area_capture_hud.gd)
## already use.
##
## See slice_radar.gd for the full derivation of the projection/stem math -
## unchanged here, just re-pointed at a different data source.

## preload(), not the bare class name - see this project's own established
## headless-hang gotcha with brand-new class_name scripts referenced before
## the editor's class cache has scanned them.
const AreaCaptureController = preload("res://scripts/area_capture_controller.gd")

enum AxisLabelStyle { NONE, POS_NEG, CARDINAL }
enum AxisLineStyle { NONE, DIRECT, PROJECTED }

const ELLIPSE_SEGMENTS := 96
const NAT_LOG_2 := 0.6931471805599453094
const HALFWAY_METERS := 6.0
const MINOR_LINE_SPACING_MULTIPLIER := 1.5
const W_IS_UP: bool = false

@export var player_path: NodePath
@export var target_cluster_path: NodePath
@export var controller_path: NodePath

@export var ellipse_squash_factor: float = 0.55
@export var ellipse_w_factor: float = 0.75
@export var ellipse_line_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var ellipse_fill_color: Color = Color(1.0, 1.0, 1.0, 0.07)

@export var axis_label_style: AxisLabelStyle = AxisLabelStyle.NONE
@export var axis_line_style: AxisLineStyle = AxisLineStyle.NONE

@export var player_marker_radius: float = 6.0
@export var player_marker_color: Color = Color(1.0, 1.0, 1.0, 0.95)

@export var projected_point_radius: float = 5.0
@export var projected_point_color: Color = Color(0.6, 0.6, 0.6, 0.9)

@export var off_plane_dot_radius: float = 6.0
@export var stem_alpha: float = 0.6

## Fill alpha for a captured box's footprint on the radar - deliberately
## much lower than the box's own real in-world alpha (1.0, fully opaque once
## locked in): at radar scale a solid-alpha quad would read as a HUD panel,
## not a translucent "here's the covered area" overlay.
const AREA_FILL_ALPHA := 0.35
const AREA_OUTLINE_ALPHA := 0.7
const LIVE_PREVIEW_FILL_ALPHA := 0.22

var _player: Node
var _target_cluster: Node
var _controller: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_player = get_node_or_null(player_path)
	_target_cluster = get_node_or_null(target_cluster_path)
	_controller = get_node_or_null(controller_path)


func _process(_delta: float) -> void:
	queue_redraw()


func _ellipse_points(ellipse_center: Vector2, ellipse_radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var angle: float = TAU * i / ELLIPSE_SEGMENTS
		points.append(ellipse_center + Vector2(cos(angle) * ellipse_radii.x, sin(angle) * ellipse_radii.y))
	return points


## Same exponential distance-compression mapping used for every marker on
## this radar - factored out so the area-footprint corners (below) project
## with identical distortion to the point markers, rather than drifting out
## of visual agreement with them.
func _project_local(relative_position: Vector4, ellipse_center: Vector2, ellipse_radii: Vector2) -> Vector2:
	var rel_len: float = relative_position.length()
	if rel_len < 0.0001:
		return ellipse_center
	var rel_len_exp: float = 1.0 - exp(-rel_len * (NAT_LOG_2 / HALFWAY_METERS))
	var scaled: Vector4 = relative_position * (rel_len_exp / rel_len)
	return ellipse_center + Vector2(scaled.x * ellipse_radii.x, scaled.z * ellipse_radii.y)


func _draw_tracked_object(relative_target_position: Vector4, marker_color: Color, ellipse_center: Vector2, ellipse_radii: Vector2) -> void:
	if relative_target_position.length() < 0.0001:
		return
	var projected: Vector2 = _project_local(relative_target_position, ellipse_center, ellipse_radii)
	draw_circle(projected, projected_point_radius, projected_point_color)

	var rel_len: float = relative_target_position.length()
	var rel_len_exp: float = 1.0 - exp(-rel_len * (NAT_LOG_2 / HALFWAY_METERS))
	var scaled_w: float = relative_target_position.w * (rel_len_exp / rel_len)
	var w_offset: float = -scaled_w if W_IS_UP else scaled_w
	var stem_end: Vector2 = projected + Vector2(0.0, w_offset * ellipse_radii.y)
	draw_line(projected, stem_end, Color(marker_color.r, marker_color.g, marker_color.b, stem_alpha), 2.0)
	draw_circle(stem_end, off_plane_dot_radius, marker_color)


## Draws a box's x/z footprint (assumes axis-aligned, no rotation - true for
## every box area_capture_controller.gd ever creates) as a filled quad, so
## "how much ground is currently covered" reads as a shape on the radar, not
## just a single point the way target cubes do.
func _draw_area_footprint(box: MeshInstance4D, fill_color: Color, ellipse_center: Vector2, ellipse_radii: Vector2, player_basis_inv: Projection, player_position: Vector4) -> void:
	var box_mesh: BoxTetraMesh4D = box.mesh
	var half: Vector4 = box_mesh.size * 0.5
	var corners_world: Array[Vector4] = [
		box.position + Vector4(-half.x, 0.0, -half.z, 0.0),
		box.position + Vector4(half.x, 0.0, -half.z, 0.0),
		box.position + Vector4(half.x, 0.0, half.z, 0.0),
		box.position + Vector4(-half.x, 0.0, half.z, 0.0),
	]
	var points := PackedVector2Array()
	for corner in corners_world:
		var rel_local: Vector4 = player_basis_inv * (corner - player_position)
		points.append(_project_local(rel_local, ellipse_center, ellipse_radii))
	var fill_colors := PackedColorArray()
	fill_colors.resize(points.size())
	fill_colors.fill(fill_color)
	draw_polygon(points, fill_colors)
	var outline_color := Color(fill_color.r, fill_color.g, fill_color.b, minf(fill_color.a * 2.0, 1.0))
	draw_polyline(points + PackedVector2Array([points[0]]), outline_color, 1.5, true)


func _draw_ring_label(bottom_center: Vector2, text: String, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size
	var total_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var char_pos: Vector2 = bottom_center + Vector2(-total_width / 2.0, font.get_ascent(font_size) * 0.85)
	for i in text.length():
		var character: String = text[i]
		draw_char(font, char_pos, character, font_size, color)
		char_pos.x += font.get_char_size(character.unicode_at(0), font_size).x


func _draw_ellipse_rings(ellipse_center: Vector2, ellipse_radii: Vector2) -> void:
	var ellipse_points: PackedVector2Array = _ellipse_points(ellipse_center, ellipse_radii)
	var fill_colors := PackedColorArray()
	fill_colors.resize(ellipse_points.size())
	fill_colors.fill(ellipse_fill_color)
	draw_polygon(ellipse_points, fill_colors)
	var font_ascent: float = ThemeDB.fallback_font.get_ascent(ThemeDB.fallback_font_size)
	var minor_color: Color = ellipse_line_color
	minor_color.a *= 0.5
	var last_minor_radii_y: float = -1.0
	for i in range(1, 12 * MINOR_LINE_SPACING_MULTIPLIER):
		var minor_radii: Vector2 = ellipse_radii * (1.0 - exp(-i * (NAT_LOG_2 / MINOR_LINE_SPACING_MULTIPLIER)))
		var minor_points: PackedVector2Array = _ellipse_points(ellipse_center, minor_radii)
		draw_polyline(minor_points + PackedVector2Array([minor_points[0]]), minor_color, 1.0, true)
		if minor_radii.y - last_minor_radii_y > font_ascent * 1.25:
			var ratio: float = HALFWAY_METERS / MINOR_LINE_SPACING_MULTIPLIER
			var ring_meters: float = i * ratio
			var fmt: String = "%.1fm"
			if is_equal_approx(int(ratio), ratio):
				fmt = "%dm"
			_draw_ring_label(ellipse_center + Vector2(0.0, -minor_radii.y), fmt % ring_meters, minor_color)
		last_minor_radii_y = minor_radii.y
	draw_polyline(ellipse_points + PackedVector2Array([ellipse_points[0]]), ellipse_line_color, 2.0, true)


func _draw() -> void:
	if _player == null:
		return
	var ellipse_margin_ratio: float = 0.9
	var ellipse_center: Vector2 = size * 0.5
	var ellipse_radii: Vector2 = ellipse_center * ellipse_margin_ratio
	ellipse_radii.y = ellipse_radii.x * ellipse_squash_factor
	ellipse_center.y = size.y * (0.5 + 0.5 * ellipse_margin_ratio) - ellipse_radii.x * ellipse_squash_factor

	_draw_ellipse_rings(ellipse_center, ellipse_radii)
	draw_circle(ellipse_center, player_marker_radius, player_marker_color)

	var player_basis_inv: Projection = _player.global_basis.inverse()
	var player_position: Vector4 = _player.global_position

	# Covered-area footprints - drawn before the point markers so target
	# cubes' dots/stems always render on top of an underlying box, never
	# hidden beneath one.
	if _controller != null:
		for box in _controller.captured_boxes:
			var captured_material: TetraMaterial4D = box.material_override
			var fill: Color = captured_material.albedo_color
			fill.a = AREA_FILL_ALPHA
			_draw_area_footprint(box, fill, ellipse_center, ellipse_radii, player_basis_inv, player_position)
		if _controller._drawing and _controller._preview_box != null:
			var live_fill := Color(
				AreaCaptureController.PREVIEW_COLOR.r, AreaCaptureController.PREVIEW_COLOR.g,
				AreaCaptureController.PREVIEW_COLOR.b, LIVE_PREVIEW_FILL_ALPHA,
			)
			_draw_area_footprint(_controller._preview_box, live_fill, ellipse_center, ellipse_radii, player_basis_inv, player_position)

	if _target_cluster == null:
		return
	var cube_color: Color = _target_cluster.cube_color
	for cube in _target_cluster.cubes:
		var rel_pos_global: Vector4 = cube.global_position - player_position
		var rel_pos_local: Vector4 = player_basis_inv * rel_pos_global
		_draw_tracked_object(rel_pos_local, cube_color, ellipse_center, ellipse_radii)
