extends Control

## Sitting down, which is what hands the camera over.
##
## THE SIT IS THE CONSENT. Taking the camera off a player who is standing where they chose
## to stand is theft, and it reads as one - the room moves and they did not ask it to.
## Taking it off a player who has just sat down in a chair is a cinema. Nothing here is
## triggered by walking into a volume: a seat offers itself, you press the key, and the
## camera leaves only after you have said so.
##
## AND YOU WATCH IT HAPPEN. The camera pulls back while your own body takes the last step
## and sits, which is not decoration - it is the one moment that TEACHES the handover.
## After you have seen the camera leave, nothing it does afterwards is confusing. This
## only works because the player's camera is already third person; in a first-person game
## the same beat would be a jump cut to a stranger.
##
## GETTING UP IS F OR ESCAPE, always, with no confirmation and no delay. A cinematic camera
## you cannot escape is the thing everybody hates about cinematic cameras. But getting up
## is LEAVING THE TALK (theatre_show_4d.walk_out), not wandering off while it carries on:
## Ramon, 1 Oct, standing up mid-talk meant "you can walk around but lose the cinematic
## touch". So the movement keys no longer get you up - a nudge of W does not break the
## film - and the key you sat down with is the key that gets you out. The player goes back
## to exactly where they were standing, rather than being dropped from the seat onto the
## floor half a metre below it.

@export var player_path: NodePath
@export var stage_path: NodePath
@export var camera_path: NodePath
@export var show_path: NodePath

## How far down the rake before a seat offers itself. Slightly above where the aside
## fires, so the thought ("good view from here") lands first and the chair answers it.
@export_range(0.0, 1.0, 0.05) var offers_at: float = 0.30
## How near a seat has to be to be the one offered.
@export_range(1.0, 12.0, 0.5) var reach: float = 5.5
## And how close once the talk is OVER - see the note where it is used.
@export_range(0.5, 12.0, 0.5) var reach_after: float = 2.0
## Long enough for three beats to read as three beats. Under about 1.5 they run together
## into one slide and it stops being an animation.
@export_range(0.5, 6.0, 0.1) var sit_seconds: float = 2.0
## How much of it is walking, and how much is turning. The rest is lowering.
@export_range(0.1, 0.9, 0.05) var walk_share: float = 0.54
@export_range(0.05, 0.6, 0.05) var turn_share: float = 0.20
## When the camera leaves, as a fraction of the sit. At the top: the sit IS the cutscene,
## and the player's own orbit rig follows them to the chair and jams against its back.
@export_range(0.0, 1.0, 0.05) var hands_over_at: float = 0.02
@export var highlight: Color = Color(0.30, 0.80, 1.0)
@export var bubble_color: Color = Color(0.05, 0.07, 0.12, 0.88)
@export var edge_color: Color = Color(0.32, 0.82, 1.0, 0.9)
@export var text_color: Color = Color(0.93, 0.96, 1.0)

## Trym's own seated angles, so the player sits the way the only other person in this
## project who sits down sits. NEGATIVE hip swings the thigh forward, POSITIVE knee folds
## the shin back under it.
const THIGH_SIT: float = -1.40
const SHIN_SIT: float = 1.40
## How far the hips end up over the pan. The DROP is measured rather than written down -
## see _ready - because a standing avatar's root is at its feet and its hips are however
## far above that its own proportions put them. Trym's 0.25 is right for Trym and left the
## player floating a quarter of a metre over the seat, which a picture caught and no
## amount of reading the number would have.
@export_range(0.0, 0.5, 0.01) var hips_over_pan: float = 0.08

signal sat
signal settled
signal stood

var _player: CharacterBody4D
var _rig: Node
var _gait: Node
var _avatar: Node4D
var _stage: Node4D
var _camera: Node
var _their_camera: Camera4D

