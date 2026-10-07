extends SceneTree

## THE CAMP'S RING (Ramon, 7 Oct: "the marker line around the campsite, is floating above ground"): what a ray
## straight down at the camp's middle, at the camp's W, hits first (the camp's own colliders, or the ground),
## and how high the path network laid the camp's ring (Frame12) and its circle (Node12) over the ground there.
##
##   lab_run.sh windowed wt_ring res://ramon/WTools/tests/_probe_camp_ring_runner.gd

const PEN := "res://ramon/chickenpen/playable_world.tscn"


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _down(at: Vector4, skip_camp: bool, camp: Node) -> Dictionary:
	var params := RaycastParameters4D.new()
	params.global_ray_origin = at + Vector4(0, 12, 0, 0)
	params.global_ray_direction = Vector4(0, -1, 0, 0)
	params.max_distance = 30.0
	var ex: Array[Node4D] = []
	if skip_camp:
		for b in camp.find_children("*", "StaticBody4D", true, false):
			ex.append(b as Node4D)
	params.set_exclude_nodes(ex)
	return PhysicsServer4D.raycast_physics_objects(params)


func _run() -> void:
	var pen: Node = (load(PEN) as PackedScene).instantiate()
	root.add_child(pen)
	current_scene = pen
	await _frames(200)
	(pen.get_node("Player") as Node4D).set("input_enabled", false)
	var camp := pen.get_node("World/EggCamp") as Node4D
	var net := pen.get_node("World/Paths") as Node4D
	var c: Vector4 = camp.global_position
	for skip in [false, true]:
		var hit: Dictionary = _down(c, skip, camp)
		var body: Object = hit.get("body")
		print("RING: down at the camp's middle (w %.2f)%s: hits %s at y %.3f" % [c.w, " looking through the camp" if skip else "",
			str(pen.get_path_to(body as Node)) if body is Node else "nothing", (hit.get("global_point", Vector4.ZERO) as Vector4).y])
	for nm in ["Frame12", "Node12", "Pad12"]:
		var mi := net.get_node_or_null(nm) as Node4D
		if mi == null:
			print("RING: %s not laid" % nm)
			continue
		var g: Dictionary = _down(mi.global_position, true, camp)
		var gy: float = (g.get("global_point", Vector4(0, NAN, 0, 0)) as Vector4).y
		print("RING: %s at y %.3f w %.2f, the ground under it at y %.3f: %.3f above" % [nm, mi.global_position.y, mi.global_position.w, gy, mi.global_position.y - gy])
	quit(0)
