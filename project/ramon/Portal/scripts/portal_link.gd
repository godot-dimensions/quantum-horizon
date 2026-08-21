extends Node
## The portal pair: placement, the linked state, and the only place a traveller
## is transformed.
##
## Portal's rules, as researched rather than assumed:
##   - A portal goes wherever you aim on a portalable surface, sliding to fit if
##     the aperture would hang off the edge (Valve calls that bumping).
##   - Shooting a colour that is already placed instantly deactivates the old
##     one; it animates shut while the new one animates open.
##   - A lone portal is a solid oval and nothing passes through it. Only a
##     linked pair is passable.
##   - Across a crossing, position, orientation AND velocity are carried from
##     the entry frame into the exit frame with a half turn, so speed survives
##     and only direction changes.

const ApertureScript := preload("res://ramon/Portal/scripts/portal_aperture.gd")

const HALF_TURN := Projection(
	Vector4(-1.0, 0.0, 0.0, 0.0),
	Vector4(0.0, 1.0, 0.0, 0.0),
	Vector4(0.0, 0.0, -1.0, 0.0),
	Vector4(0.0, 0.0, 0.0, 1.0))

const EXIT_PUSH := 0.5
const RECROSS_COOLDOWN := 0.15
## How far from a closing portal's plane the player has to be to be safe. The
## axis-aligned engine has no depenetration ("just stop moving" is the comment
## in its own source), so a traveller left inside restored geometry is a
## traveller stuck forever.
const SAFE_CLOSE_DISTANCE := 0.9

@onready var _player: CharacterBody4D = $"../Player"

var blue: Node4D = null
var yellow: Node4D = null

var teleport_count: int = 0
var last_teleport_speed: float = 0.0
var last_event: String = "no portals placed"

var _previous_distance: Dictionary = {}
var _cooldown: float = 0.0


func aperture_for(colour: StringName) -> Node4D:
	return blue if colour == &"blue" else yellow


func is_paired() -> bool:
	return _is_live(blue) and _is_live(yellow)


## A closing aperture still exists as a node for the length of its animation but
## must not count as a portal any more - Portal deactivates the old one the
## instant the new one is fired.
func _is_live(aperture: Node4D) -> bool:
	return aperture != null and is_instance_valid(aperture) and not aperture.is_closing


func place(surface: Node4D, world_point: Vector4, colour: StringName) -> bool:
	var requested: Vector2 = surface.local_of(world_point)
	var fit: Dictionary = surface.fit(requested, ApertureScript.HALF_WIDTH, ApertureScript.HALF_HEIGHT)
	if not fit.ok:
		last_event = "that surface is too small for a portal"
		return false

	var other: Node4D = aperture_for(&"yellow" if colour == &"blue" else &"blue")
	if surface.hole_colour != &"" and surface.hole_colour != colour:
		last_event = "the other portal is already on that surface"
		return false
	if _is_live(other) and other.surface == surface:
		last_event = "the other portal is already on that surface"
		return false

	_retire(colour, surface)

	var local: Vector2 = fit.local
	local = _snap_to_floor(surface, local)
	var aperture := ApertureScript.new()
	aperture.name = "Aperture_%s" % colour
	aperture.colour = colour
	aperture.surface = surface
	aperture.surface_local = local
	# Flush with the surface's inner face, never recessed into it: Valve places a
	# portal 0-8 units off its host, and the crossing plane has to sit where the
	# player meets the wall.
	aperture.position = surface.world_of(local) + surface.normal * (surface.thickness * 0.5)
	aperture.basis = Projection(surface.right, surface.up, surface.normal, Vector4(0.0, 0.0, 0.0, 1.0))
	add_child(aperture)
	# The aperture cuts and grows its own hole from here: it re-cuts the wall in
	# quantised steps as it opens, so the opening and the collar arrive together
	# rather than a full-size hole appearing under a tiny ring.
	aperture.build()

	if colour == &"blue":
		blue = aperture
	else:
		yellow = aperture

	_previous_distance.clear()
	last_event = "%s portal placed%s" % [colour, " (slid to fit)" if fit.get("bumped", false) else ""]
	return true


## Placement helper: a portal aimed near the base of a wall snaps flush with the
## floor.
##
## Not cosmetic. CharacterBody4D has no step-up of any kind and collision is
## axis-aligned boxes, so an opening whose bottom edge sits even 3 cm above the
## floor is a wall you cannot walk through - the portal would look open and
## refuse to admit you, which is precisely the failure Valve's design rule warns
## against. Valve solves the same class of problem with placement helpers and
## bumping; this is the one-dimensional version of it.
##
## Only applies to surfaces whose local "up" really is world up, i.e. walls. On a
## floor or ceiling the b axis runs horizontally and snapping would be nonsense.
const FLOOR_SNAP_RANGE := 0.45


func _snap_to_floor(surface: Node4D, local: Vector2) -> Vector2:
	if absf(surface.up.y) < 0.9:
		return local
	var hole_radius: float = ApertureScript.hole_radius()
	var gap: float = (local.y - hole_radius) - (-surface.half_b)
	if gap <= 0.0 or gap > FLOOR_SNAP_RANGE:
		return local
	return Vector2(local.x, -surface.half_b + hole_radius)


