extends Node

## Returns the player to the home slice - the hub's "unstick" key.
##
## There is no way back to the default slice anywhere in the project: the editor's
## only Reset buttons belong to the preview sun and environment, and project.godot
## defines move_kata, move_ana and rotate_4d but nothing that undoes a rotation.
## Once someone has slice-rotated, the only route back is turning by eye until it
## looks right, which is exactly the failure a stakeholder holding the controls
## cannot recover from.
##
## Deliberately scoped to the Demo hub rather than player.gd, and deliberately
## bound to a raw keycode rather than an input action - project.godot is shared
## too, so adding an action there would leak this outside the Demo folder.
##
## WHAT IT RESETS, and what it leaves alone: the body basis is rebuilt from the
## player's current horizontal heading only, so every w component goes to zero
## while the direction they are facing is preserved. Being spun round to face
## north as well would be its own small disorientation, and the point of this key
## is to remove disorientation. Head pitch lives on PlayerHead and is untouched
## for the same reason.

## Which key restores the home slice. Raw keycode rather than an action, so this
## needs no entry in the shared project.godot.
@export var reset_key: Key = KEY_R

## Also returns the player to where they started. Off by default: losing your
## slice and losing your position are different problems, and quietly teleporting
## someone is more startling than helpful when only the rotation went wrong.
@export var also_return_to_spawn: bool = false

@export var player_path: NodePath = ^"../Player"

var _spawn_position: Vector4 = Vector4()
var _has_spawn: bool = false


func _ready() -> void:
	var player := _player()
	if player != null:
		_spawn_position = player.position
		_has_spawn = true


func _player() -> Node4D:
	if player_path.is_empty():
		return null
	return get_node_or_null(player_path) as Node4D


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != reset_key:
		return
	reset_slice()


## Rebuilds the player's basis with the same heading and no w rotation.
func reset_slice() -> void:
	var player := _player()
	if player == null:
		push_warning("HubSliceReset: no player at '%s', nothing to reset." % str(player_path))
		return

	var basis: Projection = player.basis
	# Forward is -Z, matching the controller and Camera4D. Only its horizontal
	# part matters; the rest is what we are throwing away.
	var forward := -basis.z
	var heading := Vector2(forward.x, forward.z)
	if heading.length() < 0.0001:
		# Looking straight along w with no horizontal component left to preserve.
		# Any heading is as good as another, so face the arc.
		heading = Vector2(0.0, -1.0)
	heading = heading.normalized()

	# Same construction the gate ring uses: x cross y = z, right-handed, with w
	# pinned to the fourth axis so the home slice is exactly w = 0.
	var angle := atan2(heading.x, -heading.y)
	var cos_a := cos(angle)
	var sin_a := sin(angle)
	player.basis = Projection(
		Vector4(cos_a, 0.0, sin_a, 0.0),
		Vector4(0.0, 1.0, 0.0, 0.0),
		Vector4(-sin_a, 0.0, cos_a, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0)
	)

	if also_return_to_spawn and _has_spawn:
		player.position = _spawn_position
	else:
		# Even without a full teleport, w has to come back: sliding along w with
		# move_ana/move_kata leaves you in a parallel slice that no amount of
		# rotating will undo.
		var here: Vector4 = player.position
		player.position = Vector4(here.x, here.y, here.z, 0.0)
