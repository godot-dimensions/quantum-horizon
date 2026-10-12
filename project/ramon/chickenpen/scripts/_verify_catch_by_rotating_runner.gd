extends SceneTree

## Can a chicken be caught by ROTATING your slice onto it, rather than walking through W?
##
## That is the question the whole slice-rotate control exists to answer yes to. It used to
## be no: rotating made the bird visible while the catch went on measuring the world's W
## axis, so you could stand looking at a chicken you were forbidden to pick up.

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")

var _root: Node
var _f := 0
var _rig: Node4D
var _player: Node4D
var _catcher: Node
var _bird: Node
var _body: Node4D
var _step := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70:
		return false
	if _rig == null:
		_rig = _root.get_node("Player/CameraRig")
		_player = _root.get_node("Player")
		_catcher = _root.get_node("Player/Catcher")
		for a in (_root.get_node("Chickens").get("agents") as Array):
			if int(a.get("chicken_id")) == 7:
				_bird = a
		_body = _bird.get_parent() as Node4D
		print("chicken 7 sits at w %.2f. Standing beside it on slice zero and NOT moving" % _body.global_position.w)
		print("through W - only rotating the slice:\n")
		print("   %-8s %-10s %-9s %s" % ["xw", "ana", "prompt", "locator"])
	if _f % 18 != 0:
		return false

	# Stand next to it, in ordinary space, on slice zero. Never move through W.
	var here: Vector4 = _body.global_position
	_player.position = Vector4(here.x, 1.3, here.z + 1.1, 0.0)
	_player.set("_facing", atan2(0.0, -1.1))
	var xw: float = float(_step) * 0.12
	SliceAngles.tilt(_rig, xw, 0.0)
	if _step > 0:
		var slice: Projection = _rig.global_basis
		var rel: Vector4 = _body.global_position - _player.global_position
		print("   %-8.2f %-10.3f %-9s %s" % [
			xw, rel.dot(slice.w),
			"CATCH" if (_root.get_node("UI/CatchPrompt") as Label).text != "" else "-",
			(_root.get_node("UI/Locator") as Label).text.substr(9, 44)])
	_step += 1
	return _step > 9
