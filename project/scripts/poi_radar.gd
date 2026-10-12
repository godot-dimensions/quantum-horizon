extends Control
## Generalized version of slice_radar.gd (built for the shooting gallery,
## tightly coupled to that scene's Player/spawner/duck_spawner globals) -
## same ellipse + oblique-projection drawing (a point on the ellipse for
## right/depth, a vertical screen-space stem for ana_offset - reads like an
## air-traffic-control altitude readout), generalized to track an arbitrary
## list of POI4D nodes instead of gallery-specific globals.
##
## Also adapted for a DIFFERENT rotation convention: the shooting gallery's
## Player body carries slice-rotation directly on its own basis, so
## BearingUtility4D.compute(player, ...) was correct as-is. voxel_port's
## hover camera never carries that rotation itself - the TERRAIN (rig_path)
## does (see voxel_hover_camera_4d.gd's own header) - so this uses
## BearingUtility4D.compute_raw() with the camera's position but the rig's
## basis. Using the camera's own basis here would silently ignore all
## slice-rotation and show every POI as if the slice were still at zero.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

const ELLIPSE_SEGMENTS := 96
const NAT_LOG_2 := 0.6931471805599453094
const MINOR_LINE_SPACING_MULTIPLIER := 1.5
const W_IS_UP: bool = false

@export var ellipse_squash_factor: float = 0.55
@export var ellipse_line_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var ellipse_fill_color: Color = Color(1.0, 1.0, 1.0, 0.07)
@export var player_marker_radius: float = 6.0
@export var player_marker_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var projected_point_radius: float = 5.0
@export var projected_point_color: Color = Color(0.6, 0.6, 0.6, 0.9)
@export var off_plane_dot_radius: float = 6.0
@export var stem_alpha: float = 0.6
## The distance in meters at which objects are halfway to the radar's outer
## edge (which represents infinite distance via an exponential mapping) -
## same technique as slice_radar.gd, retuned for this terrain's scale
## (tens of meters, not the shooting gallery's ~6m range).
@export var halfway_meters: float = 20.0

## The camera - its position is "where the radar is centered from."
@export var camera_path: NodePath
## The Node4D whose basis carries the current 4D rotation - see this
## script's own header for why this must be the rig, not the camera.
@export var rig_path: NodePath
## Any Node - every POI4D found among its descendants (recursively, so it
## works whether POIs are direct children or nested further) is tracked.
## Typically the same container poi_spawner.gd populates.
@export var poi_container_path: NodePath

## Optional - a Node4D exposing `get_travel_direction() -> Vector4` (duck-
## typed, matching limb_prototype_body.gd's own method - the same value
## foot placement already reads, not a recomputed one). When set, draws one
## extra marker via the SAME _draw_tracked_object/BearingUtility4D.compute_raw
## path as every PoI above, for a point projected direction_indicator_length
## ahead of this node along its current travel direction - a heading arrow,
## not a new drawing mechanism. Left empty (the default), _draw() skips this
## entirely - voxel_port.tscn and any other existing user of this script are
## unaffected.
@export var direction_source_path: NodePath
@export var direction_marker_color: Color = Color(0.25, 0.9, 0.35, 1.0)
@export var direction_indicator_length: float = 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


func _ellipse_points(ellipse_center: Vector2, ellipse_radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var angle: float = TAU * i / ELLIPSE_SEGMENTS
		points.append(ellipse_center + Vector2(cos(angle) * ellipse_radii.x, sin(angle) * ellipse_radii.y))
	return points


## relative_target_position's .x/.z/.w are right_component/depth_component/
## ana_offset respectively - same convention slice_radar.gd's caller
## produces via `player_basis_inv * rel_pos_global` before calling its
## version of this function.
func _draw_tracked_object(relative_target_position: Vector4, marker_color: Color, ellipse_center: Vector2, ellipse_radii: Vector2) -> void:
	var rel_len: float = relative_target_position.length()
	if rel_len < 0.0001:
		return
	var rel_len_exp: float = 1.0 - exp(-rel_len * (NAT_LOG_2 / halfway_meters))
	var scaled_target_pos: Vector4 = relative_target_position * (rel_len_exp / rel_len)
	var projected: Vector2 = ellipse_center + Vector2(
		scaled_target_pos.x * ellipse_radii.x,
		scaled_target_pos.z * ellipse_radii.y,
	)
	draw_circle(projected, projected_point_radius, projected_point_color)

	var w_offset: float = -scaled_target_pos.w if W_IS_UP else scaled_target_pos.w
	var stem_end: Vector2 = projected + Vector2(0.0, w_offset * ellipse_radii.y)
	draw_line(projected, stem_end, Color(marker_color.r, marker_color.g, marker_color.b, stem_alpha), 2.0)
	draw_circle(stem_end, off_plane_dot_radius, marker_color)


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
			var ratio: float = halfway_meters / MINOR_LINE_SPACING_MULTIPLIER
			var ring_meters: float = i * ratio
			_draw_ring_label(ellipse_center + Vector2(0.0, -minor_radii.y), "%.0fm" % ring_meters, minor_color)
		last_minor_radii_y = minor_radii.y
	draw_polyline(ellipse_points + PackedVector2Array([ellipse_points[0]]), ellipse_line_color, 2.0, true)


## Recursively finds every POI4D under root - direct children or nested,
## so the spawner's container structure isn't load-bearing here.
func _collect_pois(root: Node) -> Array:
	var result: Array = []
	for child in root.get_children():
		if child is POI4D:
			result.append(child)
		result.append_array(_collect_pois(child))
	return result


func _draw() -> void:
	var ellipse_margin_ratio := 0.9
	var ellipse_center: Vector2 = size * 0.5
	var ellipse_radii: Vector2 = ellipse_center * ellipse_margin_ratio
	ellipse_radii.y = ellipse_radii.x * ellipse_squash_factor
	ellipse_center.y = size.y * (0.5 + 0.5 * ellipse_margin_ratio) - ellipse_radii.x * ellipse_squash_factor

	_draw_ellipse_rings(ellipse_center, ellipse_radii)
	draw_circle(ellipse_center, player_marker_radius, player_marker_color)

	var camera: Node4D = get_node_or_null(camera_path) as Node4D
	var rig: Node4D = get_node_or_null(rig_path) as Node4D
	var container: Node = get_node_or_null(poi_container_path)
	if camera == null or rig == null or container == null:
		return

	var observer_position: Vector4 = camera.global_position
	var observer_basis: Projection = rig.global_basis
	for poi in _collect_pois(container):
		var bearing: Dictionary = BearingUtility4D.compute_raw(observer_position, observer_basis, poi.global_position)
		var rel_local := Vector4(bearing.right_component, 0.0, bearing.depth_component, bearing.ana_offset)
		_draw_tracked_object(rel_local, POI4D.CATEGORY_COLOR[poi.category], ellipse_center, ellipse_radii)

	var direction_source: Node4D = get_node_or_null(direction_source_path) as Node4D
	if direction_source != null and direction_source.has_method("get_travel_direction"):
		var heading_target: Vector4 = direction_source.global_position + direction_source.get_travel_direction() * direction_indicator_length
		var heading_bearing: Dictionary = BearingUtility4D.compute_raw(observer_position, observer_basis, heading_target)
		var heading_rel_local := Vector4(heading_bearing.right_component, 0.0, heading_bearing.depth_component, heading_bearing.ana_offset)
		_draw_tracked_object(heading_rel_local, direction_marker_color, ellipse_center, ellipse_radii)
