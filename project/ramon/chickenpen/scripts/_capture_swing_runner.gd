extends SceneTree

## The swing, frame by frame, from the side - because "does the arm read as a swing" is
## not a number, and the last two attempts at this in the scene were settled by looking.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0
var _eye: Camera4D

const STOPS := [0.0, 0.25, 0.45, 0.6, 0.8, 1.0]


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/swing_%s.png" % _pending)
		_pending = ""
		return false
	if _shots >= STOPS.size():
		print("saved %d frames" % _shots)
		quit(0); return true

	var player: Node4D = _root.get_node("Player")
	var belt: Node = _root.get_node("UI/Inventory")
	var pick: Node = _root.get_node("Systems/Pickaxe")
	var avatar: Node4D = _root.get_node("Player/Avatar")
	if _eye == null:
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye); _eye.position = Vector4.ZERO; _eye.current = true
		belt.call("_choose", 0)
	player.global_position = Vector4(0.0, 1.2, 0.0, 0.0)
	player.set("linear_velocity", Vector4.ZERO)
	player.set("_facing", 0.0)
	pick.call("_hang_it")
	pick.call("_pose", float(STOPS[_shots]))

	# From the character's RIGHT, which is -X here: the arm holding the pickaxe is on
	# that side, and shot from the other one the body hides the whole swing - which is
	# what the first attempt at this photographed.
	var at: Vector4 = avatar.global_position + Vector4(0.0, 0.95, 0.0, 0.0)
	var eye_at: Vector4 = at + Vector4(-2.9, 0.25, 0.0, 0.0)
	var f: Vector4 = (at - eye_at).normalized()
	_eye.global_position = eye_at
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) \
		* Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))

	if _f % 18 != 0: return false
	_pending = "%02d" % _shots
	_shots += 1
	return false
