extends SceneTree
## One picture: the way out, seen from the chair, which is where somebody turning round
## to look for it is standing.
var _root: Node
var _f := 0
var _eye: Camera4D
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _look(eye: Vector4, at: Vector4) -> void:
	var f: Vector4 = (at - eye).normalized()
	_eye.global_position = eye
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) * Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))
func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		_root.get_node("Show").set("waits_for_seat", 0.0)
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye); _eye.position = Vector4.ZERO; _eye.current = true
		return false
	if _f == 90:
		var arch: Node4D = _root.get_node("ExitArch") as Node4D
		print("arch highlight %.2f, _lit %.2f, visible %s, at %s"
			% [float(arch.get("highlight")), float(arch.get("_lit")), arch.visible, arch.global_position])
		var field: Node = arch.get_node_or_null("Field")
		if field != null:
			var m: TetraMaterial4D = (field as MeshInstance4D).material_override as TetraMaterial4D
			print("  field visible %s colour %s" % [(field as Node4D).visible, m.albedo_color if m else "none"])
		else:
			print("  no Field child; children: %s" % [arch.get_children()])
		for part in arch.get_children():
			if part is MeshInstance4D and (part as MeshInstance4D).mesh is BoxTetraMesh4D:
				print("  %-8s at %s size %s" % [part.name, (part as Node4D).position,
					((part as MeshInstance4D).mesh as BoxTetraMesh4D).size])
			elif part is Node4D:
				print("  %-8s at %s (%d children)" % [part.name,
					(part as Node4D).position, part.get_child_count()])
				for sub in part.get_children():
					if sub is MeshInstance4D and (sub as MeshInstance4D).mesh is BoxTetraMesh4D:
						print("      %-8s at %s size %s" % [sub.name, (sub as Node4D).position,
							((sub as MeshInstance4D).mesh as BoxTetraMesh4D).size])
		# Close up, straight at it.
		_look(Vector4(0.0, 2.3, 13.6, 0.0), Vector4(0.0, 2.3, 18.6, 0.0))
		return false
	if _f == 95:
		root.get_texture().get_image().save_png("res://smoke_test_output/wayout.png")
		print("saved wayout.png"); quit(); return true
	return false