var _chair: Node4D
## Exported since this node was written and never resolved until now - nothing had
## asked the show a question before.
var _show: Node
var _offered: bool = false
var _lit: Array[TetraMaterial4D] = []
var _rest: PackedColorArray = PackedColorArray()
var _seated: bool = false
var _settle: float = 0.0
var _from: Vector4 = Vector4.ZERO
var _stood_at: Vector4 = Vector4.ZERO
var _avatar_rest: Vector4 = Vector4.ZERO
var _facing: float = 0.0
var _stride: float = 0.0
var _pulse: float = 0.0
var _handed_over: bool = false
var _drop: float = 0.25
var _measured: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player = get_node_or_null(player_path) as CharacterBody4D
	_stage = get_node_or_null(stage_path) as Node4D
	_camera = get_node_or_null(camera_path)
	if _player == null or _stage == null:
		push_warning("TheatreSeat: no player or no stage, so nobody is sitting anywhere.")
		return
	_rig = _player.get_node_or_null("CameraRig")
	_gait = _player.get_node_or_null("Gait")
	_avatar = _player.get_node_or_null("Avatar") as Node4D
	if _avatar != null:
		_avatar_rest = _avatar.position
	_their_camera = _find_camera(_player)
	# ONE CHAIR, not the nearest of ninety. The row seats are 0.46 metre blocks that read
	# as a house from the stage and as nothing at all from half a metre; the chair you sit
	# in is built to the avatar and stands in the row on its own. See
	# theatre_stage_4d._your_seat.
	var house: Node = _stage.get_node_or_null("House")
	if house != null:
		_chair = house.get_node_or_null("YourSeat") as Node4D
	if _chair == null:
		push_warning("TheatreSeat: the stage has no YourSeat, so there is nothing to sit in.")
	_show = get_node_or_null(show_path)


func is_seated() -> bool:
	return _seated


## HOW FAR THE BODY COMES DOWN, taken off the avatar rather than written down. A standing
## avatar's root is at its feet and its hips are however far above that its own
## proportions put them, so the drop that lands the hips on the pan is the hip height less
## the clearance wanted. Trym's hard-coded 0.25 is right for Trym and left the player
## floating a quarter of a metre over the seat - which a picture caught, and which no
## amount of looking at the number would have.
##
## MEASURED LAZILY, not in _ready: block_avatar_4d builds its own joints in ITS _ready,
## and the Player node is declared after the UI in theatre.tscn, so at this script's _ready
## there is no hip to measure yet.
func _measure() -> void:
	if _measured or _avatar == null:
		return
	var hip: Node4D = _avatar.get("hip_left") as Node4D
	if hip == null:
		return
	_measured = true
	_drop = maxf(0.0, hip.global_position.y - _avatar.global_position.y - hips_over_pan)


## Seated AND finished sitting. The two differ by a couple of seconds of animation, and
## anything that waits for the sit wants the second one.
func is_settled() -> bool:
	return _seated and _settle >= 1.0


func is_offering() -> bool:
	return _offered and not _seated


func _process(delta: float) -> void:
	if _player == null:
		return
	_measure()
	_pulse += delta
	if _settle > 0.0 and _settle < 1.0:
		# The way out works while you are still sitting down, too: two seconds of animation
		# in which no key does anything is two seconds of feeling stuck.
		if _wants_out():
			stand()
			queue_redraw()
			return
		_settle = minf(_settle + delta / maxf(sit_seconds, 0.05), 1.0)
		_place()
		if _settle >= 1.0:
			settled.emit()
		queue_redraw()
		return
	if _seated:
		_place()
		if _wants_out():
			stand()
		queue_redraw()
		return
	# ONE REACH WAS SERVING TWO DIFFERENT SITUATIONS. During the talk the chair is the
	# thing to do and should be findable from halfway down the rake. Afterwards it is
	# just a chair - and at the old reach the offer was the first thing on screen the
	# moment the presentation ended, inviting you to sit down for a talk that had just
	# finished.
	var want: float = reach
	if _show != null and _show.has_method("is_over") and bool(_show.call("is_over")):
		want = reach_after
	_offered = _chair != null and _down_the_rake() >= offers_at \
		and (_chair.global_position - _player.global_position).length() < want
	_glow(_offered)
	if _offered and Input.is_action_just_pressed(&"catch_target"):
		sit()
	queue_redraw()


func _down_the_rake() -> float:
	var at: Vector4 = _player.global_position
	if float(_stage.call("aisle_gap", at)) > float(_stage.get("aisle_width")) * 0.9:
		return -1.0
	var top: Vector4 = _stage.get("aisle_to")
	var foot: Vector4 = _stage.get("aisle_from")
	var span: float = Vector2(top.x - foot.x, top.z - foot.z).length()
	if span < 0.5:
		return -1.0
	return Vector2(top.x - at.x, top.z - at.z).length() / span


## The offered chair breathes. Every seat in the house is the same dead violet, so the
## one that can be used has to say so without a floating icon over it - this room does not
## put icons over things and should not grow the habit now.
##
## EVERY PART'S RESTING COLOUR IS RECORDED ONCE, and restoring is playing the record
## back. The first version worked out whether a part was lit by testing whether its blue
## channel looked high, which is a guess about a colour rather than a note of what was
## changed - and it had to be, because it was trying to light one of ninety identical
## blocks. With one chair there is nothing to guess.
func _glow(on: bool) -> void:
	if _chair == null:
		return
	if _lit.is_empty():
		for part in _chair.get_children():
			var skin := (part as MeshInstance4D).material_override as TetraMaterial4D
			if skin == null:
				continue
			_lit.append(skin)
			_rest.append(skin.albedo_color)
	var beat: float = 0.30 + (0.5 + 0.5 * sin(_pulse * 2.4)) * 0.34
	for i in _lit.size():
		_lit[i].albedo_color = _rest[i] if not on \
			else (_rest[i] as Color).lerp(highlight, beat)


