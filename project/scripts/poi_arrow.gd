extends Control
## Milestone 5 initial test: a simple flat triangle HUD element, bottom-
## center of the screen, rotated to point the shortest way to turn (ordinary
## yaw, in the Player body's current local x/z plane) from the Player's
## current facing toward the center of the spawn area. Reuses BearingUtility4D
## (built in Milestone 3 for exactly this) - right_component/depth_component
## are plain dot products against whatever the Player body's basis columns
## currently are, so they already correctly account for any slice-rotation
## (rotate_4d, xw/zw) the player has applied, not just ordinary yaw.
##
## Reads the Player body directly, NOT the camera - pitch lives only on
## PlayerHead, layered on top of Player's basis purely for look direction, and
## has no bearing on which way to turn. Going through the camera folded pitch
## into the result (confirmed bug: the arrow drifted just from looking up/
## down, no turning involved).
##
## Deliberately ignores ana_offset/w entirely here - "turn" in the sense
## asked for is normal horizontal facing, not w-slice alignment. That's a
## separate, later concern if wanted (e.g. a second indicator or color cue).

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

## Spawn positions are uniform-random around the origin (target_spawner.gd's
## XZ_RANGE/W_RANGE), so the origin is the spawn area's actual center.
const SPAWN_AREA_CENTER := Vector4(0.0, 0.0, 0.0, 0.0)

const TRIANGLE_SIZE := 28.0
## Bright red rather than white/gray - the scene's floor has no material
## override (renders in the default fallback white), so a near-white or gray
## triangle would blend into the background depending on which way it's
## pointing.
const TRIANGLE_COLOR := Color(1.0, 0.15, 0.1, 0.95)

## Below this horizontal distance to the target, right_component/
## depth_component are both near zero and atan2 on them is degenerate -
## sub-centimeter position noise swings the result across the whole circle.
## The player's own spawn point is exactly the spawn area's horizontal
## center, so this triggers immediately at game start otherwise. Freeze the
## last real direction instead of chasing a meaningless one.
const DEAD_ZONE_RADIUS := 0.5

@onready var player: CharacterBody4D = $"../FlatPlane/Player"

func _ready() -> void:
	pivot_offset = size / 2.0

func _process(_delta: float) -> void:
	var bearing: Dictionary = BearingUtility4D.compute(player, SPAWN_AREA_CENTER)
	var horizontal_distance: float = Vector2(bearing.right_component, bearing.depth_component).length()
	if horizontal_distance < DEAD_ZONE_RADIUS:
		return
	# Signed angle from "forward" (local -z) to the target, in the plane
	# spanned by the Player's current local x/z columns - positive means the
	# target is to the right. Godot's 2D rotation is clockwise-positive, so
	# this directly matches: rotating the "points up" triangle clockwise by
	# this angle sweeps it toward "points right" first, exactly when the
	# target actually is to the right.
	rotation = atan2(bearing.right_component, -bearing.depth_component)

func _draw() -> void:
	var points := PackedVector2Array([
		Vector2(TRIANGLE_SIZE / 2.0, 0.0), # apex, pointing "up" at rotation=0
		Vector2(TRIANGLE_SIZE, TRIANGLE_SIZE),
		Vector2(0.0, TRIANGLE_SIZE),
	])
	draw_colored_polygon(points, TRIANGLE_COLOR)
