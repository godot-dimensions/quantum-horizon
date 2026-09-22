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

var _theatre: Node
var _asleep: Array[Node] = []
var _hidden: Array[CanvasItem] = []
var _was_at := Vector4.ZERO


func _ready() -> void:
	for path in asleep_paths:
		var branch: Node = get_node_or_null(path)
		if branch != null:
			_asleep.append(branch)


func is_away() -> bool:
	return _theatre != null and is_instance_valid(_theatre)


## Through the door.
func go() -> void:
	if is_away() or theatre_scene == null:
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
	_theatre = theatre_scene.instantiate()
	get_tree().current_scene.add_child(_theatre)
	# The way home, connected here rather than inside the theatre - the theatre has no
	# business knowing what it was opened from.
	var exit: Node = _theatre.get_node_or_null("ExitArch")
	if exit != null and exit.has_signal("entered"):
		exit.connect("entered", come_back)


## And back out of it.
func come_back() -> void:
	if not is_away():
		return
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
		player.global_position = Vector4(_was_at.x, _was_at.y, _was_at.z + 1.6, _was_at.w)
	# The door has to be walkable again, or the second visit never happens.
	for node in get_tree().current_scene.get_children():
		_rearm(node)


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
