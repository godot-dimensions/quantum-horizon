extends SceneTree

## A flat baked patch alone under one light, to see whether the triangle pattern on the
## cave mouth's floor comes from the patch itself or from what is around it.
## Windowed. Writes res://smoke_test_output/flat_patch_<variant>.png for:
##   five - the five-way cell split, one colour
##   six  - the six-way split, one colour
##   ramp - the six-way split, with a colour ramp along z

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

var _f := 0
var _variants := ["five", "six", "ramp"]
var _mesh: MeshInstance4D


func _initialize() -> void:
	var scene := Node4D.new()
	root.add_child(scene)
	var env := WorldEnvironment4D.new()
	env.set("current", true)
	scene.add_child(env)
	var sun := DirectionalLight4D.new()
	sun.basis = Basis4D.from_yz(-0.25)
	scene.add_child(sun)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	scene.add_child(cam)
	cam.current = true
	cam.position = Vector4(0.0, 1.6, 3.0, 0.0)
	cam.basis = Basis4D.from_yz(-0.35)
	_mesh = MeshInstance4D.new()
	scene.add_child(_mesh)


func _build(variant: String) -> void:
	var flat := func(_x: float, _z: float, _w: float) -> float: return 0.0
	var grey := func(_p: Vector4, _n: Vector4, _r: float) -> Color: return Color(0.4, 0.4, 0.42)
	var ramp := func(p: Vector4, _n: Vector4, _r: float) -> Color: return Color(0.4, 0.4, 0.42).lerp(Color.BLACK, smoothstep(1.0, -6.0, p.z))
	var b: TerrainBake.Builder = TerrainBake.bake_height_box(Vector3(-3.0, -8.0, -1.7), Vector3(3.0, 2.0, 1.9), 0.6,
		flat, ramp if variant == "ramp" else grey, [], -INF, variant != "five")
	_mesh.mesh = TerrainBake.mesh_of(b)


func _process(_d: float) -> bool:
	_f += 1
	var n: int = (_f - 5) / 30
	if _f < 5:
		return false
	if n >= _variants.size():
		quit()
		return true
	if (_f - 5) % 30 == 0:
		_build(_variants[n])
	if (_f - 5) % 30 == 25:
		root.get_texture().get_image().save_png("res://smoke_test_output/flat_patch_%s.png" % _variants[n])
	return false
