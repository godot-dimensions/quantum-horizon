extends SceneTree
## Does the IK put the foot where it is asked? Feed it known targets and measure.
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 40: return false
	var gait: Node = _root.get_node("Player/Gait")
	var avatar: Node4D = _root.get_node("Player/Avatar")
	var hip: Node4D = avatar.hip_left
	var knee: Node4D = avatar.knee_left
	gait.set_physics_process(false)
	var foot_block: Node4D = null
	for c in knee.get_children():
		if c is MeshInstance4D and String(c.name).begins_with("Boot"): foot_block = c as Node4D
	print("thigh %.3f  shin %.3f  hip height %.3f" % [gait.get("_thigh"), gait.get("_shin"), gait.get("_hip_height")])
	for want_z in [0.0, 0.25, -0.25]:
		gait.call("_solve_leg", hip, knee, want_z, -0.45)
		# Where the foot actually ended up, relative to the hip, in the avatar's frame.
		var world_foot: Vector4 = foot_block.global_position
		var world_hip: Vector4 = hip.global_position
		var rel: Vector4 = world_foot - world_hip
		print("asked z %+.2f y -0.45  ->  got z %+.3f y %+.3f" % [want_z, rel.z, rel.y])
	return true
