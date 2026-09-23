extends Node
class_name PenNpcTalk4D

## Everything the talkable characters in chickenpen have in common: who can be addressed,
## when, the key they share with catching, the prompt over their head, freezing the player,
## turning the two of you to face each other, and staging the shot.
##
## A subclass supplies only what makes the character themselves - which script they speak
## from, which node of it they open on, and what their effects mean. A fourth character
## costs about forty lines.
##
## THE CATCH KEY IS THE TALK KEY, AND THAT NEEDS A RULE. chickenpen already spends F on
## catching and throwing, and a second Talk key on a control card that is already eleven
## rows long is worse than sharing one. So this listens in _input, which runs ahead of the
## catcher's _unhandled_input, and takes the key only when talking is unambiguous: this
## character in reach, no chicken in reach, and nothing in your arms. Every other press
## falls through untouched, and two of these never fight, because each claims the key only
## when it is the one you are standing next to.
##
## THE INTERIOR STAGING IS ANIMAL CROSSING'S, MINUS THE LOADING SCREEN. Its interiors are
## separate spaces with three walls and no fourth, and a fixed camera outside the missing
## one - which is why its camera never has to cope with a wall. Copied here in three parts,
## all optional and all authored in the scene: the player is MOVED to a mark that composes
## well, the camera sits on a MARK outside rather than orbiting, and the near wall and roof
## are taken away for the duration. Leave the marks unset and a character behaves as an
## outdoor one, which is what the keeper and Mithra do.

@export var player_path: NodePath
@export var character_path: NodePath
@export var catcher_path: NodePath
@export var dialogue_path: NodePath
@export var tag_path: NodePath
## Optional. Given one, the camera comes in and drops while the conversation is open.
@export var camera_rig_path: NodePath

@export_group("Staging")
## Optional. Where the player stands for the conversation; they are put back afterwards.
##
## SLID, NOT CUT. Animal Crossing can cut because it fades to black; a hard jump with no
## fade reads as a bug. Easing across in a third of a second reads as stepping inside.
@export var stand_marker_path: NodePath
@export_range(0.05, 1.5, 0.05) var step_seconds: float = 0.4
## Optional. A SECOND Camera4D, standing in the world, that becomes current for the
## conversation - plus what it should look at.
##
## A SEPARATE CAMERA, NOT THE ORBIT ONE MOVED. Setting the orbit camera's global position
## converts to a local offset under the player, so the step-inside slide and the rig's own
## per-frame placement dragged it off the mark - it ended up nineteen metres from where it
## was told to stand. A camera that is not parented to anything that moves cannot be
## dragged anywhere.
@export var camera_marker_path: NodePath
@export var camera_target_path: NodePath
## Place that camera from where the two of you are actually standing, rather than leaving
## it on its authored mark: an over-the-shoulder two-shot, the player's back in the near
## corner of frame and whoever is talking facing you across it.
##
## IT IS PLACED, NOT AUTHORED, because you can walk up to somebody from any side. A fixed
## mark that frames the conversation beautifully from the gate shows you the back of the
## speaker's head when you come round the other way.
##
## IT STAYS ON THE SIDE YOU WERE ALREADY LOOKING FROM - the film 180-degree rule. Dropping
## the camera on whichever side the maths happens to pick swaps who is on the left and who
## is on the right at the moment the conversation opens, and that reads as a mistake even
## to people who have never heard the rule.
@export var two_shot: bool = false
## The camera to give control back to afterwards.
@export var main_camera_path: NodePath
## The panel, so it can be told to project through the staged camera while it is current.
@export var dialogue_box_path: NodePath
## Optional. Something with set_cutaway(bool) - the shed - to open up for the shot.
@export var cutaway_path: NodePath
## Optional. HUD nodes to get out of the way while somebody is talking. The radar alone
## covers a third of an interior shot, and none of it is any use mid-conversation.
@export var hide_while_talking: Array[NodePath] = []

@export_group("Reach")
## How close on the ground before they are worth talking to.
@export_range(1.0, 12.0, 0.5) var talk_range: float = 3.0
## And how far through W. They should still be addressable from a slice or so away,
## because someone who goes silent when you step sideways reads as a bug.
@export_range(0.5, 8.0, 0.5) var talk_range_w: float = 2.0

@export_group("Rules")
## Freeze the player while a conversation is open. Cheaper and far less buggy than letting
## somebody wander off mid-sentence.
@export var lock_movement: bool = true

