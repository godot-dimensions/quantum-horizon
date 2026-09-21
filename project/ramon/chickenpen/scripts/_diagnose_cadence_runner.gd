extends SceneTree
## How fast are the legs actually cycling, and what stride would a slower cadence need?
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 120: return false
	Input.action_press(&"move_back")
	if _f < 200: return false
	var gait: Node = _root.get_node("Player/Gait")
	var clock: Node = gait.get_node("GaitClock")
	var speed: float = float(gait.get("speed"))
	var stride: float = float(gait.get("stride_length"))
	var period: float = float(clock.period_sec)
	var thigh: float = float(gait.get("_thigh"))
	var shin: float = float(gait.get("_shin"))
	var reach: float = thigh + shin
	var hip: float = float(gait.get("_hip_height"))
	print("speed %.2f units/s | stride %.3f | period %.2f s -> %.1f steps/s per leg" % [
		speed, stride, period, 1.0 / maxf(period, 0.001)])
	print("leg reach %.3f, hip %.3f -> geometric max sweep %.3f, so max stride %.3f" % [
		reach, hip, sqrt(maxf(reach * reach - hip * hip, 0.0)), 2.0 * sqrt(maxf(reach * reach - hip * hip, 0.0))])
	print("for a period 4x longer at this speed the stride would have to be %.2f units" % (stride * 4.0))
	Input.action_release(&"move_back")
	return true
