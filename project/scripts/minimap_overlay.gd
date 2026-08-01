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
## Distances below are scaled to the shooting gallery's own footprint
## (floors ~+-5, vs. boids' ~14-unit half-extents) - the plane/cone distances
## are deliberately large enough to span the full visible mini-map (not just
## a small patch near the player), so the slice intersection with far-away
## objects is actually visible.
##
## solid_fill (below) is a Wireframe-Canvas-engine limitation workaround, not
## an engine feature: WireframeCanvasRenderingEngine4D is genuinely edge-only
## at the C++ level (Mesh4D only exposes get_edge_indices(), no face/triangle
## data at all), so "translucent solid objects" can't come from the render
## engine itself without real new engine work (new mesh-face APIs plus a
## depth-sorted fill rasterizer - a much bigger, riskier change than anything
## else here, since it's shared engine code). Instead this draws known
## objects (floors, barrier, current target, ducks) as translucent filled
## shapes directly, using the exact same world_to_viewport() projection the
## trail/plane/cone already use, layered under the wireframe edges for a
## "solid-with-crisp-outlines" look.

@export var dot_radius: float = 3.0
@export var trail_color: Color = Color(0.95, 0.85, 0.25)

@export var plane_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var plane_fill_alpha: float = 0.15
@export var plane_forward_distance: float = 20.0
@export var plane_back_distance: float = 6.0
@export var plane_side_distance: float = 12.0

@export var cone_color: Color = Color(0.3, 0.6, 1.0, 0.65)
@export var cone_length_distance: float = 6.0
@export var cone_width_distance: float = 1.5

## Known static geometry, mirroring shooting_gallery.tscn's own floor/barrier
## dimensions. minimap_camera.gd's y-w swap makes screen-x = world-x and
## screen-y = world-w (z is depth/perspective-scale only, not a screen
## position axis) - so a fillable, non-degenerate quad needs corners that
## actually vary across x AND w (each floor's real x/w half-extent is 5,
## same as the box shapes in shooting_gallery.tscn), at a single
## representative z (each floor's own center depth). A single fixed w for
## all 4 corners (as originally written) collapses every corner to the same
## screen-y, i.e. a zero-area line, not a quad - confirmed via
## world_to_viewport() before landing on this fix. Update these if the
## scene's floor sizes ever change - this is a schematic duplicate, not read
## from the scene live.
const ORANGE_FLOOR_CORNERS := [
	Vector4(-5, 0, 0, -5), Vector4(5, 0, 0, -5), Vector4(5, 0, 0, 5), Vector4(-5, 0, 0, 5),
]
const GREEN_FLOOR_CORNERS := [
	Vector4(-5, 0, 7, -5), Vector4(5, 0, 7, -5), Vector4(5, 0, 7, 5), Vector4(-5, 0, 7, 5),
]
const BARRIER_CORNERS := [
	Vector4(-5, 0, 5, -5), Vector4(5, 0, 5, -5), Vector4(5, 0, 5, 5), Vector4(-5, 0, 5, 5),
]
const ORANGE_FLOOR_FILL := Color(1.0, 0.6, 0.1, 0.3)
const GREEN_FLOOR_FILL := Color(0.2, 0.8, 0.2, 0.3)
const BARRIER_FILL := Color(0.5, 0.5, 0.5, 0.5)
const TARGET_FILL := Color(0.9, 0.1, 0.1, 0.7)
const DUCK_FILL := Color(1.0, 0.85, 0.1, 0.7)
const OBJECT_DOT_RADIUS := 5.0

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var player_trail: Node = $"../FlatPlane/PlayerTrail"
@onready var minimap_camera: Camera4D = $"../MiniMapContainer/MiniMapViewport/MiniMapCamera"
@onready var target_spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../FlatPlane/DuckRowSpawner"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_delta: float) -> void:
	queue_redraw()


func _draw_filled_quad(corners: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for corner in corners:
		points.append(minimap_camera.world_to_viewport(corner))
	var colors := PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	draw_polygon(points, colors)


func _draw() -> void:
	_draw_filled_quad(ORANGE_FLOOR_CORNERS, ORANGE_FLOOR_FILL)
	_draw_filled_quad(GREEN_FLOOR_CORNERS, GREEN_FLOOR_FILL)
	_draw_filled_quad(BARRIER_CORNERS, BARRIER_FILL)

	if target_spawner._current_target != null:
		var target_screen_pos: Vector2 = minimap_camera.world_to_viewport(target_spawner._current_target.global_position)
		draw_circle(target_screen_pos, OBJECT_DOT_RADIUS, TARGET_FILL)
	for duck in duck_spawner._ducks:
		var duck_screen_pos: Vector2 = minimap_camera.world_to_viewport(duck.global_position)
		draw_circle(duck_screen_pos, OBJECT_DOT_RADIUS, DUCK_FILL)

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
