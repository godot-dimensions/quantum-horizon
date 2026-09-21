extends SceneTree

## A picture of the two dials, with a chicken placed dead ahead so the orientation can be
## checked by eye as well as by the facing runner.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/dials_%s.png" % _pending)
		print("saved dials_%s.png" % _pending)
		_pending = ""
		return false

	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var manager: Node = _root.get_node("Chickens")
	player.global_position = Vector4(0.0, 1.3, 0.0, 0.0)
	player.set("linear_velocity", Vector4.ZERO)
	player.set("_facing", 0.0)
	rig.set("yaw", PI)
	rig.call("_apply")

	# One chicken parked eight metres dead ahead - its dot must sit ABOVE the centre.
	var agents: Array = manager.get("agents") as Array
	if agents.size() > 0:
		var body: Node4D = (agents[0] as Node).get_parent() as Node4D
		body.global_position = Vector4(0.0, 0.0, 8.0, 0.0)

	if _f % 30 != 0: return false
	if _shots == 0:
		_pending = "00"; _shots += 1
	elif _shots == 1:
		_pending = "01"; _shots += 1
	else:
		quit(0); return true
	return false
