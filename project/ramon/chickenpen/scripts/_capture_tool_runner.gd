extends SceneTree

## A portrait of the tool in the fist, from the front and from the side.
##
## AIMED AT THE PROP, not at a guessed crop box. Three attempts at judging this from a
## corner of a full-frame screenshot went wrong - twice the body was in the way and once
## the crop was entirely sky - so the camera is put a fixed distance from the pickaxe's
## own collar and pointed at it, which cannot miss.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0
var _eye: Camera4D

const VIEWS := [[Vector4(0.0, 0.10, 0.95, 0.0), "front"],
	[Vector4(-0.95, 0.10, 0.0, 0.0), "side"],
	[Vector4(-0.62, 0.45, 0.62, 0.0), "over"]]


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/tool_%s.png" % _pending)
		print("saved tool_%s.png" % _pending)
		_pending = ""
		return false
	if _shots >= VIEWS.size():
		quit(0); return true

	var player: Node4D = _root.get_node("Player")
	var belt: Node = _root.get_node("UI/Inventory")
	var pick: Node = _root.get_node("Systems/Pickaxe")
	if _eye == null:
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye); _eye.position = Vector4.ZERO; _eye.current = true
		belt.call("_choose", 0)
	player.global_position = Vector4(0.0, 1.2, 0.0, 0.0)
	player.set("linear_velocity", Vector4.ZERO)
	player.set("_facing", 0.0)
	pick.call("_hang_it")
	# Held at rest, which is the pose the grip has to look right in.
	pick.call("_pose", 0.0)

	var collar: Node4D = _root.get_node_or_null(
		"Player/Avatar/ShoulderR/ElbowR/Pickaxe/Collar") as Node4D
	if collar == null:
		print("   the pickaxe is not in the hand")
		quit(1); return true
	var at: Vector4 = collar.global_position
	var eye_at: Vector4 = at + VIEWS[_shots][0]
	var f: Vector4 = (at - eye_at).normalized()
	_eye.global_position = eye_at
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) \
		* Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))

	if _f % 18 != 0: return false
	_pending = String(VIEWS[_shots][1])
	_shots += 1
	return false
