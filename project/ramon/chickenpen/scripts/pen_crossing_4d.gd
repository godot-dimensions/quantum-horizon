extends Node

## Going through the door, and coming back.
##
## THE FARM IS NOT UNLOADED, IT IS SWITCHED OFF. change_scene_to_file would have been two
## lines and would have thrown away the run: the chickens you have carried in, the gold in
## your belt, where the cat had got to. The theatre is added BESIDE the field instead and
## the field's branches are disabled and hidden, so coming back is switching them on again
## and everything is exactly where it was left.
##
## The cost is that both scenes are in memory at once. For a disc, a drum and three
## exhibits that is nothing, and it buys a door the player can walk through twice in a
## minute without consequence - which is the only way anybody will actually look at the
## presentation rather than deciding it is a point of no return and never trying it.
##
## THE CAMERA IS HANDED OVER EXPLICITLY. Two Camera4Ds in one tree and the one that wins is
## whichever set itself current last, which is a race nobody should have to reason about.
## This names the one it wants at each end.
##
## AND THE HUD IS HIDDEN BY HAND, one Control at a time. Canvas visibility does not inherit
## through a Node4D: the farm's UI branch is a Node4D, so every Control under it counts as
## a root canvas item and goes on drawing over the presentation no matter what the branch
## is set to. Hiding the branch is not enough; hiding its Controls is. Only the ones that
## were ON get switched off, and only those come back - otherwise returning would reveal
## the two parked dials and every dialogue box in the scene.

@export var theatre_scene: PackedScene
## Everything in the field that should stop existing while you are away. Named rather than
## inferred: this scene has branches that must keep running even then - the crossing
## itself, and whatever holds the returning camera.
@export var asleep_paths: Array[NodePath] = []
@export var farm_camera_path: NodePath
@export var player_path: NodePath

@export_group("Taking the player along")
## For a place the pen's OWN player walks into, rather than one with a player of its own
## like the theatre: the cave inside the hill. The player is moved to wherever the opened
## scene's arrival() says, and faced into it, and keeps its belt, tool and camera - so
## what you find there comes home with you. Leave it off and nothing below applies.
@export var bring_player: bool = false
## Which way the camera faces on arriving, in the rig's yaw (0 looks along -z).
@export var arrival_yaw_degrees: float = 0.0
## Where the player is set down on the way home, from where they went in. The default is
## the theatre's: a pace back from the door, so they do not walk straight through again.
@export var return_offset: Vector4 = Vector4(0.0, 0.0, 1.6, 0.0)
## Turn the camera on the way home, to face away from where you went in.
@export var face_on_return: bool = false
## Optional: a node whose turn turns return_offset and the facing on return. The cave sets its
## hill here, so "a pace back out of the mouth" stays out of the mouth however the Cave unit is
## turned (6 Oct).
@export var return_frame_path: NodePath
@export var return_yaw_degrees: float = 180.0
## Keep the place between visits instead of building it afresh each time. The theatre is
## rebuilt every visit, which is right for a show. The cave is not a show: a slab you have
## dug into should still have the hole in it next time, and a seam you have emptied should
## stay empty - rebuilt, it came back whole with six fresh pieces of gold, which was a way
## to print money. Kept, it is taken out of the tree on the way home and put back on the
## next visit exactly as it was.
@export var keep_scene: bool = false
## Other crossings that, while away, make this one stay shut - so the cave's key does not
## open a cave on top of the theatre.
@export var blocked_by: Array[NodePath] = []

@export_group("Testing")
## A way straight in and straight out again, for looking at the theatre without walking
## the whole invitation first. It TOGGLES - the same key brings you home - because a way
## in that needs a different way out is half a shortcut.
##
## It deliberately does not touch the invitation. Jumping in this way leaves Trym exactly
## where he was, which is the honest thing for a debug key to do: it should show you the
## room, not fake the scene that leads to it.
@export var debug_key_enabled: bool = true
@export var debug_key: Key = KEY_C
## Whether the debug key first stages whatever normally leads up to the trip (Trym's
## invitation, for the theatre). A place with no lead-up leaves it off.
@export var stage_before_testing: bool = true

var _theatre: Node
## The place, parked between visits, when keep_scene is on.
var _kept: Node
var _asleep: Array[Node] = []
var _hidden: Array[CanvasItem] = []
var _was_at := Vector4.ZERO


func _ready() -> void:
	for path in asleep_paths:
		var branch: Node = get_node_or_null(path)
		if branch != null:
			_asleep.append(branch)


func _unhandled_key_input(event: InputEvent) -> void:
	if not debug_key_enabled:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != debug_key:
		return
	get_viewport().set_input_as_handled()
	if is_away():
		come_back()
	else:
		go_for_testing()


func is_away() -> bool:
	return _theatre != null and is_instance_valid(_theatre)


## The debug key's way in. Same trip, but anything that stages the journey is first put
## into the state it would be in had you walked it - so coming back plays the real
## homecoming rather than the mechanical half of it.
func go_for_testing() -> void:
	if is_away():
		return
	if stage_before_testing:
		for node in get_tree().current_scene.get_children():
			_stage_trip(node)
	go()


func _stage_trip(node: Node) -> void:
	if node.has_method("stage_as_if_followed"):
		node.call("stage_as_if_followed")
	for child in node.get_children():
		_stage_trip(child)


