extends Node4D

## A lift that travels along W, carrying whoever is standing on it.
##
## A plain box, deliberately. A cubinder was tried first because it is the only
## curved 4D shape that both draws itself and has a flat top (so its bounding box
## top, which is all the AABB physics engine sees, matches the visible surface).
## It works mechanically and looks bad: cubinder meshes carry ZERO uvw entries, so
## they cannot take a texture, and the flat-shaded cross-section of the tetra mesh
## reads as noise rather than a surface. A box textures properly and collides
## exactly as it appears.
##
## Not a @tool script: it only ever runs during play, so the builder can spawn it
## in the editor without the disc wandering off while you author the room.
##
## WHY THE CARRY IS EXPLICIT. Measured during the engine audit:
## `AxisAlignedBoxPhysicsEngine4D` subtracts an obstacle's velocity only for
## `CharacterBody4D` and `RigidBody4D` - never `StaticBody4D` - so a moving static
## platform does not carry anything. Worse, there is no depenetration
## ("TODO: Implement a proper depenetration algorithm. For now, just stop
## moving."), so a platform that moves INTO the player leaves them stuck inside
## it rather than pushed along. The only workable answer is to move the rider
## ourselves by exactly the same delta, which is also what the brief asks for:
## "do not parent the player to a rendered platform mesh, use an explicit 4D
## carry/contact relationship."

## Where the lift starts and ends along w.
@export var w_from: float = 0.0
@export var w_to: float = 14.0

## Metres per second along w.
@export var speed: float = 3.0

## Seconds spent waiting at each end, so it can actually be boarded.
@export var dwell: float = 1.5

## Half the platform's width in the xz plane, and the height of its top surface.
## Both are set by the builder from the same numbers it used for the geometry, so
## the rider test cannot drift from the shape it is testing against.
@export var half_extent: float = 2.2
@export var top_y: float = 0.0

@export var player_path: NodePath = ^"../../Player"

## How close to the platform's top a body must be to count as aboard.
##
## MUST stay well under the step from the surrounding pad up onto the platform.
## At 0.45 against a 0.16 m step, standing on the PAD beside the lift satisfied
## this - so the lift dragged you along w while you were still on the pad, until
## you slid off its edge and fell. It read as the lift shoving you off, and
## jumping "fixed" it only because landing on top left the ambiguous zone.
const RIDE_TOLERANCE := 0.18

## Slop on the footprint test. Small: the rider's centre has to actually be over
## the platform, not merely near it, or standing alongside counts as aboard.
const RIDE_FOOTPRINT_SLOP := 0.1

var _player: CharacterBody4D = null
var _travelling_to_end: bool = true
var _waiting: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody4D
	if _player == null:
		push_warning("WLift4D: no CharacterBody4D at '%s', so nothing will be carried." % str(player_path))
	position.w = w_from


func _physics_process(delta_time: float) -> void:
	if _waiting > 0.0:
		_waiting -= delta_time
		return

	var target: float = w_to if _travelling_to_end else w_from
	var before: float = position.w
	var moved: float = move_toward(before, target, speed * delta_time)
	var step: float = moved - before
	if is_zero_approx(step):
		_travelling_to_end = not _travelling_to_end
		_waiting = dwell
		return

	position.w = moved
	if _is_being_ridden():
		# Same delta, same frame. The rider is moved directly rather than through
		# move_and_collide because this is not a collision - it is the platform
		# and its passenger keeping station with each other.
		_player.position.w += step


## Is the player standing on the platform? Checked in the xz plane against the disc's
## own radius, and vertically against its top surface.
##
## Deliberately ignores w: the rider and the disc share a w by construction while
## carried, and testing it would fight the very motion being applied.
func _is_being_ridden() -> bool:
	if _player == null:
		return false
	var here: Vector4 = _player.global_position
	var centre: Vector4 = global_position
	# Square, matching the box platform. A radial test would refuse a rider
	# standing on a perfectly solid corner.
	if absf(here.x - centre.x) > half_extent + RIDE_FOOTPRINT_SLOP or absf(here.z - centre.z) > half_extent + RIDE_FOOTPRINT_SLOP:
		return false
	# 0.875 is half the player capsule, so this is the feet.
	var feet: float = here.y - 0.875
	return absf(feet - top_y) < RIDE_TOLERANCE
