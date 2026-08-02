extends Control
## Player-centered alternate minimap - replaced the earlier volume-view
## minimap entirely (that one, plus its dedicated Camera4D/SubViewport rig
## and the player-trail sibling script it needed, has been removed as of
## this widget proving more useful).
##
## Draws a fixed ellipse representing the player's current 3-slice as a
## stable "horizontal" reference plane - it never rotates with the player's
## slice-rotation input, always drawn the same way; the world is expressed
## relative to it, not the other way around. A player marker sits fixed at
## its center. For each tracked object (the active target, and every active
## duck), projects its position onto the ellipse via right_component/
## depth_component (same oblique-projection math as any tilted top-down HUD:
## depth's contribution is scaled by the ellipse's own squash factor to
## match its tilt), then draws a vertical screen-space stem proportional to
## ana_offset - up if positive, down if negative, exactly as
## BearingUtility4D already defines the sign, not re-derived here -
## terminating in a dot marking the object's true off-plane position,
## tinted to match that object's real in-world color so targets and ducks
## stay distinguishable. Reads like an air-traffic-control altitude
## readout: a point on the plane, a stem showing height above/below it.
##
## Pure 2D math + drawing (like poi_arrow.gd) - no Camera4D/SubViewport
## involved, nothing rendered in 4D for this widget at all.

enum AxisLabelStyle {
	NONE,
	POS_NEG,
	CARDINAL,
}

enum AxisLineStyle {
	NONE,
	DIRECT,
	PROJECTED,
}

const ELLIPSE_SEGMENTS := 96
const NAT_LOG_2 := 0.6931471805599453094

## The distance in meters at which objects are halfway along to the far extent of the radar.
## The outer ring of the radar represents infinite distance using an exponential function.
const HALFWAY_METERS := 6.0
const MINOR_LINE_SPACING_MULTIPLIER := 1.5

## For W_IS_UP, true makes more sense at a glance since that's how it's presented
## in the editor, but false seems to feel better when purely navigating by radar.
## When pressing E to move the player ana, the targets move in the opposite direction.
## So false means "E makes the targets move up on the screen.",
## and true means "E makes the targets move down on the screen".
const W_IS_UP: bool = false

@export var ellipse_squash_factor: float = 0.55 # vertical radius = horizontal * this - "squashed ~50-60% vertically."
@export var ellipse_w_factor: float = 0.75 # How much to squash W "height" on the screen Y compared to Z.
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

## Matches gallery_target.tscn/duck_target.tscn's own albedo colors, so the
## off-plane marker for each object reads as "which one is this" at a glance.
const TARGET_COLOR := Color(0.9, 0.1, 0.1, 0.95)
const DUCK_COLOR := Color(1.0, 0.85, 0.1, 0.95)

## World-units-to-pixels for the projected point AND the stem length alike -
## one world unit is one unit, visually consistent across the whole widget.
#@export var units_to_pixels: float = 15.0

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../FlatPlane/DuckRowSpawner"


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


func _draw_tracked_object(relative_target_position: Vector4, marker_color: Color, ellipse_center: Vector2, ellipse_radii: Vector2) -> void:
	var rel_len: float = relative_target_position.length()
	var rel_len_exp: float = 1.0 - exp(-rel_len * (NAT_LOG_2 / HALFWAY_METERS))
	var scaled_target_pos: Vector4 = relative_target_position * (rel_len_exp / rel_len)
	# Same oblique-projection math as any tilted top-down HUD: right_component
	# maps straight to horizontal screen offset; depth_component's
	# contribution is scaled by the ellipse's own squash factor so a "forward"
	# step moves the projected point along the ellipse's short/vertical axis,
	# matching its tilt, not the full horizontal-equivalent distance.
	var projected: Vector2 = ellipse_center + Vector2(
		scaled_target_pos.x * ellipse_radii.x,
		scaled_target_pos.z * ellipse_radii.y,
	)
	draw_circle(projected, projected_point_radius, projected_point_color)

	# Vertical stem (screen-space, not world-space) proportional to ana_offset.
	var w_offset: float = -scaled_target_pos.w if W_IS_UP else scaled_target_pos.w
	var stem_end: Vector2 = projected + Vector2(0.0, w_offset * ellipse_radii.y)
	draw_line(projected, stem_end, Color(marker_color.r, marker_color.g, marker_color.b, stem_alpha), 2.0)
	draw_circle(stem_end, off_plane_dot_radius, marker_color)


