@tool
extends CanvasLayer

## "Back to hub" prompt, shared by every prototype the hub links to.
##
## HOW THE SHARING WORKS: this lives in one scene, `Demo/return_button.tscn`, and
## each prototype instances it. Editing that scene restyles every copy at once,
## because a Godot instance reads its source scene rather than owning a snapshot -
## the same property that lets one `sign_style.tres` drive both the hub's signs and
## the preview board. There is no autoload and no entry in project.godot, so
## nothing leaks outside the Demo folder or into anyone else's scenes.
##
## A [CanvasLayer] rather than a plain [Control] so it draws over whatever the
## prototype is rendering - 4D cross-section, 3D, its own UI - without joining that
## scene's layout or being affected by it.
##
## KEY ONLY, no click. These scenes capture the mouse for look, so a clickable
## button would fight the cursor. The label's job is to advertise the key, not to
## be pressed.

const Palette := preload("res://ramon/Demo/scripts/hub_palette.gd")

## Marks generated children so a rebuild clears exactly what it made.
const GENERATED_META := "hub_generated"

@export_tool_button("Rebuild button") var _rebuild_action: Callable = rebuild

## Where the key sends the player. Repoint it here and every prototype follows,
## which is the whole point of one shared scene.
##
## A PATH, not a [PackedScene], and that is load-bearing rather than a preference.
## The hub already points AT the prototypes - gate05's `target_scene` is the
## gallery - so a PackedScene here would close the loop:
## hub1 -> gallery -> return_button -> hub1. Godot resolves ExtResources
## statically and cannot load a cycle; it fails with "Parse Error: Busy" and
## neither scene opens. A path is resolved at runtime by `change_scene_to_file`,
## so the dependency only exists at the moment it is used.
##
## Any two scenes that link to each other need one of the two edges to be lazy
## like this. The hub keeps the typed picker; the way back is the string.
##
## CHANGED 2026-08-25: this now points at the MENU, not at the hub.
##
## Trym's call is that the diegetic hub is not the right front door for
## stakeholders yet, so the demo is becoming a chamber package reached from a
## conventional menu. Repointing here is what actually retires the hub: every
## prototype instances this one scene, so the hub stops being reachable from
## anywhere in normal play the moment this default changes. `HubFinal.tscn` still
## exists and still opens directly - it is deprecated as a destination, not
## deleted.
##
## Because this is a hand-written path, renaming or moving the menu silently
## breaks every return button at once - which already happened when hub3.tscn
## became hub3Final.tscn and all seven prompts quietly stopped working. If the
## mockup is ever renamed or promoted out of ramon/Menu/, update this line.
@export_file("*.tscn") var hub_scene_path: String = "res://ramon/Menu2.tscn":
	set(value):
		hub_scene_path = value
		rebuild()

## Raw keycode rather than an input action, because project.godot is shared and an
## action there would leak this out of the Demo folder. Same reasoning as
## hub_slice_reset.gd's R.
@export var return_key: Key = KEY_H:
	set(value):
		return_key = value
		rebuild()

## Shown on the prompt. `%s` is replaced with the key's name, so relabelling the
## key cannot leave the text lying about which key to press.
@export var label_format: String = "BACK TO MENU   %s":
	set(value):
		label_format = value
		rebuild()

@export_group("Style")
## Optional link to the hub's sign styling. When assigned, the font, panel colour,
## text colour and corner radius come from it, so restyling the signs restyles this
## too. Leave empty to use the values below instead.
##
## Only those four are borrowed: [HubSignStyle4D] sizes everything in METRES for 3D
## geometry, and screen UI is in pixels, so sizing stays local.
@export var sign_style: HubSignStyle4D:
	set(value):
		sign_style = value
		rebuild()

@export var font: Font:
	set(value):
		font = value
		rebuild()

@export_range(8, 96, 1, "suffix:px") var font_size: int = 20:
	set(value):
		font_size = value
		rebuild()

@export var panel_color: Color = Color(0.235, 0.510, 0.808, 1.0):
	set(value):
		panel_color = value
		rebuild()

@export var text_color: Color = Color(0.902, 0.902, 0.902, 1.0):
	set(value):
		text_color = value
		rebuild()

@export_range(0, 40, 1, "suffix:px") var corner_radius: int = 8:
	set(value):
		corner_radius = value
		rebuild()

@export var padding: Vector2 = Vector2(18.0, 10.0):
	set(value):
		padding = value
		rebuild()

@export_range(-40, 40, 1, "suffix:px") var letter_spacing: int = 1:
	set(value):
		letter_spacing = value
		rebuild()

@export_group("Placement")
## Distance from the corner of the screen, in pixels.
@export var margin: Vector2 = Vector2(24.0, 24.0):
	set(value):
		margin = value
		rebuild()

