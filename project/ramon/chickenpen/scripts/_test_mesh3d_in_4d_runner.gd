extends SceneTree
## Can a plain 3D mesh be seen in a 4D scene? Build the smallest possible case: a 4D box
## that definitely renders, and a 3D box beside it, and look at what comes out.
var _f := 0
func _initialize() -> void:
	var root4d := Node4D.new()
	root.add_child(root4d)
	current_scene = root4d
	var env := WorldEnvironment4D.new()
	env.current = true
	root4d.add_child(env)
	var sun := DirectionalLight4D.new()
	root4d.add_child(sun)
	# A 4D box on the left - the control, which must appear.
	var m4 := MeshInstance4D.new()
	var box4 := BoxTetraMesh4D.new()
	box4.size = Vector4(1, 1, 1, 1)
	m4.mesh = box4
	m4.position = Vector4(-1.5, 0, 0, 0)
	root4d.add_child(m4)
	# A plain 3D box on the right - the question.
	var m3 := MeshInstance3D.new()
	var box3 := BoxMesh.new()
	box3.size = Vector3(1, 1, 1)
	m3.mesh = box3
	m3.position = Vector3(1.5, 0, 0)
	root4d.add_child(m3)
	var cam := Camera4D.new()
	cam.position = Vector4(0, 1.2, 6, 0)
	cam.basis = Basis4D.from_yz(-0.18)
	cam.current = true
	root4d.add_child(cam)
	print("scene built: MeshInstance4D at x=-1.5, MeshInstance3D at x=+1.5")
func _process(_d) -> bool:
	_f += 1
	if _f < 40: return false
	var img: Image = root.get_texture().get_image()
	img.save_png("res://smoke_test_output/mesh3d_in_4d.png")
	# Count non-background pixels either side of centre.
	var left := 0
	var right := 0
	for x in range(0, img.get_width()):
		for y in range(0, img.get_height(), 3):
			var c: Color = img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.75:
				if x < img.get_width() / 2: left += 1
				else: right += 1
	print("lit pixels - left half (4D box): %d, right half (3D box): %d" % [left, right])
	print("verdict: 3D mesh %s" % ("IS VISIBLE" if right > 200 else "does NOT render"))
	return true
