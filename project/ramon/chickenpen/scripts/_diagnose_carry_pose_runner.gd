extends SceneTree

var _root: Node
var _f := 0
var _t0 := 0
var _stage := 0
var _sweep := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	var gait: Node = _root.get_node("Player/Gait")
	var catcher: Node = _root.get_node("Player/Catcher")
	var avatar: Node = _root.get_node("Player/Avatar")
	var mgr: Node = _root.get_node("Chickens")
	var player: Node4D = _root.get_node("Player")
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0

	match _stage:
		0:
			var bird: Node = (mgr.get("agents") as Array)[0]
			var body: Node4D = bird.get_parent() as Node4D
			player.position = body.global_position + Vector4(0.0, 1.3, 0.9, 0.0)
			player.position.w = body.global_position.w
			_stage = 1
			_t0 = Time.get_ticks_msec()
		1:
			if elapsed < 0.4:
				return false
			catcher.call("_catch", (mgr.get("agents") as Array)[0])
			_stage = 2
			_t0 = Time.get_ticks_msec()
		2:
			if elapsed < 1.5:
				return false
			print("blend %.2f, head top %.2f, shoulder rest y %.2f" % [
				gait.get("_carry_blend"), _top(avatar),
				(avatar.get("shoulder_left") as Node4D).global_position.y])
			print("sweeping the shoulder angle to find what actually raises the arm:")
			_sweep = 0
			_stage = 3
			_t0 = Time.get_ticks_msec()
		3:
			if elapsed < 0.12:
				return false
			if _sweep > 0:
				var used: float = float(_sweep - 1) * 0.4
				var sh: Node4D = avatar.get("shoulder_left") as Node4D
				print("   %5.2f rad -> arm top %.2f" % [used, _top(sh)])
			if _sweep > 16:
				return true
			gait.set("carry_arm_raise", float(_sweep) * 0.4)
			_sweep += 1
			_t0 = Time.get_ticks_msec()
	return false

func _top(node: Node) -> float:
	var hi := -INF
	for child in _all(node):
		var m: MeshInstance4D = child as MeshInstance4D
		if m == null or not (m.mesh is TetraMesh4D):
			continue
		for v in (m.mesh as TetraMesh4D).get_simplex_cell_positions():
			hi = maxf(hi, (m.global_basis * v + m.global_position).y)
	return hi


func _all(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out
