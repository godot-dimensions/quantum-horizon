extends Node4D

## The camera that takes over once you sit down.
##
## IT IS A SECOND CAMERA, NOT THE PLAYER'S ONE MOVED. Driving the player's own camera
## would mean fighting `pen_orbit_rig_4d.gd` for the same transform every frame, and
## handing it back would mean reconstructing a yaw and a pitch that the rig believes it
## still owns. A duplicate of that camera - duplicated rather than built, so it inherits
## the cross-section renderer and the W fade distance exactly - is switched to `current`
## instead. Handing back is one boolean.
##
## IT EASES, IT NEVER CUTS. A cut in a first-person game is a teleport: you were standing
## somewhere, and now you are elsewhere with no account of how. Every move here is an
## exponential ease toward a wanted eye and a wanted focus, so the handover reads as the
## camera leaving you rather than as the room jumping.
##
## AND IT NEVER CHANGES YOUR W. This is the one rule that is not taste. The camera's slice
## is what exists; a shot that drifted through W would silently change the shape of the
## exhibit, and nothing on screen would say whether the object had changed or the viewer
## had. Every eye and every focus is forced to the player's own w on the way out.
##
## EYE AND FOCUS ARE INTERPOLATED, NOT THE BASIS. Interpolating two 4D bases means
## interpolating two `Projection`s, which does not stay orthonormal and drifts into a shear
## within a second. Two points do not have that problem, and the basis is rebuilt from them
## every frame - which is also how a real camera rig is aimed.
##
## THE SHOT LIST IS SHORT ON PURPOSE. A slow orbit is the default move for a presentation
## and it is usually the wrong one: it gives every angle equal weight, so nothing is
## emphasised, and here it would actively fight two of the exhibits - the goat's build is
## about watching handles ARRIVE, and the creature's gait only reads side-on. So there are
## pushes, drifts and holds, no orbits, and most beats hold. A move earns its place by
## being the information: the camera drifts toward the plinth that has nothing on it, and
## tracks away from the stop conditions that are not on your slice.

@export var player_path: NodePath
@export var presenter_path: NodePath

## How long the camera takes to settle into a new framing. This is the whole character of
## the rig: short is a cut with the edges rounded off, long is a drifting dream. 1.6 reads
## as a deliberate operator.
@export_range(0.2, 6.0, 0.1) var settle_seconds: float = 1.6
## And the first move of all. It used to be 2.6, which was longer than the sit it belonged
## to: the camera was still travelling toward its framing of the chair when the player
## landed in it and the shot changed to the presenter, so the one shot the whole beat
## exists for was never actually reached. A handover has to finish inside the thing it is
## handing over.
@export_range(0.2, 8.0, 0.1) var handover_seconds: float = 1.3
@export_range(0.5, 3.0, 0.05) var eye_height: float = 1.25
## How far back the camera stands to watch you sit, and how high.
@export_range(1.5, 10.0, 0.1) var sit_distance: float = 4.2
@export_range(0.5, 5.0, 0.1) var sit_height: float = 1.7

## Each shot is an eye and a point to look at, and optionally a second pair it drifts to
## over the length of the beat. `follow` aims at the presenter wherever he actually is,
## for the one shot whose subject is a person walking.
const SHOTS := {
	# The seat's own eyeline, held. Filled in when you sit, because it is wherever you
	# chose to sit rather than a spot chosen for you.
	"house": {"seat": true, "focus": Vector4(0.0, 1.4, 0.0, 0.0)},
	# Watching yourself sit down. Also filled in at run time, from the chair - it is the
	# one shot whose subject is a piece of furniture rather than the stage.
	"sitting": {"sit": true},
	# The whole room, from behind and above the front rows.
	"wide": {"eye": Vector4(0.0, 3.4, 10.4, 0.0), "focus": Vector4(0.0, 1.6, 0.0, 0.0)},
	# Him, wherever he is. The only moving subject in the room.
	"presenter": {"eye": Vector4(3.2, 2.6, 8.6, 0.0), "follow": true},
	# A slow dolly in. For an exhibit that is arriving, or one that is absent.
	"push": {"eye": Vector4(0.0, 2.6, 8.2, 0.0), "focus": Vector4(0.0, 1.5, 0.0, 0.0),
		"eye_to": Vector4(0.0, 2.0, 5.4, 0.0)},
	# Low, rising, looking up past the plinths so the empty one reads tall.
	"low": {"eye": Vector4(0.0, 1.05, 7.6, 0.0), "focus": Vector4(0.0, 2.1, 0.0, 0.0),
		"eye_to": Vector4(0.0, 1.45, 6.6, 0.0)},
	# The three-quarter on the drum. Held: the goat is already turning, and a camera
	# turning with it would cancel the turn out.
	"close": {"eye": Vector4(2.7, 2.1, 3.9, 0.0), "focus": Vector4(0.0, 1.5, 0.0, 0.0)},
	# The same corner, easing in. FOR THE ONE THAT GROWS: a thing assembling itself reads
	# from the three-quarter and not from the front, where a new limb arriving on the far
	# side is hidden behind the near one and the whole build looks like nothing happening.
	"quarter": {"eye": Vector4(3.5, 2.7, 5.6, 0.0), "focus": Vector4(0.0, 1.4, 0.0, 0.0),
		"eye_to": Vector4(2.4, 2.0, 3.7, 0.0)},
	# Side-on, easing in. A walk cycle is read from the side and from nowhere else.
	"profile": {"eye": Vector4(0.9, 3.0, 9.4, 0.0), "focus": Vector4(0.0, 1.9, 0.0, 0.0),
		"eye_to": Vector4(0.5, 2.4, 7.4, 0.0)},
	# A lateral track that ENDS ON NOTHING. For the four stop conditions that are not on
	# this slice: the camera arrives where they would be and they are not there.
	"drift": {"eye": Vector4(-3.6, 2.4, 7.4, 0.0), "focus": Vector4(-2.2, 1.4, 0.0, 0.0),
		"eye_to": Vector4(3.8, 2.4, 7.4, 0.0), "focus_to": Vector4(3.0, 1.4, 0.0, 0.0)},
	# The chicken's sheet from three-quarters, easing round towards the front. NOT square on:
	# the ghosts travel through the sheet towards you, and from straight in front a ball
	# coming at you only grows - from the side you see it cross.
	"sheet": {"eye": Vector4(4.6, 2.9, 6.2, 0.0), "focus": Vector4(0.1, 2.0, 0.0, 0.0),
		"eye_to": Vector4(2.8, 2.6, 7.2, 0.0), "focus_to": Vector4(0.0, 1.9, 0.0, 0.0)},
	# Back far enough for the largest of the zoo, a shade above so the tiger's two rings do
	# not stack on top of each other in the picture.
	"zoo": {"eye": Vector4(1.8, 3.6, 7.4, 0.0), "focus": Vector4(0.0, 2.7, 0.0, 0.0),
		"eye_to": Vector4(1.2, 3.3, 6.6, 0.0)},
}