## Through the door.
##
## AND THE ROOM IS BUILT HERE, NOT EARLIER. THAT WAS TRIED AND IT IS NOT POSSIBLE LIKE
## THIS.
##
## Building the theatre during Trym's offer and parking it disabled and invisible is the
## obvious answer to the stall, and it measured beautifully - 3,946 ms at the door down to
## 2.0. It is also wrong, for a reason `visible` hides: theatre.tscn carries a
## WorldEnvironment4D with `current = true`, and an environment is not a visual node. The
## moment it enters the tree it owns the sky, the tonemapping and the mood of whatever
## scene it landed in - so the farm turned into the inside of the cinema while the player
## was still standing in a field, and its Camera4D was one `current` away from taking the
## view as well.
##
## Making it safe would mean reaching into the parked room and switching off its
## environment, its lights and its camera, then switching them back on at the threshold -
## which is a list of things to remember, and the next thing added to theatre.tscn that
## claims a global would not be on it. The stall is worth more than that risk. What made
## the real difference was not scheduling at all: the goat's twelve lofts are baked to
## disk now, which took part two from 3,474 ms to 697 on its own.
##
## THERE WAS ALSO A LOADING TUNNEL HERE AND IT HAS BEEN TAKEN OUT.
##
## Going through costs a visible second - the theatre is instantiated whole, carving its
## own rock and building its floor, house, backdrop and three exhibits on the frame it
## arrives - so a curtain over that second is the right idea. This one did not land on it.
## It was shown, then two `process_frame`s were awaited, then the theatre was built; but
## `process_frame` fires at the START of an idle frame, before anything is drawn, so the
## curtain went up on screen roughly when the stall ended. Ramon saw it flash AFTER
## arriving, which is worse than no curtain at all.
##
## `await RenderingServer.frame_post_draw` is the wait that actually means "it is on the
## screen", and it is a one-line difference - so this is recoverable if it is ever wanted
## back. Ramon's call was to drop it rather than iterate, and a stall you were not warned
## about beats a curtain that arrives to congratulate you on having waited.
func go() -> void:
	if is_away() or theatre_scene == null:
		return
	for path in blocked_by:
		var other: Node = get_node_or_null(path)
		if other != null and other.has_method("is_away") and bool(other.call("is_away")):
			return
	var player: Node4D = get_node_or_null(player_path) as Node4D
	if player != null:
		# Where to put them back down. Not the door - standing in a doorway you have just
		# come out of is how you walk straight back through it.
		_was_at = player.global_position
	_hidden.clear()
	for branch in _asleep:
		if not is_instance_valid(branch):
			continue
		branch.process_mode = Node.PROCESS_MODE_DISABLED
		if branch is Node4D:
			(branch as Node4D).visible = false
		_put_away(branch)
	if _kept != null and is_instance_valid(_kept):
		_theatre = _kept
		_kept = null
		get_tree().current_scene.add_child(_theatre)
		# Its own way out was used on the way home last time.
		_rearm(_theatre)
	else:
		_theatre = theatre_scene.instantiate()
		get_tree().current_scene.add_child(_theatre)
	# The way home, connected here rather than inside the theatre - the theatre has no
	# business knowing what it was opened from.
	var exit: Node = _theatre.get_node_or_null("ExitArch")
	if exit != null and exit.has_signal("entered") and not exit.is_connected("entered", come_back):
		exit.connect("entered", come_back)
	if bring_player and player != null and _theatre.has_method("arrival"):
		player.global_position = _theatre.call("arrival")
		_face(player, arrival_yaw_degrees)


## And back out of it.
func come_back() -> void:
	if not is_away():
		return
	if keep_scene:
		_theatre.get_parent().remove_child(_theatre)
		_kept = _theatre
	else:
		_theatre.queue_free()
	_theatre = null
	for branch in _asleep:
		if not is_instance_valid(branch):
			continue
		branch.process_mode = Node.PROCESS_MODE_INHERIT
		if branch is Node4D:
			(branch as Node4D).visible = true
	for item in _hidden:
		if is_instance_valid(item):
			item.visible = true
	_hidden.clear()
	var camera: Camera4D = get_node_or_null(farm_camera_path) as Camera4D
	if camera != null:
		camera.current = true
	var player: Node4D = get_node_or_null(player_path) as Node4D
	if player != null and _was_at != Vector4.ZERO:
		# A pace back from where they went in, and on the floor.
		var frame: Node4D = get_node_or_null(return_frame_path) as Node4D if not return_frame_path.is_empty() else null
		var offset: Vector4 = frame.global_basis * return_offset if frame != null else return_offset
		var turn: float = 0.0
		if frame != null:
			var z: Vector4 = frame.global_basis.z
			turn = rad_to_deg(atan2(z.x, z.z))
		player.global_position = _was_at + offset
		if face_on_return:
			_face(player, return_yaw_degrees + turn)
	# The door has to be walkable again, or the second visit never happens.
	for node in get_tree().current_scene.get_children():
		_rearm(node)


## Stops the body and points its camera rig at [param yaw_degrees].
func _face(player: Node4D, yaw_degrees: float) -> void:
	if player is CharacterBody4D:
		(player as CharacterBody4D).linear_velocity = Vector4.ZERO
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null and rig.has_method("_apply"):
		rig.set("yaw", deg_to_rad(yaw_degrees))
		rig.call("_apply")


## Every Control in a branch that is currently showing, remembered so it can be put back
## exactly as it was.
func _put_away(node: Node) -> void:
	if node is CanvasItem:
		var item := node as CanvasItem
		if item.visible:
			item.visible = false
			_hidden.append(item)
		# Children of a hidden CanvasItem are hidden with it; no need to walk further.
		return
	for child in node.get_children():
		_put_away(child)


func _rearm(node: Node) -> void:
	if node.has_method("rearm"):
		node.call("rearm")
	for child in node.get_children():
		_rearm(child)