@export_group("Two-shot")
## Out to the side of the player, across the line between the two of you.
@export_range(0.2, 4.0, 0.1) var two_shot_side: float = 1.55
## Back from the player, away from the speaker. The shoulder in the corner of frame.
@export_range(-2.0, 4.0, 0.1) var two_shot_back: float = 1.15
## Above the speaker's head node. A little up is a conversation; a lot is a drone.
@export_range(-1.0, 2.0, 0.05) var two_shot_rise: float = 0.18
## Where along the line between you the camera aims. Past halfway, so the speaker holds
## the frame and the player is the shoulder rather than the subject.
@export_range(0.0, 1.0, 0.01) var two_shot_bias: float = 0.72
## How long the staged shot holds before the player's own camera takes over again. Zero
## keeps it for the whole conversation.
##
## A BEAT, NOT A MODE. A staged camera you cannot move is fine for two seconds and wrong
## for a whole conversation: the moment anything happens in the world - an item handed
## over, arcing above your head - you are watching it from a camera that is not yours and
## cannot follow it. Cutting back leaves the rig's own closer conversation framing, so it
## still feels like a conversation, but you can look where you like.
@export_range(0.0, 20.0, 0.1) var two_shot_seconds: float = 0.0
## Metres per second the staged camera creeps toward what it is looking at while it holds.
## Zero is a locked-off shot.
@export_range(0.0, 3.0, 0.05) var two_shot_push: float = 0.0
## A SECOND shot, on their face, after the two-shot and before the camera goes back. Zero
## is one shot and out.
##
## TWO SHOTS IS A SCENE, one is a camera angle. Cutting wide-then-close is the oldest
## grammar there is: the first shot says who is here and where, the second says what they
## think about it. It costs nothing here because both are placed from the same two
## positions that were already known.
@export_range(0.0, 10.0, 0.1) var close_up_seconds: float = 0.0
## How far off their face it sits.
@export_range(0.4, 3.0, 0.05) var close_up_distance: float = 1.15
## Degrees off their eyeline, so it is a three-quarter face rather than a mugshot. Swung
## to the side the two-shot was on, so the cut does not jump the line.
@export_range(0.0, 80.0, 1.0) var close_up_degrees: float = 28.0
## Lifted above their head node - slightly under eye level looks up at them, slightly over
## looks down on them, and neither is neutral.
@export_range(-0.5, 0.5, 0.01) var close_up_rise: float = 0.03

var _player: Node4D
var _character: Node
var _catcher: Node
var _talk: DialoguePlayer4D
var _tag: WorldTag4D
var _rig: Node
var _marker: Node4D
var _cam_marker: Node4D
var _main_cam: Node4D
var _box: Node
var _cam_target: Node4D
var _cutaway: Node
## Seconds left on the staged shot. Zero means the player has the camera.
var _cine: float = 0.0
## What that shot is pointed at, kept so a push-in can keep aiming at it.
var _cine_aim: Vector4 = Vector4.ZERO
## Which shot is on screen: 1 the two-shot, 2 the close-up, 0 nothing.
var _cine_stage: int = 0
## Which side of the line the two-shot chose, so the close-up stays on it.
var _cine_lean: float = 1.0
var _hide: Array[CanvasItem] = []
## The subset of _hide that was actually on screen when this conversation opened.
var _hid: Array[CanvasItem] = []

var _outside: Vector4 = Vector4.ZERO
var _went_in: bool = false
var _slide_from: Vector4 = Vector4.ZERO
var _slide_to: Vector4 = Vector4.ZERO
var _slide: float = -1.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_character = get_node_or_null(character_path)
	_catcher = get_node_or_null(catcher_path)
	_talk = get_node_or_null(dialogue_path) as DialoguePlayer4D
	_tag = get_node_or_null(tag_path) as WorldTag4D
	_rig = get_node_or_null(camera_rig_path)
	_marker = get_node_or_null(stand_marker_path) as Node4D
	_cam_marker = get_node_or_null(camera_marker_path) as Node4D
	_main_cam = get_node_or_null(main_camera_path) as Node4D
	_box = get_node_or_null(dialogue_box_path)
	_cam_target = get_node_or_null(camera_target_path) as Node4D
	_cutaway = get_node_or_null(cutaway_path)
	for path in hide_while_talking:
		var item: CanvasItem = get_node_or_null(path) as CanvasItem
		if item != null:
			_hide.append(item)
	if _player == null or _talk == null or _tag == null:
		push_warning("%s: player, dialogue or tag missing - this character will never speak (item 82)." % name)
		return
	_talk.effect.connect(_on_effect)
	# A SECOND listener rather than logic inside _on_effect, which every subclass here
	# overrides outright - putting it there would work for none of them.
	_talk.effect.connect(_on_cine_effect)
	_talk.started.connect(_on_started)
	_talk.ended.connect(_on_ended)
	_configure()


