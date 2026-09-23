extends SceneTree
## The coop and the plank up to its doorway, from outside and from the side.
var _root: Node
var _f := 0
var _eye: Camera4D
var _shot := 0
const SHOTS := [
	[Vector4(0.0, 1.5, -9.0, 0.0), Vector4(0.0, 0.5, -14.1, 0.0), "coop_front"],
	[Vector4(5.0, 1.2, -12.0, 0.0), Vector4(0.0, 0.4, -13.4, 0.0), "coop_side"],
	[Vector4(0.0, 0.7, -11.6, 0.0), Vector4(0.0, 0.45, -14.1, 0.0), "coop_low"],
]
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _look(eye: Vector4, at: Vector4) -> void:
	var f: Vector4 = (at - eye).normalized()
	_eye.global_position = eye
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) * Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))
func _process(_d) -> bool:
	_f += 1
	if _f == 60:
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye); _eye.position = Vector4.ZERO; _eye.current = true
		var coop: Node4D = _root.get_node("Pen/Coop") as Node4D
		print("coop at %s  body %s  stilt %.2f  ramp %.2f  door %.2f x %.2f"
			% [coop.global_position, coop.get("body_size"), float(coop.get("stilt_height")),
				float(coop.get("ramp_length")), float(coop.get("door_width")),
				float(coop.get("door_height"))])
		for name_ in ["Ramp", "Lintel"]:
			var part: Node4D = coop.get_node_or_null(name_) as Node4D
			if part != null:
				print("  %-7s at %s  world %s  basis.z %s" % [name_, part.position,
					part.global_position, part.basis.z])
		return false
	if _f >= 100 and (_f - 100) % 14 == 0:
		if _shot > 0:
			root.get_texture().get_image().save_png("res://smoke_test_output/%s.png" % SHOTS[_shot - 1][2])
		if _shot >= SHOTS.size():
			print("done"); quit(); return true
		_look(SHOTS[_shot][0], SHOTS[_shot][1])
		_shot += 1
	return false
