extends SceneTree

## A face parade: one frame each, camera a metre off the front of every head that has
## eyes now, so the four pairs can be compared side by side rather than described.

var _s: Node
var _f: int = 0
var _cam: Camera4D
var _who: Array[String] = ["World/Keeper", "World/Trym/Figure",
	"World/Professor/Figure", "Player/Avatar"]


func _initialize() -> void:
	_s = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_s)
	current_scene = _s
	var rig: Node = _s.get_node_or_null("Player/CameraRig") if _s != null else null
	if rig != null:
		rig.set("mouse_sensitivity", 0.0)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_s.add_child(_cam)


func _aim(head: Node4D) -> void:
	# +Z is the front of a block head, so stand off that face and look back at it.
	var front: Vector4 = head.global_basis.z.normalized()
	_cam.global_position = head.global_position + front * 0.85 + Vector4(0.0, 0.02, 0.0, 0.0)
	var gap: Vector4 = head.global_position - _cam.global_position
	var fwd: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -fwd
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc).normalized()
	var yc: Vector3 = zc.cross(xc)
	_cam.global_basis = Projection(
		Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0),
		Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))
	_cam.set("current", true)


func _process(_d) -> bool:
	_f += 1
	if _f < 30:
		return false
	var i: int = int((_f - 30) / 12)
	if i >= _who.size():
		return true
	if (_f - 30) % 12 != 0:
		return false
	var fig: Node4D = _s.get_node_or_null(_who[i]) as Node4D
	if fig == null:
		print("%-24s missing" % _who[i])
		return false
	var head: Node4D = fig.get_node_or_null("Tunic/Head") as Node4D
	if head == null:
		print("%-24s no head" % _who[i])
		return false
	_aim(head)
	print("frame %d: %s" % [_f, _who[i]])
	return false
