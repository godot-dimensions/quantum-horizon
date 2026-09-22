extends SceneTree

## The professor beside his rock.

var _root: Node
var _f := 0
var _pending := false
var _eye: Camera4D


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 90: return false
	if _pending:
		root.get_texture().get_image().save_png("res://smoke_test_output/professor.png")
		print("saved professor.png")
		quit(0); return true
	var prof: Node4D = _root.get_node("World/Professor")
	_root.get_node("Player").global_position = Vector4(40.0, 1.3, 40.0, 0.0)
	_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
	_root.add_child(_eye); _eye.position = Vector4.ZERO; _eye.current = true
	var at: Vector4 = prof.global_position + Vector4(0.0, 0.85, 0.0, 0.0)
	# From the open side. The rock is to his east, and a camera put there is inside it.
	var from: Vector4 = at + Vector4(-2.2, 0.5, 2.4, 0.0)
	var f: Vector4 = (at - from).normalized()
	_eye.global_position = from
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) \
		* Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))
	_pending = true
	return false