## Ends the staged shot early the moment the conversation DOES something - hands an item
## over, builds a trough. Whatever it was, it happens in the world and the player should
## be watching it from their own camera, not from a mark on the grass.
func _on_cine_effect(_name: String) -> void:
	if _cine > 0.0:
		_end_cine()


func _end_cine() -> void:
	_cine = 0.0
	_cine_stage = 0
	if _rig != null and _rig.has_method("lock_look"):
		_rig.call("lock_look", false)
	if _main_cam != null:
		_main_cam.set("current", true)
	_tell_box(null)


func _run_cine(delta: float) -> void:
	_cine -= delta
	if _cine <= 0.0:
		# Wide, then close, then it is yours again.
		if _cine_stage == 1 and close_up_seconds > 0.0 and _cam_marker != null:
			_cine_stage = 2
			_cine = close_up_seconds
			var on: Node4D = _cam_target if _cam_target != null else _anchor()
			if on != null:
				_cine_aim = _stage_close_up(on)
				var look: Vector4 = _cine_aim - _cam_marker.global_position
				if look.length_squared() > 0.0001:
					_cam_marker.global_basis = _look_basis(look)
				return
		_end_cine()
		return
	if _cine_stage != 1 or is_zero_approx(two_shot_push) or _cam_marker == null:
		return
	var gap: Vector4 = _cine_aim - _cam_marker.global_position
	var flat := Vector2(gap.x, gap.z)
	# Stopped short, or a push-in becomes a walk-through. The player is checked as well as
	# the mark: the shot creeps along the line between the two of you and passes close by
	# the near one, and a camera that clips through their shoulder flashes the inside of a
	# head across the whole frame for a moment.
	if flat.length() < 1.2:
		return
	if _player != null:
		var near: Vector4 = _player.global_position - _cam_marker.global_position
		if Vector2(near.x, near.z).length() < 1.1:
			return
	var step: Vector2 = flat.normalized() * two_shot_push * delta
	_cam_marker.global_position += Vector4(step.x, 0.0, step.y, 0.0)
	var aim: Vector4 = _cine_aim - _cam_marker.global_position
	if aim.length_squared() > 0.0001:
		_cam_marker.global_basis = _look_basis(aim)


func _process(delta: float) -> void:
	if _cine > 0.0:
		_run_cine(delta)
	_advance_slide(delta)
	if _tag == null:
		return
	if _talk != null and _talk.is_running():
		_tag.clear()
		return
	_tag.show_text(_tag_text()) if _can_talk() else _tag.clear()


func _input(event: InputEvent) -> void:
	if _talk == null or _talk.is_running():
		return
	if not event.is_action_pressed(&"catch_target"):
		return
	if not _can_talk():
		return
	_before_begin()
	_talk.begin(_entry_node())
	get_viewport().set_input_as_handled()


## In reach of them, out of reach of a chicken, and empty-handed. Anything else and the
## key still means catch.
func _can_talk() -> bool:
	if _player == null:
		return false
	if _catcher != null:
		if _catcher.get("carried") != null:
			return false
		if _catcher.get("_candidate") != null:
			return false
	return _in_reach()


func _in_reach() -> bool:
	var anchor: Node4D = _anchor()
	if anchor == null:
		return false
	var gap: Vector4 = anchor.global_position - _player.global_position
	return Vector2(gap.x, gap.z).length() <= talk_range and absf(gap.w) <= talk_range_w


## Distance is measured to whatever the tag hangs off, so the prompt and the reach can
## never disagree about where the character is.
func _anchor() -> Node4D:
	if _tag == null:
		return null
	return _tag.get_node_or_null(_tag.anchor_path) as Node4D


# ------------------------------------------------------------------ staging