func _draw_axes(ellipse_center: Vector2, ellipse_radii: Vector2, player_basis_inv: Projection) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size
	# Draw axis labels.
	var label_map: Dictionary
	match axis_label_style:
		AxisLabelStyle.NONE:
			pass
		AxisLabelStyle.POS_NEG:
			label_map = {
				"+X": player_basis_inv.x,
				"-X": -player_basis_inv.x,
				"+Z": player_basis_inv.z,
				"-Z": -player_basis_inv.z,
				"+W": player_basis_inv.w,
				"-W": -player_basis_inv.w,
			}
		AxisLabelStyle.CARDINAL:
			label_map = {
				"N": -player_basis_inv.z, # North.
				"S": player_basis_inv.z, # South.
				"E": player_basis_inv.x, # East.
				"W": -player_basis_inv.x, # West.
				"A": player_basis_inv.w, # Anth.
				"K": -player_basis_inv.w, # Kenth.
			}
	for label in label_map.keys():
		var axis_vec: Vector4 = label_map[label]
		var projected: Vector2 = ellipse_center + Vector2(
			axis_vec.x * ellipse_radii.x,
			axis_vec.z * ellipse_radii.y,
		)
		var w_offset: float = -axis_vec.w if W_IS_UP else axis_vec.w
		var stem_end: Vector2 = projected + Vector2(0.0, w_offset * ellipse_radii.y)
		var total_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var char_offset: Vector2 = Vector2(-total_width / 2.0, font.get_ascent(font_size))
		if w_offset > 0.0:
			char_offset.y *= 0.85
		else:
			# If the stem is pointing up, draw the label above it instead of below.
			char_offset.y *= -0.15
		var char_pos: Vector2 = stem_end + char_offset
		for i in label.length():
			var character: String = label[i]
			draw_char(font, char_pos, character, font_size, ellipse_line_color)
			char_pos.x += font.get_char_size(character.unicode_at(0), font_size).x
	# Draw axis lines.
	var axis_line_colors := PackedColorArray([
		Vector4D.axis_color(0), # X
		Vector4D.axis_color(1), # Y
		Vector4D.axis_color(2), # Z
		Vector4D.axis_color(3), # W
	])
	for i in range(axis_line_colors.size()):
		var axis_vec: Vector4 = player_basis_inv[i]
		var proj_offset: Vector2 = Vector2(
			axis_vec.x * ellipse_radii.x,
			axis_vec.z * ellipse_radii.y,
		)
		var w_offset: float = -axis_vec.w if W_IS_UP else axis_vec.w
		var stem_offset: Vector2 = proj_offset + Vector2(0.0, w_offset * ellipse_radii.y)
		match axis_line_style:
			AxisLineStyle.NONE:
				pass
			AxisLineStyle.DIRECT:
				draw_line(ellipse_center, ellipse_center + stem_offset, axis_line_colors[i], 1.0)
				draw_line(ellipse_center, ellipse_center - stem_offset, axis_line_colors[i], 1.0)
			AxisLineStyle.PROJECTED:
				draw_line(ellipse_center, ellipse_center + proj_offset, axis_line_colors[i], 1.0)
				draw_line(ellipse_center + proj_offset, ellipse_center + stem_offset, axis_line_colors[i], 1.0)
				draw_line(ellipse_center, ellipse_center - proj_offset, axis_line_colors[i], 1.0)
				draw_line(ellipse_center - proj_offset, ellipse_center - stem_offset, axis_line_colors[i], 1.0)


