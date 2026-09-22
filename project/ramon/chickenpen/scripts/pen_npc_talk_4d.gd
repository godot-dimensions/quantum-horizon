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
## outdoor one, which is what the keeper and Nessa do.

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
var _hide: Array[CanvasItem] = []

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
	_talk.started.connect(_on_started)
	_talk.ended.connect(_on_ended)
	_configure()


func _process(delta: float) -> void:
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
			var gap: Vector4 = target.global_position - _cam_marker.global_position
			if gap.length_squared() > 0.0001:
				_cam_marker.global_basis = _look_basis(gap)
		_cam_marker.set("current", true)
		_tell_box(_cam_marker)
	else:
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
func _show_hud(on: bool) -> void:
	for item in _hide:
		if is_instance_valid(item):
			item.visible = on


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