func _on_started() -> void:
	_set_player_moving(false)
	# Both parties turn to each other. The subclass turns the character it owns; this turns
	# the player, so neither of them is talking to the side of somebody's head.
	var anchor: Node4D = _anchor()
	if anchor != null and _character != null and _character.has_method("face_towards"):
		_character.call("face_towards", anchor.global_position)
	_open_room(true)
	_show_hud(false)
	_frame_camera(true)
	if _marker != null:
		_outside = _player.global_position
		_went_in = true
		_start_slide(_marker.global_position)
	_began()


func _on_ended() -> void:
	_set_player_moving(true)
	if _character != null and _character.has_method("stop_facing"):
		_character.call("stop_facing")
	_frame_camera(false)
	_show_hud(true)
	_open_room(false)
	if _went_in:
		_went_in = false
		_start_slide(_outside)
	_ended()


func _frame_camera(talking: bool) -> void:
	if _rig == null:
		return
	if _rig.has_method("set_talking"):
		_rig.call("set_talking", talking)
	if _cam_marker == null:
		return
	if talking:
		# Aimed here rather than authored in the scene, so moving the mark or the target is
		# enough and nobody has to hand-write a Projection.
		var target: Node4D = _cam_target if _cam_target != null else _anchor()
		if target != null:
			var look: Vector4 = target.global_position
			if two_shot:
				look = _stage_two_shot(target)
			var gap: Vector4 = look - _cam_marker.global_position
			if gap.length_squared() > 0.0001:
				_cam_marker.global_basis = _look_basis(gap)
			_cine_aim = look
			_cine = two_shot_seconds
			_cine_stage = 1
			if _cine > 0.0 and _rig != null and _rig.has_method("lock_look"):
				_rig.call("lock_look", true)
		_cam_marker.set("current", true)
		_tell_box(_cam_marker)
	else:
		_cine = 0.0
		_cine_stage = 0
		if _rig != null and _rig.has_method("lock_look"):
			_rig.call("lock_look", false)
		if _main_cam != null:
			_main_cam.set("current", true)
		_tell_box(null)


## A look-at that leaves the SLICE alone.
##
## Basis4D.looking_at only constrains forward, and the axes it is free to choose include W.
## It picked one that was not the world's, so the staged camera rendered a different cross
## section - which looked like the shed and everyone in it having been deleted, leaving
## ground and sky. Pinning the W column to the world's fourth axis and aiming only within
## XYZ keeps the shot on the slice the scene is built on.
## Puts the staged camera over the player's shoulder and returns the point it should aim
## at. See the two_shot export for why it is placed rather than authored.
func _stage_two_shot(target: Node4D) -> Vector4:
	var here: Vector4 = target.global_position
	if _player == null:
		return here
	var them: Vector4 = _player.global_position
	var axis := Vector2(here.x - them.x, here.z - them.z)
	if axis.length() < 0.2:
		# Standing on top of each other; there is no line to shoot along.
		return here
	axis = axis.normalized()
	var across := Vector2(-axis.y, axis.x)
	# The 180-degree rule: whichever side of the line the player was already watching from
	# is the side the shot goes on.
	var lean: float = 1.0
	if _main_cam != null:
		var was: Vector4 = _main_cam.global_position
		if Vector2(was.x - them.x, was.z - them.z).dot(across) < 0.0:
			lean = -1.0
	_cine_lean = lean
	var spot := Vector2(them.x, them.z) - axis * two_shot_back
	spot += across * (two_shot_side * lean)
	# W IS THE SPEAKER'S, not a blend. The camera renders one cross-section, and a camera
	# halfway between two w values shows a half-faded pair of people talking in a fog.
	# Both of them are inside talk_range_w of each other or this conversation could not
	# have opened, so the speaker's slice has the player in it too.
	_cam_marker.global_position = Vector4(spot.x, here.y + two_shot_rise, spot.y, here.w)
	# Aimed past the midpoint so the speaker holds the frame.
	return Vector4(
		lerpf(them.x, here.x, two_shot_bias),
		here.y - 0.06,
		lerpf(them.z, here.z, two_shot_bias),
		here.w)


