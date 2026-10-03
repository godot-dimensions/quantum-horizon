extends SceneTree

## The level in each of the states it is meant to tell apart, so the SHAPES can be
## compared by eye - which is the whole claim of the instrument.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0

const STATES := [[0.0, 0.0, 0.0, "00_home"], [1.5, 0.0, 0.0, "01_floating"],
	[0.0, 0.35, 0.0, "02_xw"], [0.0, 0.0, 0.35, "03_zw"], [0.6, 0.3, -0.25, "04_both"]]


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/plane_%s.png" % _pending)
		print("saved plane_%s.png" % _pending)
		_pending = ""
		return false
	if _shots >= STATES.size():
		quit(0); return true

	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var state: Array = STATES[_shots]
	player.global_position = Vector4(0.0, 1.3, 0.0, state[0])
	player.set("linear_velocity", Vector4.ZERO)
	rig.set("_slice_xw", state[1])
	rig.set("_slice_zw", state[2])
	rig.call("_apply")
	if _f % 20 != 0: return false
	# Printed from the same frame the picture is taken on, so a caption that disagrees
	# with the shape can be told from a capture that lagged a frame behind the state.
	var plane: Node = _root.get_node("UI/SlicePlane")
	var pen: Rect2 = plane.call("_footprint")
	var h: Array = []
	for c in [Vector2(pen.position.x, pen.position.y), Vector2(pen.end.x, pen.position.y),
			Vector2(pen.end.x, pen.end.y), Vector2(pen.position.x, pen.end.y)]:
		h.append(float(plane.call("_w_above", c.x, c.y)))
	print("   %-12s asked w %.2f xw %.2f zw %.2f | player at %v | corners %s"
		% [state[3], state[0], state[1], state[2], player.global_position,
			h.map(func(v): return "%+.2f" % v)])
	_pending = state[3]
	_shots += 1
	return false
