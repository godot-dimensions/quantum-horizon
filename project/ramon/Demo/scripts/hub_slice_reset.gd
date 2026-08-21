@tool
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

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")

## Same reset, as a button, because in the editor there is no key to press.
##
## The keycode below only exists at runtime - [method _unhandled_input] is not
## delivered while authoring - so a scene left mid-rotation could only be
## straightened by editing the Player's basis by hand, which is sixteen floats in
## a [Projection] and no way to do it by eye.
##
## Named for the PLAYER specifically, because it does not touch the editor's own 4D
## viewport camera and the shorter name implied it did. That camera is unreachable
## from script - [EditorCamera4D] has an empty `_bind_methods()` and is not
## registered for scripting - so the only reset for the VIEW is clicking an axis on
## the viewport's rotation gizmo, which calls `set_ground_view_axis` internally.
@export_tool_button("Reset player slice") var _reset_action: Callable = reset_slice

## Which key restores the home slice. Raw keycode rather than an action, so this
## needs no entry in the shared project.godot.
@export var reset_key: Key = KEY_R

## Also returns the player to where they started. Off by default: losing your
## slice and losing your position are different problems, and quietly teleporting
## someone is more startling than helpful when only the rotation went wrong.
@export var also_return_to_spawn: bool = false

@export var player_path: NodePath = ^"../Player"

@export_group("Prompt")
## Small on-screen hint naming the key. Nothing else in the hub advertises R, and
## a rescue key nobody knows about rescues nobody - which is the whole reason this
## node exists.
##
## Bottom-left, matching return_button.tscn, and they never collide: the hub has a
## reset and no return, a prototype has a return and no reset.
@export var show_prompt: bool = true:
	set(value):
		show_prompt = value
		_build_prompt()

## `%s` becomes the key name, so rebinding cannot leave the text lying about which
## key to press - same guarantee as the return button's label.
@export var prompt_format: String = "%s   RESET SLICE":
	set(value):
		prompt_format = value
		_build_prompt()

## Borrows font and colours so this matches the signs. Empty falls back to the
## palette.
@export var sign_style: HubSignStyle4D:
	set(value):
		sign_style = value
		_build_prompt()

@export_range(8, 64, 1, "suffix:px") var font_size: int = 16:
	set(value):
		font_size = value
		_build_prompt()

var _spawn_position: Vector4 = Vector4()
var _has_spawn: bool = false


func _ready() -> void:
	_build_prompt()
	var player := _player()
	if player != null:
		_spawn_position = player.position
		_has_spawn = true


func _player() -> Node4D:
	if player_path.is_empty():
		return null
	return get_node_or_null(player_path) as Node4D


func _unhandled_input(event: InputEvent) -> void:
	# @tool means this script now runs while authoring too, and without this guard
	# every R typed into the editor - renaming a node, filling in a blurb - would
	# quietly rotate the Player. The button above is the editor's route in.
	if Engine.is_editor_hint():
		return
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


## Builds the corner hint. Regenerated wholesale rather than patched, the same way
## every other generated thing in the hub is, so there is only ever one of it.
func _build_prompt() -> void:
	if not is_inside_tree():
		return
	# Nil-tolerant: a @tool script that gains exports while its scene is open reads
	# them as Nil until reload. See project/ramon/follow_up/hub_demo_lessons.md.
	if typeof(show_prompt) != TYPE_BOOL or typeof(font_size) != TYPE_INT:
		return
	var existing := get_node_or_null("ResetPrompt")
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	if not show_prompt:
		return

	# Deliberately NOT the sign styling. Signage blue is reserved for the gates and
	# would make a debug hint compete with them; this is an aid, not a destination.
	# Muted grey on a dark plate reads as information and stays out of the way.
	var panel_colour := Color(0.13, 0.13, 0.14, 0.55)
	var text_colour := Color(0.62, 0.63, 0.66, 1.0)

	var box := StyleBoxFlat.new()
	box.bg_color = panel_colour
	for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		box.set_corner_radius(corner, 8)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0

	var layer := CanvasLayer.new()
	layer.name = "ResetPrompt"
	layer.layer = 100
	add_child(layer)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_left = 16.0
	panel.offset_right = 16.0
	# Below the player-position readout, which sits at the very top - this belongs
	# with the debug information, not with the signage.
	panel.offset_top = 40.0
	panel.offset_bottom = 40.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)

	var label := Label.new()
	var key_name := OS.get_keycode_string(reset_key)
	label.text = prompt_format % key_name if prompt_format.contains("%s") else prompt_format
	label.add_theme_color_override("font_color", text_colour)
	label.add_theme_font_size_override("font_size", font_size)
	if sign_style != null and sign_style.font != null:
		label.add_theme_font_override("font", sign_style.font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