func sit() -> void:
	if _seated or not _offered or _player == null or _chair == null:
		return
	_seated = true
	_settle = 0.001
	_handed_over = false
	_stride = 0.0
	_from = _player.global_position
	_stood_at = _from
	# Physics off entirely, not merely input off: gravity and floor snap would pull the
	# player straight back off a chair that has no collider under it.
	_player.set_physics_process(false)
	_player.set("input_enabled", false)
	if _gait != null:
		_gait.set_physics_process(false)
		_gait.set_process(false)
	if _rig != null:
		_rig.set_process_unhandled_input(false)
	_glow(false)
	_offered = false
	sat.emit()


func stand() -> void:
	if not _seated:
		return
	_seated = false
	_settle = 0.0
	_player.global_position = _stood_at
	_player.set_physics_process(true)
	_player.set("input_enabled", true)
	if _gait != null:
		_gait.set_physics_process(true)
		_gait.set_process(true)
	if _rig != null:
		_rig.set_process_unhandled_input(true)
	if _avatar != null:
		_avatar.position = _avatar_rest
		_fold(0.0)
	if _camera != null and _camera.has_method("release"):
		_camera.call("release")
	if _their_camera != null:
		_their_camera.current = true
	stood.emit()


## SITTING DOWN, IN THREE BEATS. A single lerp from wherever you were straight into the
## chair is a player sliding sideways into furniture, which is the thing that makes a
## scripted sit look cheap. So:
##
##   WALK   he crosses to a spot in front of the chair, legs striding, facing his travel
##   TURN   he stops there and turns to face the stage
##   LOWER  he settles back onto the pan, thighs folding forward as he goes
##
## The stride is driven here rather than by block_gait_4d, because the gait reads the
## character's velocity and the character's physics is off for the duration - it has to
## be, or gravity would pull him off a chair that has no collider under it. Same sign
## convention as everyone else who walks in this project: NEGATIVE hip swings the thigh
## forward, POSITIVE knee folds the shin back under it.
func _place() -> void:
	if _chair == null or _avatar == null:
		return
	var seat: Vector4 = _chair.global_position
	# Out in front of the chair, on the floor the chair stands on. The chair's forward is
	# its own -Z, which is the way it faces, which is the stage.
	var ahead: Vector4 = -_chair.global_basis.z
	var stood: Vector4 = seat + ahead * 0.66 - Vector4(0.0, 0.20, 0.0, 0.0)
	var down: Vector4 = seat + Vector4(0.0, 0.15, 0.0, 0.0)

	var t: float = _settle
	var to_stage: float = atan2(-seat.x, -seat.z)
	if t < walk_share:
		var k: float = _ease(t / maxf(walk_share, 0.01))
		var was: Vector4 = _player.global_position
		_player.global_position = _from.lerp(stood, k)
		_stride += (_player.global_position - was).length() * 6.0
		var went := _player.global_position - was
		if Vector2(went.x, went.z).length() > 0.0005:
			_facing = atan2(went.x, went.z)
		_walk_legs()
	elif t < walk_share + turn_share:
		_player.global_position = stood
		var k: float = (t - walk_share) / maxf(turn_share, 0.01)
		_facing = rotate_toward(_facing, to_stage, k * 0.35)
		_walk_legs()
	else:
		var k: float = _ease((t - walk_share - turn_share)
			/ maxf(1.0 - walk_share - turn_share, 0.01))
		_player.global_position = stood.lerp(down, k)
		_facing = to_stage
		_avatar.position = _avatar_rest - Vector4(0.0, _drop * k, 0.0, 0.0)
		_fold(k)
	_avatar.basis = Basis4D.from_zx(_facing)

	# THE CAMERA LEAVES WHILE HE IS STILL GOING DOWN, not once he has landed. Overlapping
	# the two is the difference between a handover and a queue of two animations.
	if not _handed_over and t >= hands_over_at and _camera != null \
			and _camera.has_method("take"):
		_handed_over = true
		_camera.call("take", down, _from)


