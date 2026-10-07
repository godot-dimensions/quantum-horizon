extends Node

## Swallows every real key, mouse and pad event before the scene sees it, for runners that take frames:
## Ramon's typing and mouse reached a capture window on 7 Oct (a U started the hawk's flight in the
## middle of the coop's frames, though the window was unfocusable). Added to the root after the scene,
## so it hears input first (input goes from the last node to the first). Runners that press keys on
## purpose (Input.parse_input_event) must not use it.


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