## Puts the camera on their face. They are already turned toward the player by their own
## facing node, so their eyeline IS the direction to the player - swinging off that by
## close_up_degrees gives a three-quarter face without needing to read their basis.
##
## THE SWING IS NEGATIVE-LEAN. `across` in the two-shot is the left-hand perpendicular of
## the player-to-speaker axis, and rotating the reverse of that axis by a positive angle
## moves the other way, so the sign is flipped to land on the same side. Checked against a
## captured frame rather than argued about, because getting it wrong crosses the line and
## puts the back of their head on screen.
func _stage_close_up(target: Node4D) -> Vector4:
	var here: Vector4 = target.global_position
	if _player == null:
		return here
	var eyeline := Vector2(_player.global_position.x - here.x,
		_player.global_position.z - here.z)
	if eyeline.length() < 0.2:
		return here
	var swung: Vector2 = eyeline.normalized().rotated(
		deg_to_rad(-close_up_degrees) * _cine_lean)
	var spot: Vector2 = Vector2(here.x, here.z) + swung * close_up_distance
	_cam_marker.global_position = Vector4(spot.x, here.y + close_up_rise, spot.y, here.w)
	return here


func _look_basis(gap: Vector4) -> Projection:
	var forward: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	# -Z is forward, the convention Basis4D.looking_at documents and the catcher relies on.
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc)
	if xc.length_squared() < 0.000001:
		xc = Vector3(1.0, 0.0, 0.0)
	xc = xc.normalized()
	var yc: Vector3 = zc.cross(xc)
	return Projection(
		Vector4(xc.x, xc.y, xc.z, 0.0),
		Vector4(yc.x, yc.y, yc.z, 0.0),
		Vector4(zc.x, zc.y, zc.z, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0))


## The panel projects a head to a screen point, so it has to be using the same camera the
## player is looking through or the maths is right about the wrong view.
func _tell_box(cam: Node) -> void:
	if _box != null and _box.has_method("use_camera"):
		_box.call("use_camera", cam)


## Anything the conversation should not be sharing the frame with. Remembered as a list
## rather than a flag on each node, so the same driver can hide different things for an
## indoor character than for one standing in a field.
## Puts the HUD away for the length of a conversation, and gives back only what it took.
##
## ONLY WHAT IT TOOK. Setting every item visible again on the way out looks identical
## until something else has hidden one of them for its own reasons - the trip to the
## cinema puts the whole farm HUD away, and a conversation ending would hand a piece of it
## back in the middle of a film. So the hiding pass records what was actually on screen,
## and the showing pass restores that list rather than the whole one.
func _show_hud(on: bool) -> void:
	if not on:
		_hid.clear()
		for item in _hide:
			if is_instance_valid(item) and item.visible:
				_hid.append(item)
				item.visible = false
		return
	for item in _hid:
		if is_instance_valid(item):
			item.visible = true
	_hid.clear()


func _open_room(open: bool) -> void:
	if _cutaway != null and _cutaway.has_method("set_cutaway"):
		_cutaway.call("set_cutaway", open)


## Keeps the player's own height: the marker says where to stand, not how tall to be, and
## dropping them to the marker's y would sink or float them depending on where it was put.
func _start_slide(to: Vector4) -> void:
	if _player == null:
		return
	_slide_from = _player.global_position
	_slide_to = Vector4(to.x, _slide_from.y, to.z, to.w)
	_slide = 0.0


func _advance_slide(delta: float) -> void:
	if _slide < 0.0 or _player == null:
		return
	_slide = minf(_slide + delta / step_seconds, 1.0)
	# Smoothstepped, so it leaves and arrives gently instead of at full speed.
	var t: float = _slide * _slide * (3.0 - 2.0 * _slide)
	_player.global_position = _slide_from.lerp(_slide_to, t)
	_player.set("linear_velocity", Vector4.ZERO)
	if _slide >= 1.0:
		_slide = -1.0


func _set_player_moving(on: bool) -> void:
	if lock_movement and _character != null:
		_character.set("input_enabled", on)


## Read from the InputMap for the same reason every other prompt in this prototype does: a
## printed key stops being true the moment somebody rebinds.
func _catch_key() -> String:
	if not InputMap.has_action(&"catch_target"):
		return "?"
	for event in InputMap.action_get_events(&"catch_target"):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


# ------------------------------------------------------------------ for subclasses

## Hand the dialogue player its script. Called once, after everything is resolved.
func _configure() -> void:
	pass


## Which node of the script to open on, given the state of the world right now.
func _entry_node() -> String:
	return ""


## What one of the script's announced effects means in this game.
func _on_effect(_name: String) -> void:
	pass


## Ways in for a subclass around the conversation itself.
func _before_begin() -> void:
	pass


func _began() -> void:
	pass


func _ended() -> void:
	pass


func _tag_text() -> String:
	return "%s talk" % _catch_key()