## A plain two-beat stride, enough for four paces of walking.
func _walk_legs() -> void:
	var swing: float = sin(_stride) * 0.40
	for side in ["left", "right"]:
		var lead: float = -swing if side == "left" else swing
		var hip: Node4D = _avatar.get("hip_%s" % side) as Node4D
		var knee: Node4D = _avatar.get("knee_%s" % side) as Node4D
		var ankle: Node4D = _avatar.get("ankle_%s" % side) as Node4D
		var knee_angle: float = maxf(0.0, lead) * 0.75
		if hip != null:
			hip.basis = Basis4D.from_yz(lead)
		if knee != null:
			knee.basis = Basis4D.from_yz(knee_angle)
		if ankle != null:
			ankle.basis = Basis4D.from_yz(-(lead + knee_angle))


## Trym's pose, part-played. 0 is standing, 1 is sat.
func _fold(t: float) -> void:
	for side in ["left", "right"]:
		var hip: Node4D = _avatar.get("hip_%s" % side) as Node4D
		var knee: Node4D = _avatar.get("knee_%s" % side) as Node4D
		var ankle: Node4D = _avatar.get("ankle_%s" % side) as Node4D
		if hip != null:
			hip.basis = Basis4D.from_yz(THIGH_SIT * t)
		if knee != null:
			knee.basis = Basis4D.from_yz(SHIN_SIT * t)
		if ankle != null:
			# Rotations compose down the chain, so undoing their sum keeps the foot flat
			# however far the leg is folded.
			ankle.basis = Basis4D.from_yz(-(THIGH_SIT + SHIN_SIT) * t)


## F, the key you sat down with, and Escape.
##
## ESCAPE because it is the reflex. Ramon, 30 Sept, sitting down again after the talk:
## "locked in a freeze, nothing works anymore ... double esc didn't work". Escape is the
## camera rig's key (free the cursor, then quit), and the rig's input is off while you sit -
## so the key everybody presses when they feel stuck did nothing at all. The chair says
## what gets you out while you are in it (see _draw).
##
## NOT THE MOVEMENT KEYS any more (Ramon, 1 Oct): getting up is leaving the talk, and a
## brush of W should not end a film.
func _wants_out() -> bool:
	for action in [&"catch_target", &"ui_cancel"]:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			return true
	return false


func _draw() -> void:
	if _seated:
		_draw_way_up()
		return
	if not _offered or _their_camera == null or _chair == null:
		return
	var at: Vector4 = _chair.global_position + Vector4(0.0, 1.35, 0.0, 0.0)
	var ahead: Vector4 = at - _their_camera.global_position
	if ahead.dot(-_their_camera.global_basis.z) <= 0.1:
		return
	var point: Vector2 = _their_camera.world_to_viewport(at)
	var screen: Vector2 = get_viewport_rect().size
	if point.x < 0.0 or point.y < 0.0 or point.x > screen.x or point.y > screen.y:
		return
	var font: Font = ThemeDB.fallback_font
	var size: int = int(screen.y * 0.023)
	var label: String = "Sit down   [%s]" % _sit_key()
	var wide: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pad: float = screen.y * 0.014
	var box := Rect2(point - Vector2(wide * 0.5 + pad, size + pad * 2.0),
		Vector2(wide + pad * 2.0, size + pad * 2.0))
	draw_rect(box, bubble_color, true)
	draw_rect(box, edge_color, false, 1.5)
	draw_string(font, Vector2(box.position.x + pad, box.position.y + pad + size * 0.78),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, text_color)


## While you sit: how to get up, small, in the top corner the stage does not use.
func _draw_way_up() -> void:
	if not is_settled():
		return
	var font: Font = ThemeDB.fallback_font
	var screen: Vector2 = get_viewport_rect().size
	var size: int = int(screen.y * 0.019)
	var label: String = "%s / Esc   leave the presentation" % _sit_key()
	var wide: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pad: float = screen.y * 0.012
	var box := Rect2(Vector2(screen.y * 0.03, screen.y * 0.03),
		Vector2(wide + pad * 2.0, size + pad * 2.0))
	draw_rect(box, Color(bubble_color, bubble_color.a * 0.7), true)
	draw_rect(box, Color(edge_color, 0.45), false, 1.0)
	draw_string(font, Vector2(box.position.x + pad, box.position.y + pad + size * 0.78),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(text_color, 0.8))


## Read off the InputMap, because a printed key stops being true the moment somebody
## rebinds it - the same rule every other prompt in this prototype follows.
func _sit_key() -> String:
	if not InputMap.has_action(&"catch_target"):
		return "?"
	for event in InputMap.action_get_events(&"catch_target"):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 \
				else event.keycode
			return OS.get_keycode_string(code)
	return "?"


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