var _player: Node4D
var _presenter: Node4D
var _their_camera: Camera4D
var _camera: Camera4D
var _holding: bool = false
var _eye: Vector4 = Vector4.ZERO
var _focus: Vector4 = Vector4.ZERO
var _seat_eye: Vector4 = Vector4.ZERO
var _sit_eye: Vector4 = Vector4.ZERO
var _sit_focus: Vector4 = Vector4.ZERO
var _shot: String = ""
var _clock: float = 0.0
var _over: float = 1.0
var _tau: float = 1.6


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_presenter = get_node_or_null(presenter_path) as Node4D
	if _player == null:
		push_warning("TheatreCamera: no player, so there is nobody to take the camera from.")
		return
	_their_camera = _find_camera(_player)
	if _their_camera == null:
		push_warning("TheatreCamera: the player has no Camera4D.")
		return
	# Duplicated, so the cross-section renderer, the FOV and the W fade distance are
	# whatever the player's camera is set to rather than whatever I remembered to copy.
	_camera = _their_camera.duplicate() as Camera4D
	_camera.name = "ShotCamera"
	_camera.current = false
	add_child(_camera)
	# No top_level in this module, so the rig node itself has to stay at the origin with
	# an identity basis - which it does, and which is why global writes land where they
	# are written. Moving this node would move every shot with it.
	position = Vector4.ZERO
	basis = Projection()


## Takes the camera, starting from exactly where the player's one is standing, so the
## first frame of the handover is identical to the last frame before it.
##
## IT TAKES OVER AT THE START OF THE SIT, not the end. The first version waited until the
## player was down, which meant the orbit rig followed them the whole way to the chair and
## spent a second and a half pressed flat against the seat back with nothing else in
## frame. And it misses the point anyway: watching yourself walk over and sit down is what
## teaches the handover. You cannot be taught it by a camera that arrives afterwards.
func take(seat_at: Vector4, look_from: Vector4 = Vector4.ZERO) -> void:
	if _camera == null or _holding:
		return
	_seat_eye = seat_at + Vector4(0.0, eye_height, 0.0, 0.0)
	# A SIDE-ON TWO-SHOT OF THE WALK AND THE CHAIR. The camera stands square to the line
	# between where you were standing and where you are about to sit, on the STAGE side of
	# it, so it looks back up the house and you can see your own face arrive. Framing it
	# off the chair alone put the walk behind the camera, and blending the focus toward
	# where you pressed the key pulled the chair out to the edge of the frame - both of
	# which a picture caught and neither of which the numbers would have.
	var here: Vector4 = look_from if look_from != Vector4.ZERO else seat_at
	var mid: Vector4 = here.lerp(seat_at, 0.5)
	var along := Vector4(seat_at.x - here.x, 0.0, seat_at.z - here.z, 0.0)
	if Vector2(along.x, along.z).length() < 0.3:
		# Sat down where they stood: no line to stand square to, so fall back to the line
		# from the stage out to the chair.
		along = Vector4(seat_at.x, 0.0, seat_at.z, 0.0)
	var square := Vector4(-along.z, 0.0, along.x, 0.0)
	if Vector2(square.x, square.z).length() > 0.01:
		square = square.normalized()
	# The side the stage is on, so the room is what you are walking into rather than what
	# is behind the camera.
	if square.dot(Vector4(-mid.x, 0.0, -mid.z, 0.0)) < 0.0:
		square = -square
	_sit_eye = mid + square * sit_distance + Vector4(0.0, sit_height, 0.0, 0.0)
	_sit_focus = mid.lerp(seat_at, 0.65) + Vector4(0.0, 0.8, 0.0, 0.0)
	_eye = _their_camera.global_position
	# Where they were looking: a point out in front of their camera, so the pan away from
	# it starts from the direction they were actually facing.
	_focus = _eye - _their_camera.global_basis.z * 6.0
	_camera.global_position = _eye
	_camera.global_basis = _their_camera.global_basis
	_holding = true
	_tau = handover_seconds
	_camera.current = true
	shoot("sitting", 6.0)


