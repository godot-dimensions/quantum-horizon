extends SceneTree
## The chicken from its own RIGHT and from the front, to confirm the orientation mark
## sits on the right wing and the feet read as feet.
var _root: Node
var _f := 0
var _shot := 0
var _cam: Camera4D
func _initialize() -> void:
	var holder := Node4D.new()
	root.add_child(holder); current_scene = holder
	var env := WorldEnvironment4D.new(); env.current = true
	env.sky_material = GradientSkyMaterial4D.new()
	holder.add_child(env)
	var sun := DirectionalLight4D.new(); holder.add_child(sun)
	_root = load("res://ramon/chickenpen/chicken.tscn").instantiate()
	holder.add_child(_root)
	_cam = Camera4D.new(); _cam.current = true
	_cam.rendering_engine_name = "Cross-section"
	holder.add_child(_cam)
func _process(_d) -> bool:
	_f += 1
	# The chicken faces +Z, so its right is -X: view 0 looks at that side.
	var eye := Vector4(-0.75, 0.42, 0.22, 0.0) if _shot == 0 else Vector4(0.28, 0.12, 0.45, 0.0)
	_cam.position = eye
	_cam.basis = Basis4D.looking_at((Vector4(0.0, 0.26, 0.0, 0.0) if _shot == 0 else Vector4(0.0, 0.06, 0.03, 0.0)) - eye)
	if _f < 30 + _shot * 25: return false
	root.get_texture().get_image().save_png("res://smoke_test_output/chicken_%s.png" % ("right" if _shot == 0 else "front"))
	print("SAVED %s" % ("right" if _shot == 0 else "front"))
	_shot += 1
	return _shot > 1