func _draw_ring_label(bottom_center: Vector2, text: String, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = ThemeDB.fallback_font_size
	var total_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Centered under bottom_center, baseline dropped below it by the ascent plus a small gap.
	var char_pos: Vector2 = bottom_center + Vector2(-total_width / 2.0, font.get_ascent(font_size) * 0.85)
	for i in text.length():
		var character: String = text[i]
		draw_char(font, char_pos, character, font_size, color)
		char_pos.x += font.get_char_size(character.unicode_at(0), font_size).x


func _draw_ellipse_rings(ellipse_center: Vector2, ellipse_radii: Vector2) -> void:
	var ellipse_points: PackedVector2Array = _ellipse_points(ellipse_center, ellipse_radii)
	# Draw a filled ellipse first as a background.
	var fill_colors := PackedColorArray()
	fill_colors.resize(ellipse_points.size())
	fill_colors.fill(ellipse_fill_color)
	draw_polygon(ellipse_points, fill_colors)
	# Draw minor rings between the center and major ring.
	var font_ascent: float = ThemeDB.fallback_font.get_ascent(ThemeDB.fallback_font_size)
	var minor_color: Color = ellipse_line_color
	minor_color.a *= 0.5
	var last_minor_radii_y: float = -1.0
	for i in range(1, 12 * MINOR_LINE_SPACING_MULTIPLIER): # Skip 0 (would be a zero size ring).
		var minor_radii: Vector2 = ellipse_radii * (1.0 - exp(-i * (NAT_LOG_2 / MINOR_LINE_SPACING_MULTIPLIER)))
		var minor_points: PackedVector2Array = _ellipse_points(ellipse_center, minor_radii)
		draw_polyline(minor_points + PackedVector2Array([minor_points[0]]), minor_color, 1.0, true)
		if minor_radii.y - last_minor_radii_y > font_ascent * 1.25:
			# Inverse of the exponential mapping used for tracked objects, so each
			# ring's label matches the meters value that would project onto it.
			var ratio: float = HALFWAY_METERS / MINOR_LINE_SPACING_MULTIPLIER
			var ring_meters: float = i * ratio
			var fmt: String = "%.1fm"
			if is_equal_approx(int(ratio), ratio):
				fmt = "%dm"
			_draw_ring_label(ellipse_center + Vector2(0.0, -minor_radii.y), fmt % ring_meters, minor_color)
		last_minor_radii_y = minor_radii.y
	# Draw the major ring last to ensure it goes on top.
	draw_polyline(ellipse_points + PackedVector2Array([ellipse_points[0]]), ellipse_line_color, 2.0, true)


func _draw() -> void:
	# Calculate ellipse parameters based on current control size
	var ellipse_margin_ratio: float = 0.9
	var ellipse_center: Vector2 = size * 0.5
	var ellipse_radii: Vector2 = ellipse_center * ellipse_margin_ratio
	ellipse_radii.y = ellipse_radii.x * ellipse_squash_factor
	ellipse_center.y = size.y * (0.5 + 0.5 * ellipse_margin_ratio) - ellipse_radii.x * ellipse_squash_factor

	_draw_ellipse_rings(ellipse_center, ellipse_radii)
	draw_circle(ellipse_center, player_marker_radius, player_marker_color)

	# Each entry: [world position, marker color]. The active target and
	# every currently-active duck.
	var tracked_objects: Array = []
	if spawner._current_target != null:
		tracked_objects.append([spawner._current_target.global_position, TARGET_COLOR])
	for duck in duck_spawner._ducks:
		tracked_objects.append([duck.global_position, DUCK_COLOR])

	var player_basis_inv: Projection = player.global_basis.inverse()
	# Draw axis letter labels and lines.
	_draw_axes(ellipse_center, ellipse_radii, player_basis_inv)
	# Draw tracked objects.
	for entry in tracked_objects:
		var rel_pos_global: Vector4 = entry[0] - player.global_position
		var rel_pos_local: Vector4 = player_basis_inv * rel_pos_global
		_draw_tracked_object(rel_pos_local, entry[1], ellipse_center, ellipse_radii)
