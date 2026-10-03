extends SceneTree

## The crow perched, and mid-beat in the air.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0
var _eye: Camera4D
var _crow: Node4D


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _look(at: Vector4, from: Vector4) -> void:
	var f: Vector4 = (at - from).normalized()
	_eye.global_position = from
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) \
		* Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/crow_%s.png" % _pending)
		print("saved crow_%s.png" % _pending)
		_pending = ""
		return false
	if _crow == null:
		_crow = _root.get_node("World/Crow")
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye); _eye.position = Vector4.ZERO; _eye.current = true
		_root.get_node("Player").position = Vector4(40.0, 1.3, 40.0, 0.0)
	if _shots >= 3:
		quit(0); return true

	# Posed by hand rather than waited for, so each picture is the moment it is meant to
	# show rather than whatever the bird happened to be doing.
	match _shots:
		0:
			_crow.set("_mood", 0)
			_crow.call("_fold", 1.0)
			_crow.call("_stand", 1.0)
			_crow.position = Vector4(0.0, 0.95, -7.0, 0.0)
		1:
			_crow.set("_mood", 2)
			_crow.set("_beat", 0.25)
			_crow.call("_flap", 0.95)
			_crow.call("_stand", 0.0)
			_crow.position = Vector4(0.0, 2.6, -7.0, 0.0)
		_:
			_crow.set("_beat", 0.75)
			_crow.call("_flap", 0.95)
			_crow.call("_stand", 0.0)
			_crow.position = Vector4(0.0, 2.6, -7.0, 0.0)
	_look(_crow.global_position, _crow.global_position + Vector4(1.15, 0.28, 1.15, 0.0))

	if _f % 16 != 0: return false
	_pending = ["00_perched", "01_wings_up", "02_wings_down"][_shots]
	_shots += 1
	return false
