extends Area4D

## The end of the course: step onto the last pad and get a completion screen.
##
## Not a @tool script - it only runs during play, so the builder can spawn it in
## the editor without the overlay appearing while you author the room.
##
## The overlay is built in code rather than as a .tscn so the goal is one
## self-contained file. It is deliberately plain: this is a test bench, and the
## numbers on it (time, falls) are the two the brief asks to instrument.

## Emitted once, when the course is completed.
signal completed(seconds: float, falls: int)

@export var title: String = "OBSTACLE COURSE TEST COMPLETED"

## Where to read the fall counter from. Optional - if the player has no `falls`
## property the line is simply left out rather than erroring.
@export var player_path: NodePath = ^"../../Player"

var _fired: bool = false
var _started_at_ms: int = 0


func _ready() -> void:
	_started_at_ms = Time.get_ticks_msec()
	body_entered_self.connect(_on_body_entered)


func _on_body_entered(body: PhysicsBody4D) -> void:
	# Once only. The pad is broad and w-deep, so without this the overlay would be
	# rebuilt every time the body's rect re-tested against it.
	if _fired or not (body is CharacterBody4D):
		return
	_fired = true

	var seconds: float = float(Time.get_ticks_msec() - _started_at_ms) / 1000.0
	var falls: int = 0
	var player: Node = get_node_or_null(player_path)
	if player != null:
		var reported: Variant = player.get("falls")
		if reported != null:
			falls = int(reported)

	completed.emit(seconds, falls)
	print("COURSE COMPLETE: %.1f s, %d fall(s)" % [seconds, falls])
	# Deferred: this fires from inside the physics step, and adding UI to the tree
	# mid-step is the same class of hazard as changing scene from a physics signal.
	_show_overlay.call_deferred(seconds, falls)
	# Hand the mouse back, so the end screen can actually be looked at.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_overlay(seconds: float, falls: int) -> void:
	var layer := CanvasLayer.new()
	layer.name = "CompletionScreen"
	layer.layer = 100

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.04, 0.06, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	layer.add_child(column)

	column.add_child(_line(title, 44, Color(0.42, 0.89, 0.93)))
	column.add_child(_line("time   %s" % _format_time(seconds), 24, Color(0.86, 0.88, 0.92)))
	column.add_child(_line("falls  %d" % falls, 24, Color(0.86, 0.88, 0.92)))
	column.add_child(_line("Esc to quit", 18, Color(0.55, 0.58, 0.64)))

	# On the root, not on this Area4D: the builder clears and rebuilds its own
	# generated nodes, and the end screen should outlive that.
	get_tree().root.add_child(layer)


func _line(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _format_time(seconds: float) -> String:
	var whole: int = int(seconds)
	return "%d:%02d.%01d" % [whole / 60, whole % 60, int((seconds - float(whole)) * 10.0)]