## Hands it back, and leaves the player's rig exactly as it was - it never stopped owning
## its own transform, so there is nothing to restore.
func release() -> void:
	if not _holding or _their_camera == null:
		return
	_holding = false
	_shot = ""
	_their_camera.current = true
	if _camera != null:
		_camera.current = false


## Frames the next beat. `over` is how long the beat lasts, which is what a drifting shot
## paces itself against - a dolly that finishes early is a dolly that stops dead in the
## middle of a sentence.
func shoot(which: String, over: float) -> void:
	if not SHOTS.has(which):
		return
	if _shot != which:
		_tau = settle_seconds if _shot != "" else _tau
	_shot = which
	_clock = 0.0
	_over = maxf(over, 0.5)


func is_holding() -> bool:
	return _holding


## For anything that has to project a world point onto the screen and therefore has to
## know which camera is actually rendering. See theatre_metric_4d._live.
func live_camera() -> Camera4D:
	return _camera


func shot_name() -> String:
	return _shot


func _process(delta: float) -> void:
	if not _holding or _camera == null or _player == null:
		return
	_clock += delta
	var want_eye: Vector4 = _eye
	var want_focus: Vector4 = _focus
	if SHOTS.has(_shot):
		var shot: Dictionary = SHOTS[_shot]
		# Eased rather than linear, so a drift arrives and settles instead of stopping.
		var t: float = _ease(clampf(_clock / _over, 0.0, 1.0))
		if bool(shot.get("sit", false)):
			# The one shot the table cannot hold, because its subject is wherever the
			# chair is and the chair is placed by the stage.
			want_eye = _sit_eye
			want_focus = _sit_focus
			_settle_frame(delta, want_eye, want_focus)
			return
		var a: Vector4 = _seat_eye if bool(shot.get("seat", false)) \
			else Vector4(shot.get("eye", Vector4.ZERO))
		want_eye = a.lerp(Vector4(shot.get("eye_to", a)), t)
		if bool(shot.get("follow", false)) and _presenter != null:
			want_focus = _presenter.global_position + Vector4(0.0, 1.15, 0.0, 0.0)
		else:
			var f: Vector4 = Vector4(shot.get("focus", Vector4(0.0, 1.4, 0.0, 0.0)))
			want_focus = f.lerp(Vector4(shot.get("focus_to", f)), t)

	_settle_frame(delta, want_eye, want_focus)


## One frame of easing toward a wanted eye and focus.
func _settle_frame(delta: float, want_eye: Vector4, want_focus: Vector4) -> void:
	# THE ONE RULE THAT IS NOT TASTE: the shot happens on the player's slice, never
	# somewhere else in W. See the header.
	var w: float = _player.global_position.w
	want_eye.w = w
	want_focus.w = w

	# Exponential, which is frame-rate independent and has no end - it approaches and
	# keeps approaching, which is what makes a long dolly read as a dolly rather than as
	# an animation that finished.
	var k: float = 1.0 - exp(-delta / maxf(_tau, 0.01))
	_eye = _eye.lerp(want_eye, k)
	_focus = _focus.lerp(want_focus, k)
	# Once the handover is done, later moves are brisker. Set here rather than on a timer
	# so it cannot get out of step with the move it belongs to.
	if _tau > settle_seconds:
		_tau = maxf(settle_seconds, _tau - delta * 0.8)

	_camera.global_position = _eye
	_camera.global_basis = _aim(_focus - _eye)


## A basis looking along `at`, built the way the capture runners build one: a yaw to face
## it and a pitch to raise or drop the nose. No roll, because a rolled camera in a room
## whose whole subject is which way is up would be showing off.
func _aim(at: Vector4) -> Projection:
	var flat: float = Vector2(at.x, at.z).length()
	if flat < 0.0001 and absf(at.y) < 0.0001:
		return Projection()
	var forward: Vector4 = at.normalized()
	return Basis4D.from_zx(atan2(-forward.x, -forward.z)) \
		* Basis4D.from_yz(asin(clampf(forward.y, -1.0, 1.0)))


func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _find_camera(node: Node) -> Camera4D:
	if node is Camera4D:
		return node as Camera4D
	for child in node.get_children():
		var found: Camera4D = _find_camera(child)
		if found != null:
			return found
	return null
