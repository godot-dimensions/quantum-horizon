extends Label

## The controls, on screen, at a size you can read from across a desk.
##
## BUILT FROM THE INPUT MAP, not typed out. Every other piece of text in this prototype
## that names a key reads it from `InputMap` - the locator, the tutor, the catch prompt -
## for the same reason: a printed key name is a claim that stops being true the moment
## somebody rebinds, and a card of wrong controls is worse than no card. Rebind anything
## and this line changes with it.
##
## ALWAYS UP, rather than a hint that fades. The tutor's hints teach one verb each at the
## moment it first matters and then leave; this is the reference you glance at afterwards,
## and a reference that hides itself is not one. H puts it away for a clean capture.

## Font size. Large on purpose - this is meant to be legible over a shoulder, not tucked
## into a corner for the player alone.
@export_range(12, 48, 1) var text_size: int = 22

## Held by an outline rather than a panel behind it, so it stays readable over pale sky and
## dark ground alike without a box that has to be kept in sync with the text's size.
@export_range(0, 12, 1) var outline: int = 6

@export var toggle_key: Key = KEY_H

## Bottom-left, growing upward, or pinned to whatever corner the scene put it in. The
## card moved to the top right to clear the bottom of the screen for dialogue, and up
## there it has to grow DOWNWARD or the first rows walk off the top edge.
@export var pin_to_bottom: bool = true


func _ready() -> void:
	add_theme_font_size_override("font_size", text_size)
	add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.09, 0.85))
	add_theme_constant_override("outline_size", outline)
	# Pinned to the bottom of its rect, so the block grows upward and its last line stays
	# put however many lines it ends up with.
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if pin_to_bottom else VERTICAL_ALIGNMENT_TOP
	text = _card()
	# Grow the rect to whatever the card actually needs. Sizing it by hand in the scene
	# clipped the last line the moment a row was added, and the row that went missing was
	# the one naming the key that hides this.
	if pin_to_bottom:
		custom_minimum_size = Vector2(0.0, get_combined_minimum_size().y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == toggle_key:
		visible = not visible
		get_viewport().set_input_as_handled()


## The verbs in the order you need them: get there, get into its slice, pick it up, put it
## in the pen.
func _card() -> String:
	var lines: Array = [
		"%s  move      mouse  look" % _keys([&"move_forward", &"move_left", &"move_back", &"move_right"]),
		"%s / %s  step ana / kata - through the fourth axis" % [
			_key(&"move_ana"), _key(&"move_kata")],
		"T  pick the nearest chicken - it tells you which way to slice-rotate onto it",
		"%s  pick up a chicken, and throw the one you are holding" % _key(&"catch_target"),
		"%s  put it down where you stand instead" % _key(&"fire"),
		"hold %s + mouse  turn the view through W" % _key(&"rotate_4d"),
		"R  back to the slice you started on - level and at w zero",
		"%s  jump      Ctrl+R  restart      %s  hide this      Esc  quit" % [
			_key(&"move_jump"), OS.get_keycode_string(toggle_key)],
	]
	return "\n".join(lines)


func _keys(actions: Array) -> String:
	var out: Array = []
	for action in actions:
		out.append(_key(action))
	return "".join(out)


func _key(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return "left mouse"
				MOUSE_BUTTON_RIGHT:
					return "right mouse"
				MOUSE_BUTTON_MIDDLE:
					return "middle mouse"
			return "mouse %d" % (event as InputEventMouseButton).button_index
	return "?"
