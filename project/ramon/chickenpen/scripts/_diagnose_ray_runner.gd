extends SceneTree

## What does a 4D raycast actually give back? Printed whole, rather than guessed at.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	for spot in [Vector4(0.0, 2.0, 0.0, 0.0), Vector4(0.0, 2.0, 5.2, 0.0),
			Vector4(0.0, 2.0, 12.0, 0.0), Vector4(0.0, 4.0, 0.0, 0.0)]:
		var params := RaycastParameters4D.new()
		params.global_ray_origin = spot
		params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
		params.max_distance = 8.0
		var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
		print("from %v -> empty %s, keys %s" % [spot, str(hit.is_empty()), str(hit.keys())])
		if not hit.is_empty():
			for k in hit.keys():
				print("      %s = %s" % [str(k), str(hit[k])])
	quit()
	return true
