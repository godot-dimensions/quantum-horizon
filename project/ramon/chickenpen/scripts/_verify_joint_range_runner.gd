extends SceneTree
## How much do the knees and shoulders actually move while walking?
var _root: Node
var _f := 0
var _avatar: Node4D
var _klo := 9.0
var _khi := -9.0
var _slo := 9.0
var _shi := -9.0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _angle(n: Node4D) -> float:
	return atan2(n.basis.z.y, n.basis.z.z)


## The real knee bend: the angle between thigh and shin in world space, where 0 is a
## straight leg. Reading it off a basis depends on a rotation convention; this does not.
func _knee_bend(gait: Node) -> float:
	var hip: Node4D = _avatar.hip_left
	var knee: Node4D = _avatar.knee_left
	var shin: float = float(gait.get("_shin"))
	var ankle: Vector4 = knee.global_position + knee.global_basis * Vector4(0.0, -shin, 0.0, 0.0)
	var thigh_dir: Vector4 = (knee.global_position - hip.global_position).normalized()
	var shin_dir: Vector4 = (ankle - knee.global_position).normalized()
	return acos(clampf(thigh_dir.dot(shin_dir), -1.0, 1.0))
func _process(_d) -> bool:
	_f += 1
	if _f == 60:
		_avatar = _root.get_node("Player/Avatar")
		return false
	if _f < 60: return false
	Input.action_press(&"move_back")
	if _f > 110:
		var k: float = _knee_bend(_root.get_node("Player/Gait"))
		var s: float = _angle(_avatar.shoulder_left)
		_klo = minf(_klo, k); _khi = maxf(_khi, k)
		_slo = minf(_slo, s); _shi = maxf(_shi, s)
	if _f < 400: return false
	Input.action_release(&"move_back")
	print("knee bend (0 = straight): %.0f deg .. %.0f deg  (range %.0f)" % [rad_to_deg(_klo), rad_to_deg(_khi), rad_to_deg(_khi - _klo)])
	print("shoulder swing: %.0f deg .. %.0f deg  (range %.0f)" % [rad_to_deg(_slo), rad_to_deg(_shi), rad_to_deg(_shi - _slo)])
	return true
