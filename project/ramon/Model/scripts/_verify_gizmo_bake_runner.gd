extends SceneTree

## Checks that nothing touches a ball's basis on its own any more - the automatic
## bake is what caused the jitter, because "nothing changed since last frame" is
## also true whenever the mouse pauses mid-drag, and baking then restarts the
## compounding.
##
## So: hold a scale steady for several frames and confirm the basis is left exactly
## as it is and the effective size never drifts. Then press the button once and
## confirm it folds in cleanly, changing the numbers but not the shape.

var _instance: Node
var _rig: Node
var _ball: Node
var _frame: int = 0


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	_frame += 1
	if _rig == null:
		_rig = _instance.get_node("Models/LoftRig")
		_rig.verbose = false
		_ball = _rig.get_node("Ball2")
		_ball.basis = Projection(
			Vector4(2.0, 0, 0, 0), Vector4(0, 2.0, 0, 0),
			Vector4(0, 0, 2.0, 0), Vector4(0, 0, 0, 2.0))
		print("--- holding a 2.0x gizmo scale steady, as if pausing mid-drag ---")
		return false

	if _frame <= 6:
		_report("frame %d, untouched" % _frame)
		return false
	if _frame == 7:
		print("--- pressing 'Bake ball scaling' once ---")
		_rig.bake_ball_scaling()
		return false
	_report("after the button")
	return true


func _report(label: String) -> void:
	print("%-22s stored radius=%6.3f  basis=%5.3f  ->  effective radius=%6.3f" % [
		label, _ball.radius, _ball.basis.x.length(), _ball.get_loft_section()["radius"]
	])
