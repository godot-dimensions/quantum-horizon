extends Control
## Shooting gallery minimap overlay, drawn directly on top of MiniMapContainer
## (same rect). Ported from godot_boids_4d's minimap_overlay.gd - always
## drawn now (no is_volume_view() gating; there's no second main view/toggle
## here, the mini-map is always showing the volume view). Draws:
##   1. A trail of dots at recent player positions, fading out over
##      player_trail.trail_duration seconds.
##   2. A big, mostly-transparent "orientation plane" spanned by the player's
##      forward/right vectors - the x-z-w cross-section of the player's
##      current view. Since the player body only ever rotates in the
##      xz/xw/zw planes (pitch lives separately on PlayerHead),
##      player.global_basis's forward/right vectors are always exactly
##      confined to x-z-w already. This is the slice-plane intersection
##      indicator - genuinely live, tied to the player's real current basis,
##      not a static decoration.
##   3. A smaller, higher-opacity "cone" on top marking the player's exact
##      current facing within that plane.
##
## Every point is projected with minimap_camera.world_to_viewport(), the same
## function the Wireframe Canvas rendering engine itself uses internally to
## draw the mini-map's actual scene - so this lines up exactly with whatever
## is really rendered underneath, not an approximate schematic mapping. 4D
## mesh geometry has no per-camera visibility layer in this engine (any
## MeshInstance4D is visible to every Camera4D everywhere), so real 4D
## objects for these would leak into the main view too; a 2D overlay is the
## only way to keep them mini-map-only.
##
## clip_contents is enabled so a point that projects wildly off-screen gets
## clipped to this control's own rect instead of spilling into the main view.
##
## Distances below are scaled down from godot_boids_4d's originals (~1/3) to
## fit the shooting gallery's much smaller footprint (floors ~+-5, vs. boids'
## ~14-unit half-extents).

@export var dot_radius: float = 3.0
@export var trail_color: Color = Color(0.95, 0.85, 0.25)

@export var plane_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var plane_fill_alpha: float = 0.15
@export var plane_forward_distance: float = 3.0
@export var plane_back_distance: float = 1.5
@export var plane_side_distance: float = 2.0

@export var cone_color: Color = Color(0.3, 0.6, 1.0, 0.65)
@export var cone_length_distance: float = 2.0
@export var cone_width_distance: float = 0.6

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var player_trail: Node = $"../FlatPlane/PlayerTrail"
@onready var minimap_camera: Camera4D = $"../MiniMapContainer/MiniMapViewport/MiniMapCamera"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for entry in player_trail.get_trail():
		var age: float = entry["age"]
		var alpha: float = clamp(1.0 - (age / player_trail.trail_duration), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var screen_pos: Vector2 = minimap_camera.world_to_viewport(entry["position"])
		draw_circle(screen_pos, dot_radius, Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * alpha))

	var player_pos: Vector4 = player.global_position
	var basis: Projection = player.global_basis
	var forward: Vector4 = basis * Vector4(0, 0, -1, 0)
	var right: Vector4 = basis * Vector4(1, 0, 0, 0)

	# Big orientation plane: spanned by the player's forward/right directions
	# in x-z-w space (longer forward than back, so the shape itself still
	# reads as "which way is forward"), projected point-by-point through the
	# real camera so it matches the actual render's perspective/scale.
	var p_forward: Vector2 = minimap_camera.world_to_viewport(player_pos + forward * plane_forward_distance)
	var p_back: Vector2 = minimap_camera.world_to_viewport(player_pos - forward * plane_back_distance)
	var p_left: Vector2 = minimap_camera.world_to_viewport(player_pos + right * plane_side_distance)
	var p_right: Vector2 = minimap_camera.world_to_viewport(player_pos - right * plane_side_distance)
	var plane_points := PackedVector2Array([p_forward, p_left, p_back, p_right])
	var plane_fill_color := Color(plane_color.r, plane_color.g, plane_color.b, plane_fill_alpha)
	draw_polygon(plane_points, [plane_fill_color, plane_fill_color, plane_fill_color, plane_fill_color])
	draw_polyline(PackedVector2Array([p_forward, p_left, p_back, p_right, p_forward]), plane_color, 1.5, true)

	# Small, higher-opacity cone on top marking the exact current facing -
	# also doubles as the "player indicator, centered" element: with
	# minimap_camera.gd tracking the player's x/z/w every frame, player_pos
	# always projects to dead-center of the mini-map by construction.
	var cone_tip: Vector2 = minimap_camera.world_to_viewport(player_pos + forward * cone_length_distance)
	var cone_left: Vector2 = minimap_camera.world_to_viewport(player_pos + right * cone_width_distance)
	var cone_right: Vector2 = minimap_camera.world_to_viewport(player_pos - right * cone_width_distance)
	draw_polygon(PackedVector2Array([cone_tip, cone_left, cone_right]), [cone_color, cone_color, cone_color])
