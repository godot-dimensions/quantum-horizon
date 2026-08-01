extends Control
## Player-centered alternate minimap concept - separate from the existing
## volume-view minimap (minimap_camera.gd/minimap_overlay.gd), which is left
## alone/paused for later comparison.
##
## Draws a fixed ellipse representing the player's current 3-slice as a
## stable "horizontal" reference plane - it never rotates with the player's
## slice-rotation input, always drawn the same way; the world is expressed
## relative to it, not the other way around. A player marker sits fixed at
## its center. For each tracked object (currently just the active target),
## projects its position onto the ellipse via right_component/
## depth_component (same oblique-projection math as any tilted top-down HUD:
## depth's contribution is scaled by the ellipse's own squash factor to
## match its tilt), then draws a vertical screen-space stem proportional to
## ana_offset - up if positive, down if negative, exactly as
## BearingUtility4D already defines the sign, not re-derived here -
## terminating in a dot marking the object's true off-plane position. Reads
## like an air-traffic-control altitude readout: a point on the plane, a
## stem showing height above/below it.
##
## Pure 2D math + drawing (like poi_arrow.gd) - no Camera4D/SubViewport
## involved, so there's no rendered 4D scene here and nothing from the
## volume-view minimap's camera/viewport rig to share. The circular framing
## shader isn't reused either - this widget's outer boundary is just its
## own plain Control rect; the ellipse is content drawn inside it, not an
## outer crop.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

const ELLIPSE_SEGMENTS := 48

@export var ellipse_radius_x: float = 85.0
@export var ellipse_squash_factor: float = 0.55 # vertical radius = horizontal * this - "squashed ~50-60% vertically."
@export var ellipse_line_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var ellipse_fill_color: Color = Color(1.0, 1.0, 1.0, 0.07)

@export var player_marker_radius: float = 4.0
@export var player_marker_color: Color = Color(1.0, 1.0, 1.0, 0.95)

@export var projected_point_radius: float = 3.5
@export var projected_point_color: Color = Color(0.6, 0.6, 0.6, 0.9)

@export var off_plane_dot_radius: float = 4.0
@export var off_plane_dot_color: Color = Color(0.95, 0.25, 0.85, 0.95)
@export var stem_color: Color = Color(0.95, 0.25, 0.85, 0.6)

## World-units-to-pixels for the projected point AND the stem length alike -
## one world unit is one unit, visually consistent across the whole widget.
@export var units_to_pixels: float = 8.0

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"

var _ellipse_center: Vector2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_ellipse_center = size / 2.0


func _process(_delta: float) -> void:
	queue_redraw()


func _ellipse_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in ELLIPSE_SEGMENTS:
		var angle: float = TAU * i / ELLIPSE_SEGMENTS
		points.append(_ellipse_center + Vector2(cos(angle) * ellipse_radius_x, sin(angle) * ellipse_radius_x * ellipse_squash_factor))
	return points


func _draw_tracked_object(target_position: Vector4) -> void:
	var bearing: Dictionary = BearingUtility4D.compute(player, target_position)
	# Same oblique-projection math as any tilted top-down HUD: right_component
	# maps straight to horizontal screen offset; depth_component's
	# contribution is scaled by the ellipse's own squash factor so a "forward"
	# step moves the projected point along the ellipse's short/vertical axis,
	# matching its tilt, not the full horizontal-equivalent distance.
	var projected: Vector2 = _ellipse_center + Vector2(
		bearing.right_component * units_to_pixels,
		bearing.depth_component * units_to_pixels * ellipse_squash_factor,
	)
	draw_circle(projected, projected_point_radius, projected_point_color)

	# Vertical stem (screen-space, not world-space) proportional to
	# ana_offset - up if positive, down if negative, using the sign exactly
	# as BearingUtility4D already defines it. Screen-space up is negative-Y,
	# so a positive ana_offset (drawn "up") needs the sign flipped here.
	var stem_end: Vector2 = projected + Vector2(0.0, -bearing.ana_offset * units_to_pixels)
	draw_line(projected, stem_end, stem_color, 2.0)
	draw_circle(stem_end, off_plane_dot_radius, off_plane_dot_color)


func _draw() -> void:
	var ellipse_points: PackedVector2Array = _ellipse_points()
	var fill_colors := PackedColorArray()
	fill_colors.resize(ellipse_points.size())
	fill_colors.fill(ellipse_fill_color)
	draw_polygon(ellipse_points, fill_colors)
	draw_polyline(ellipse_points + PackedVector2Array([ellipse_points[0]]), ellipse_line_color, 2.0, true)

	draw_circle(_ellipse_center, player_marker_radius, player_marker_color)

	# Currently just the active target - a list so tracking more objects
	# later (e.g. ducks) is a one-line addition, not a restructure.
	var tracked_positions: Array = []
	if spawner._current_target != null:
		tracked_positions.append(spawner._current_target.global_position)

	for target_position in tracked_positions:
		_draw_tracked_object(target_position)