## Which corner it sits in. Bottom-left by default: it is a persistent affordance
## rather than an alert, and that corner is the one least likely to cover a
## crosshair, a score, or whatever the prototype puts in the middle.
@export_enum("Bottom left", "Bottom right", "Top left", "Top right") var corner: int = 0:
	set(value):
		corner = value
		rebuild()


func _ready() -> void:
	rebuild()


## Text with the key name substituted in.
func get_label_text() -> String:
	var key_name := OS.get_keycode_string(return_key)
	if label_format.contains("%s"):
		return label_format % key_name
	return label_format


func rebuild() -> void:
	if not is_inside_tree():
		return
	# Nil-tolerant, because a @tool script that gains exports while a scene is open
	# returns Nil for them until reload - and a Nil here would either error or draw
	# a blank box. See project/ramon/follow_up/hub_demo_lessons.md.
	if typeof(corner_radius) != TYPE_INT or typeof(padding) != TYPE_VECTOR2:
		push_warning("ReturnButton: exports are not initialised - reload the scene (Scene > Reload Saved Scene).")
		return

	for child in get_children():
		if child.has_meta(GENERATED_META):
			remove_child(child)
			child.queue_free()

	var style := StyleBoxFlat.new()
	style.bg_color = _panel_color()
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_detail = 8
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y

	var panel := PanelContainer.new()
	panel.name = "Prompt"
	panel.set_meta(GENERATED_META, true)
	panel.add_theme_stylebox_override("panel", style)
	# Shrinks to the text rather than stretching, so the prompt is the size of what
	# it says and the corner margin means the same thing whatever the label is.
	panel.set_anchors_preset(_anchors_preset())
	panel.grow_horizontal = Control.GROW_DIRECTION_END if corner % 2 == 0 else Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN if corner < 2 else Control.GROW_DIRECTION_END
	panel.offset_left = margin.x if corner % 2 == 0 else -margin.x
	panel.offset_right = panel.offset_left
	panel.offset_top = -margin.y if corner < 2 else margin.y
	panel.offset_bottom = panel.offset_top
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var label := Label.new()
	label.name = "Label"
	label.text = get_label_text()
	label.add_theme_color_override("font_color", _text_color())
	label.add_theme_font_size_override("font_size", font_size)
	var face := _font()
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)


## Font with tracking applied, matching how the signs open their capitals out.
func _font() -> Font:
	var base: Font = sign_style.font if sign_style != null and sign_style.font != null else font
	if letter_spacing == 0:
		return base
	var variation := FontVariation.new()
	if base != null:
		variation.base_font = base
	variation.set_spacing(TextServer.SPACING_GLYPH, letter_spacing)
	return variation


func _panel_color() -> Color:
	if sign_style != null:
		return sign_style.get_panel_color()
	return panel_color if typeof(panel_color) == TYPE_COLOR else Palette.signage()


func _text_color() -> Color:
	if sign_style != null:
		return sign_style.get_text_color()
	return text_color if typeof(text_color) == TYPE_COLOR else Palette.signage_text()


func _anchors_preset() -> int:
	match corner:
		1:
			return Control.PRESET_BOTTOM_RIGHT
		2:
			return Control.PRESET_TOP_LEFT
		3:
			return Control.PRESET_TOP_RIGHT
		_:
			return Control.PRESET_BOTTOM_LEFT


func _unhandled_input(event: InputEvent) -> void:
	# @tool means this runs while authoring too, where changing scene would close
	# whatever is being edited.
	if Engine.is_editor_hint():
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != return_key:
		return
	get_viewport().set_input_as_handled()
	_return_to_hub.call_deferred()


## Deferred for the same reason the gate trigger is: change_scene_to_packed frees
## the current scene immediately, and doing that from inside input handling pulls
## the ground out from under the event still being dispatched.
func _return_to_hub() -> void:
	if hub_scene_path.is_empty():
		push_warning("ReturnButton: no hub_scene_path set, nothing to return to.")
		return
	# Checked explicitly, because the alternative is a key that does nothing and no
	# way to tell why. This is a hand-written path rather than a resource
	# reference - which it has to be, to keep the hub/prototype link free of a
	# dependency cycle - so RENAMING THE HUB SILENTLY BREAKS EVERY RETURN BUTTON.
	# That already happened once: hub3.tscn became hub3Final.tscn and all seven
	# prompts quietly stopped working.
	if not ResourceLoader.exists(hub_scene_path):
		push_error("ReturnButton: hub scene '%s' does not exist - was it renamed? Update hub_scene_path in Demo/return_button.tscn." % hub_scene_path)
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(hub_scene_path)
