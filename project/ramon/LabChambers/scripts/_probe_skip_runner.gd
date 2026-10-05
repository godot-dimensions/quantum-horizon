extends SceneTree

## Clicking through the presentation past its last part: does the next click start it over?
## Calls the showcase's skip() a dozen times, then sends real left clicks through the room's input
## (with the mouse captured if the window lets it), printing the part after each.
##
##   LabChambers/scripts/lab_run.sh windowed skip res://ramon/LabChambers/scripts/_probe_skip_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"

var _g: Node


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _click() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(u)
	await process_frame


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.0)
	var sc: Node = _g.get_node("Showcase")
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(0.8, 0.05, 5.5, 0.0)
	var until: int = Time.get_ticks_msec() + 20000
	while int(sc.get("seq_index")) < 0 and Time.get_ticks_msec() < until:
		await process_frame
	var seen: Array = [int(sc.get("seq_index"))]
	for i in 12:
		sc.call("skip")
		await _wait(0.25)
		seen.append(int(sc.get("seq_index")))
	print("skip(): ", seen, "   looping ", sc.get("_looping"), "  loop_t %.2f" % float(sc.get("_loop_t")))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _wait(0.3)
	print("mouse captured: ", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "   in room ", _g.get("_in_room"))
	var seen2: Array = [int(sc.get("seq_index"))]
	for i in 12:
		await _click()
		await _wait(0.25)
		seen2.append(int(sc.get("seq_index")))
	print("clicks: ", seen2, "   looping ", sc.get("_looping"), "  touched %.1f  t %.1f" % [float(sc.get("_touched_at")), float(sc.get("_t"))])
	# Paused in your hands (a turn through W), then one click: it should start over at part 1.
	sc.call("turn_by", 0.3, 0.0)
	await _wait(0.4)
	var paused: int = int(sc.get("seq_index"))
	await _click()
	await _wait(0.3)
	print("paused at %d, after one click: part %d" % [paused, int(sc.get("seq_index"))])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit(0)
