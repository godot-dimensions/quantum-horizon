extends SceneTree

## How much of what you see is the directional light, and how much is ambient?
##
## Renders the same frame twice - once as authored, once with the sun's energy at zero -
## and reports the mean per-channel difference. That is the sun's actual contribution to
## the image, which is a different question from whether a light node exists. At three
## degrees of elevation a directional light delivers about a twentieth of itself to a flat
## floor, so "there is a sun" and "the sun is lighting anything" can easily disagree.

var _sun: Node
var _camera: Camera4D
var _f: int = 0
var _lit: Image
var _energy: float = 0.0


func _initialize() -> void:
	var scene: Node = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	_sun = scene.get_node("World/Sun")
	_energy = float(_sun.get("light_energy"))
	var clouds: Resource = scene.get_node("World/Environment").get("cloud_material")
	if clouds != null:
		clouds.set("animation_enabled", false)
		clouds.set("evolution_speed", 0.0)
		clouds.set("wind_velocity", Vector4.ZERO)
	_camera = Camera4D.new()
	_camera.rendering_engine_name = "Cross-section"
	_camera.focal_length_3d = 2.2
	# The with-the-sun angle, where a directional light has the best chance of showing.
	var from := Vector4(13.0, 2.8, -20.0, 0.0)
	var to := Vector4(-1.0, 1.2, -6.0, 0.0)
	var gap: Vector4 = to - from
	var fwd: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -fwd
	var xc: Vector3 = Vector3(0, 1, 0).cross(zc).normalized()
	var yc: Vector3 = zc.cross(xc)
	_camera.position = from
	_camera.basis = Projection(
		Vector4(xc.x, xc.y, xc.z, 0), Vector4(yc.x, yc.y, yc.z, 0),
		Vector4(zc.x, zc.y, zc.z, 0), Vector4(0, 0, 0, 1))
	scene.add_child(_camera)
	_camera.current = true
	print("authored light_energy: %.2f" % _energy)


func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		_lit = root.get_texture().get_image()
		_sun.set("light_energy", 0.0)
		return false
	if _f < 70:
		return false
	var dark: Image = root.get_texture().get_image()
	if _lit == null or dark == null:
		print("FAILED: no framebuffer")
		return true
	var total: float = 0.0
	var peak: float = 0.0
	var counted: int = 0
	# Sampled on a grid, and only below the horizon line - the sky is drawn by the sky
	# material and does not care about the light node either way, so including it would
	# dilute the answer with pixels that could never change.
	for y in range(int(_lit.get_height() * 0.5), _lit.get_height(), 4):
		for x in range(0, _lit.get_width(), 4):
			var a: Color = _lit.get_pixel(x, y)
			var b: Color = dark.get_pixel(x, y)
			var d: float = (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			total += d
			peak = maxf(peak, d)
			counted += 1
	print("GROUND-HALF PIXELS sampled: %d" % counted)
	print("MEAN change when the sun is switched off: %.4f  (0 = the sun does nothing)" % (total / maxf(float(counted), 1.0)))
	print("PEAK change on any sampled pixel: %.4f" % peak)
	return true
