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

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

const ELLIPSE_SEGMENTS := 48

## Everything below is a fraction of this control's own current size, not a
## fixed pixel value - shooting_gallery.tscn anchors this widget's rect to a
## fraction of the viewport too (rather than a fixed-pixel box), so between
## the two the whole radar scales up automatically in fullscreen/higher
## resolutions instead of staying pinned to a size tuned for one specific
## window (confirmed bug report: correct in a ~1152x648 window, "quite
## small" in fullscreen at a much higher resolution, because the box and
## everything drawn inside it were fixed-pixel-sized regardless of the
## actual viewport). Recomputed every frame in _process(), not just once at
## _ready(), so a live window resize or fullscreen toggle is picked up too.
@export var ellipse_radius_x_fraction: float = 0.4 # of this control's own width.
@export var ellipse_squash_factor: float = 0.55 # vertical radius = horizontal * this - "squashed ~50-60% vertically."
@export var ellipse_line_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var ellipse_fill_color: Color = Color(1.0, 1.0, 1.0, 0.07)

@export var player_marker_radius_fraction: float = 0.0375 # of ellipse_radius_x.
@export var player_marker_color: Color = Color(1.0, 1.0, 1.0, 0.95)

@export var projected_point_radius_fraction: float = 0.03125 # of ellipse_radius_x.
@export var projected_point_color: Color = Color(0.6, 0.6, 0.6, 0.9)

@export var off_plane_dot_radius_fraction: float = 0.0375 # of ellipse_radius_x.
@export var stem_alpha: float = 0.6

## Matches gallery_target.tscn/duck_target.tscn's own albedo colors, so the
## off-plane marker for each object reads as "which one is this" at a glance.
const TARGET_COLOR := Color(0.9, 0.1, 0.1, 0.95)
const DUCK_COLOR := Color(1.0, 0.85, 0.1, 0.95)

## World-units-to-pixels for the projected point AND the stem length alike,
## as a fraction of ellipse_radius_x so it scales along with everything else
## rather than staying a fixed pixel-per-world-unit value.
@export var units_to_pixels_fraction: float = 0.09375

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../FlatPlane/DuckRowSpawner"

var _ellipse_center: Vector2
var _ellipse_radius_x: float
var _units_to_pixels: float


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	_update_derived_sizes()
	queue_redraw()


func _update_derived_sizes() -> void:
	_ellipse_radius_x = size.x * ellipse_radius_x_fraction
	_units_to_pixels = _ellipse_radius_x * units_to_pixels_fraction
	# Horizontally centered; vertically positioned so the ellipse's own
	# bottom edge lands exactly on this control's bottom edge (which the
	# scene anchors flush to the true screen bottom) rather than centered
	# in the box with margin on both sides.
	_ellipse_center = Vector2(size.x / 2.0, size.y - _ellipse_radius_x * ellipse_squash_factor)


func _ellipse_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var angle: float = TAU * i / ELLIPSE_SEGMENTS
		points.append(_ellipse_center + Vector2(cos(angle) * _ellipse_radius_x, sin(angle) * _ellipse_radius_x * ellipse_squash_factor))
	return points


func _draw_tracked_object(target_position: Vector4, marker_color: Color) -> void:
	var bearing: Dictionary = BearingUtility4D.compute(player, target_position)
	# Same oblique-projection math as any tilted top-down HUD: right_component
	# maps straight to horizontal screen offset; depth_component's
	# contribution is scaled by the ellipse's own squash factor so a "forward"
	# step moves the projected point along the ellipse's short/vertical axis,
	# matching its tilt, not the full horizontal-equivalent distance.
	var projected: Vector2 = _ellipse_center + Vector2(
		bearing.right_component * _units_to_pixels,
		bearing.depth_component * _units_to_pixels * ellipse_squash_factor,
	)
	draw_circle(projected, _ellipse_radius_x * projected_point_radius_fraction, projected_point_color)

	# Vertical stem (screen-space, not world-space) proportional to
	# ana_offset - up if positive, down if negative, using the sign exactly
	# as BearingUtility4D already defines it. Screen-space up is negative-Y,
	# so a positive ana_offset (drawn "up") needs the sign flipped here.
	var stem_end: Vector2 = projected + Vector2(0.0, -bearing.ana_offset * _units_to_pixels)
	draw_line(projected, stem_end, Color(marker_color.r, marker_color.g, marker_color.b, stem_alpha), 2.0)
	draw_circle(stem_end, _ellipse_radius_x * off_plane_dot_radius_fraction, marker_color)


func _draw() -> void:
	var ellipse_points: PackedVector2Array = _ellipse_points()
	var fill_colors := PackedColorArray()
	fill_colors.resize(ellipse_points.size())
	fill_colors.fill(ellipse_fill_color)
	draw_polygon(ellipse_points, fill_colors)
	draw_polyline(ellipse_points + PackedVector2Array([ellipse_points[0]]), ellipse_line_color, 2.0, true)

	draw_circle(_ellipse_center, _ellipse_radius_x * player_marker_radius_fraction, player_marker_color)

	# Each entry: [world position, marker color]. The active target and
	# every currently-active duck.
	var tracked_objects: Array = []
	if spawner._current_target != null:
		tracked_objects.append([spawner._current_target.global_position, TARGET_COLOR])
	for duck in duck_spawner._ducks:
		tracked_objects.append([duck.global_position, DUCK_COLOR])

	for entry in tracked_objects:
		_draw_tracked_object(entry[0], entry[1])
