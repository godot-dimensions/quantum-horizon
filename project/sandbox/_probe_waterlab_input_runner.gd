extends SceneTree

## Why does looking around do nothing in the Aquatic Lab?
##
##   godot --path project --rendering-method forward_plus --resolution 800x500 \
##       --script res://sandbox/_probe_waterlab_input_runner.gd
##
## Feeding the rig's _unhandled_input by hand proved only that its maths works - it skips
## every stage that could be eating the event. This routes a motion event through the REAL
## pipeline with Input.parse_input_event (viewport, GUI, _input, then _unhandled_input) and
## compares the two, which tells delivery apart from arithmetic.
##
## NO `await` IN _process. A SceneTree script that awaits stops being driven; the first
## version of this check hung silently after one line of output.

var _f := 0
var _held := 0.0
var _root: Node = null
var _rig: Node = null
var _before_basis: Projection
var _before_pitch: float = 0.0
var _routed: float = -1.0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(d: float) -> bool:
	_f += 1
	if _f == 1:
		_root = (load("res://ramon/WaterLab/water_lab.tscn") as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	_held += d
	if _held < 3.0:
		return false

	if _rig == null:
		var player: Node = _root.get("player")
		if player == null:
			print("  FAIL - no player")
			quit(1)
			return true
		_rig = player.get_node_or_null(^"CameraRig")
		print("")
		print("  mouse_mode      %s" % ["VISIBLE", "HIDDEN", "CAPTURED", "CONFINED", "CONFINED_HIDDEN"][Input.mouse_mode])
		print("  slice_turning   %s" % _rig.get(&"slice_turning"))
		_before_basis = _rig.get(&"basis")
		_before_pitch = float(_rig.get(&"pitch"))
		var look := InputEventMouseMotion.new()
		look.relative = Vector2(60.0, 20.0)
		look.screen_relative = Vector2(60.0, 20.0)
		look.position = Vector2(root.size) * 0.5
		Input.parse_input_event(look)
		return false

	if _routed < 0.0:
		var now: Projection = _rig.get(&"basis")
		_routed = (_before_basis * Vector4(0, 0, 1, 0)).distance_to(now * Vector4(0, 0, 1, 0))
		print("  routed through the pipeline: heading moved %.4f, pitch %.4f" % [
				_routed, float(_rig.get(&"pitch")) - _before_pitch])
		var again := InputEventMouseMotion.new()
		again.relative = Vector2(60.0, 20.0)
		_rig.call(&"_unhandled_input", again)
		var direct: float = (now * Vector4(0, 0, 1, 0)).distance_to((_rig.get(&"basis") as Projection) * Vector4(0, 0, 1, 0))
		print("  fed straight to the rig:     heading moved %.4f" % direct)
		print("")
		if _routed < 0.001 and direct > 0.001:
			print("  -> CONSUMED: something eats the event before the rig sees it")
		elif _routed > 0.001:
			print("  -> DELIVERED: looking works when the lab is run directly")
		else:
			print("  -> the rig does not turn even when fed directly")
		quit(0)
		return true
	return false