## Retires the existing portal of one colour. It stops counting as a portal
## immediately - Portal deactivates the old one the instant the new one is fired,
## and _is_live() enforces that - but its geometry collapses over the close
## animation rather than snapping shut, which is the whole point of a slow close.
##
## The exception is re-shooting the same surface: two holes cannot coexist in one
## surface's decomposition, so there the old one is sealed at once.
func _retire(colour: StringName, next_surface: Node4D) -> void:
	var aperture: Node4D = aperture_for(colour)
	if aperture == null or not is_instance_valid(aperture):
		return
	_push_traveller_clear(aperture)
	if aperture.surface != null and is_instance_valid(aperture.surface) and aperture.surface == next_surface:
		aperture.surface.close_hole()
		aperture.surface = null # Its animation must not touch the wall any more.
	aperture.start_closing()
	if colour == &"blue":
		blue = null
	else:
		yellow = null


## If the player is standing in the opening that is about to become wall again,
## move them clear on the room side first.
func _push_traveller_clear(aperture: Node4D) -> void:
	var normal: Vector4 = aperture.global_basis.z
	var offset: Vector4 = _player.global_position - aperture.global_position
	var distance: float = offset.dot(normal)
	if absf(distance) > SAFE_CLOSE_DISTANCE:
		return
	var across := Vector2(offset.dot(aperture.global_basis.x), offset.dot(aperture.global_basis.y))
	if across.length() > ApertureScript.hole_radius() + 0.4:
		return
	_player.global_position = aperture.global_position + normal * SAFE_CLOSE_DISTANCE
	last_event = "portal closed - you were pushed clear of it"


func _physics_process(delta_time: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta_time
	if not is_paired():
		return
	_check_crossing(blue, yellow)
	_check_crossing(yellow, blue)


func _check_crossing(entry: Node4D, exit: Node4D) -> void:
	var normal: Vector4 = entry.global_basis.z
	var distance: float = (_player.global_position - entry.global_position).dot(normal)
	var previous: float = _previous_distance.get(entry, distance)
	_previous_distance[entry] = distance

	if _cooldown > 0.0:
		return
	if not (previous > 0.0 and distance <= 0.0):
		return
	# Radial test, matching the disc actually cut in the wall: anywhere you can
	# physically pass you teleport, and anywhere you cannot you meet wall rather
	# than slipping through a corner the opening does not have.
	var contact: Vector4 = _player.global_position - normal * distance
	var offset: Vector4 = contact - entry.global_position
	var across := Vector2(offset.dot(entry.global_basis.x), offset.dot(entry.global_basis.y))
	if across.length() > ApertureScript.pass_radius():
		return
	_teleport(entry, exit)


func _teleport(entry: Node4D, exit: Node4D) -> void:
	var mapping: Projection = exit.global_basis * HALF_TURN * _transposed(entry.global_basis)
	var relative: Vector4 = _player.global_position - entry.global_position

	_player.global_position = exit.global_position + mapping * relative + exit.global_basis.z * EXIT_PUSH
	_player.linear_velocity = mapping * _player.linear_velocity
	_clear_destination(exit.global_basis.z)

	var mapped_basis: Projection = mapping * _player.global_basis
	mapped_basis.y = Vector4(0.0, 1.0, 0.0, 0.0)
	_player.global_basis = Basis4D.orthonormalized(mapped_basis)

	teleport_count += 1
	last_teleport_speed = _player.linear_velocity.length()
	last_event = "crossed %s -> %s at %.1f m/s" % [entry.colour, exit.colour, last_teleport_speed]
	_cooldown = RECROSS_COOLDOWN
	_previous_distance.clear()


## Destination clearance: never leave a traveller inside geometry.
##
## The exit preserves the traveller's offset from the entry opening, so arriving
## somewhere with a floor, ledge or step just behind the opening can land them
## partly inside it. That is unrecoverable on its own here: the axis-aligned
## engine has no depenetration ("TODO: Implement a proper depenetration
## algorithm. For now, just stop moving" is its own comment) and its safe margin
## is 1e-12, so a body overlapping by even a centimetre reports a negative travel
## ratio for every motion and is frozen for good. Measured exactly that: a player
## arrived 1.9 cm inside a ledge and never moved again.
##
## So probe with a test-only move and lift until clear. Valve does the same thing
## in spirit - place beyond the exit plane, then run a clearance test.
const CLEARANCE_STEP := 0.08
const CLEARANCE_ATTEMPTS := 12


func _clear_destination(exit_normal: Vector4) -> void:
	for attempt in range(CLEARANCE_ATTEMPTS):
		# The zero-motion move is not a no-op and must not be removed. A
		# test_only query is evaluated against a rect the engine cached at the
		# end of the previous real move_and_collide, and returns early before
		# refreshing it - so straight after a teleport it probes where the player
		# USED to be and cheerfully reports clear. A real (non-test) call
		# refreshes that cache. Same stale-rect trap that stops Area4D firing for
		# teleported bodies; see follow_up/engine_gotchas.md.
		_player.move_and_collide(Vector4.ZERO, false)
		var probe: KinematicCollision4D = _player.move_and_collide(exit_normal * 0.001, true)
		if probe == null or probe.get_travel_ratio() >= 0.0:
			if attempt > 0:
				last_event += " (lifted %.2f m clear)" % (attempt * CLEARANCE_STEP)
			return
		_player.global_position += Vector4(0.0, CLEARANCE_STEP, 0.0, 0.0)


## Orthonormal by construction, so the transpose is the inverse - cheaper and
## exact, where Projection.inverse() would run a general 4x4 inversion.
func _transposed(basis: Projection) -> Projection:
	return Projection(
		Vector4(basis.x.x, basis.y.x, basis.z.x, basis.w.x),
		Vector4(basis.x.y, basis.y.y, basis.z.y, basis.w.y),
		Vector4(basis.x.z, basis.y.z, basis.z.z, basis.w.z),
		Vector4(basis.x.w, basis.y.w, basis.z.w, basis.w.w))
