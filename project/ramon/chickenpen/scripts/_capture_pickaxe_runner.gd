extends SceneTree

## The rock before and after a few swings, with the pickaxe in hand in the belt.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0
var _eye: Camera4D


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _middle(voxels: Node) -> Vector4:
	var sum := Vector4.ZERO
	var n: int = 0
	for shape in voxels.get_children():
		if shape is CollisionShape4D:
			sum += (shape as CollisionShape4D).global_position
			n += 1
	return sum / maxf(float(n), 1.0)


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/pickaxe_%s.png" % _pending)
		print("saved pickaxe_%s.png" % _pending)
		_pending = ""
		return false

	var rock: Node4D = _root.get_node("World/MiningRock")
	var voxels: Node = rock.get_node("Voxels")
	var belt: Node = _root.get_node("UI/Inventory")
	var pick: Node = _root.get_node("Systems/Pickaxe")
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")

	if _eye == null:
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye)
		_eye.position = Vector4.ZERO
		_eye.current = true
		belt.call("_choose", 0)

	var middle: Vector4 = _middle(voxels)
	player.global_position = Vector4(middle.x, 1.2, middle.z + 2.2, middle.w)
	player.set("linear_velocity", Vector4.ZERO)
	var to: Vector4 = middle - player.global_position
	rig.set("yaw", atan2(-to.x, -to.z))
	rig.set("pitch", 0.0)
	rig.call("_apply")
	pick.set("chest_height", middle.y - player.global_position.y)

	# The camera for the picture stands off to the side, so the rock is not hidden behind
	# the character that is hitting it.
	var eye_at: Vector4 = middle + Vector4(3.4, 2.2, 3.4, 0.0)
	var f: Vector4 = (middle - eye_at).normalized()
	_eye.global_position = eye_at
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) \
		* Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))

	if _f % 25 != 0: return false
	if _shots == 0:
		_pending = "00_whole"; _shots += 1
	elif _shots < 9:
		# A handful of swings, aimed slightly differently each time by nudging the yaw.
		rig.set("yaw", atan2(-to.x, -to.z) + sin(float(_shots) * 1.7) * 0.10)
		rig.set("pitch", sin(float(_shots) * 2.3) * 0.09)
		rig.call("_apply")
		pick.call("_swing")
		_shots += 1
	elif _shots == 9:
		_pending = "01_mined"; _shots += 1
	else:
		quit(0); return true
	return false
