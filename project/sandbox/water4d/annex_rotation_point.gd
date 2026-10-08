extends Node

## The ring mid-span on the walkway: stand on it and 4D rotation is switched on; step off and
## it is switched off again and the slice eases back to flat.
##
## WHAT THIS DRIVES, AND THE VERSION THAT DID NOT WORK. The camera rig already owns slice
## turning - `pen_orbit_rig_4d.gd` has a `slice_turning` flag, holds the angles in `_slice_xw`
## and `_slice_zw`, composes them into its own frame every frame, and has a `go_home()` that
## eases them back. The gallery deliberately switches the flag OFF
## (`arboretum_4d.gd`: `rig.set("slice_turning", false)`), because Ramon found a whole
## rotating world confusing in a room full of exhibits.
##
## So the ring's job is to lend that flag back, not to rotate anything itself. The first
## version of this turned the PLAYER's basis directly, the way the pool room's HUD did. That
## could never have worked here: the rig rebuilds its own basis from yaw, pitch and
## `_slice_xw` every single frame, so a basis written from outside is gone before it is drawn.
## It passed a probe that called the turn directly and checked the maths, which measured my
## arithmetic rather than whether anything reached the screen.
##
## THE TEST IS IN THE ROOM'S OWN FRAME, not the world's. `is_on_rotation_point` compares
## against `room_size` and `rotation_radius`, both measured from the room node. The pool scene
## had that node at the origin so a world position worked by accident; the annex sits at
## (36, -3, 10.5), where the same call would put the ring inside the building.
##
## THE CONTROL IS THE GAME'S OWN: hold the right mouse button (`rotate_4d`) and move the
## mouse. Not a key of this room's invention - the rig reads the drag itself, and a second,
## different way to turn the slice is how two controls start disagreeing.
##
## AND SO IS THE PROMPT. This node does not draw one. The gallery's control strip already
## rebuilds itself every frame from where the player stands (`arboretum_4d.gd::_strip`), and
## it names the ring there, in the same chips and the same voice as every other hint in the
## building. A label of this room's own was a second HUD saying its own thing in its own
## style, next to one that was already doing the job.

@export var room_path: NodePath = NodePath("..")

var _room: Node4D = null
var _player: Node4D = null
var _rig: Node = null
## What the gallery had the flag set to before the ring touched it, so stepping off restores
## the room's own choice rather than assuming it was false.
var _was_turning: bool = false
var _on_ring: bool = false


func _ready() -> void:
	_room = get_node_or_null(room_path) as Node4D
	if _room == null:
		push_warning("Rotation point: no room at %s." % room_path)
		set_process(false)


func _process(_delta: float) -> void:
	if _resolve_rig() == null:
		return
	var here: Vector4 = _room.global_to_local(_player.global_position)
	var on_ring: bool = bool(_room.call(&"is_on_rotation_point", here))
	if on_ring == _on_ring:
		return
	_on_ring = on_ring
	if on_ring:
		_was_turning = bool(_rig.get(&"slice_turning"))
		_rig.set(&"slice_turning", true)
		return
	_rig.set(&"slice_turning", _was_turning)
	# Back to flat, through the rig's own route home rather than by zeroing its angles here -
	# it eases over `home_seconds` and also carries the player's own w back with it, which
	# setting the angles directly would leave behind.
	if _rig.has_method(&"go_home"):
		_rig.call(&"go_home")


## The gallery builds its player in code and hangs it off the scene root, so it cannot be
## found by a path written in advance - and children are ready before their parents, so it is
## not there yet when this node's _ready runs either. Hence: lazily, every frame until found.
func _resolve_rig() -> Node:
	if _rig != null and is_instance_valid(_rig):
		return _rig
	if _player == null or not is_instance_valid(_player):
		var owner_node: Node = _room.get_parent()
		if owner_node != null:
			var theirs: Variant = owner_node.get(&"player")
			if theirs is Node4D:
				_player = theirs as Node4D
		if _player == null:
			for node in _walk(get_tree().current_scene):
				if node is CharacterBody4D:
					_player = node as Node4D
					break
	if _player == null:
		return null
	_rig = _player.get_node_or_null(^"CameraRig")
	return _rig


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node == null:
		return found
	for child in node.get_children():
		found.append(child)
		found.append_array(_walk(child))
	return found
