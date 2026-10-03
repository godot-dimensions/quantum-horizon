extends SceneTree

## Pictures of Trym: hunched at the laptop, and on his feet facing you.
##
## A CAMERA OF ITS OWN, not the player's. Driving the orbit rig puts the player body three
## metres in front of the lens and directly between it and whatever is being photographed -
## the first attempt at this produced four pictures of the back of the player's head. A
## free camera can stand wherever the picture wants.

var _root: Node
var _f := 0
var _t0 := 0
var _pending := ""
var _shots := 0
var _eye: Camera4D


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


## Points the free camera at a spot. The rig's own convention: the camera looks along its
## own -Z, its basis is from_zx(yaw) * from_yz(pitch), so the angles fall straight out.
func _look_from(eye: Vector4, target: Vector4) -> void:
	var f: Vector4 = (target - eye).normalized()
	var yaw: float = atan2(-f.x, -f.z)
	var pitch: float = asin(clampf(f.y, -1.0, 1.0))
	_eye.global_position = eye
	_eye.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/trym_%s.png" % _pending)
		print("saved trym_%s.png" % _pending)
		_pending = ""
		return false

	var trym: Node4D = _root.get_node("World/Trym")
	var player: Node4D = _root.get_node("Player")
	if _t0 == 0:
		_t0 = Time.get_ticks_msec()
		# DUPLICATED from the scene's own camera, not built fresh. A default Camera4D
		# renders wireframe on black; the scene's is set to "Cross-section" with a W fade,
		# and copying it is the only way to photograph what the player actually sees.
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye)
		_eye.position = Vector4.ZERO
		_eye.current = true
		print("Trym built with %d parts, at %v" % [trym.get_child_count(), trym.global_position])
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var at: Vector4 = trym.global_position

	if _shots < 2:
		# Player parked well away, so he stays at the desk. Three-quarter view from his
		# right, close enough to read the pose.
		player.global_position = Vector4(25.0, 1.3, 25.0, 0.0)
		player.set("linear_velocity", Vector4.ZERO)
		_look_from(at + Vector4(2.3, 1.35, 2.2, 0.0), at + Vector4(0.0, 0.75, 0.2, 0.0))
	else:
		# Somebody standing in front of him, photographed from the side so both are in it.
		player.global_position = at + Vector4(0.3, 1.3, 2.3, 0.0)
		player.set("linear_velocity", Vector4.ZERO)
		_look_from(at + Vector4(3.1, 1.5, 1.4, 0.0), at + Vector4(0.1, 0.8, 1.0, 0.0))

	if _f % 30 != 0: return false
	if _shots == 0 and elapsed > 1.5:
		_pending = "00_seated"; _shots += 1
	elif _shots == 1 and elapsed > 2.5:
		_pending = "01_seated"; _shots += 1
	elif _shots == 2 and elapsed > 7.5:
		_pending = "02_standing"; _shots += 1
	elif _shots == 3 and elapsed > 9.5:
		_pending = "03_standing"; _shots += 1
	elif _shots >= 4:
		quit(0); return true
	return false
