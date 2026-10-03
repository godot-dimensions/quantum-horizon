extends SceneTree

## Are the chickens actually SURROUNDING the pen, or just spread out on one side of it?
##
## Measured from where they really spawn rather than from the table, and reported as
## bearings from the pen's centre with the gaps between them - an even ring shows as
## twelve roughly equal gaps, a fan shows as one enormous one. Also photographs the field
## from directly overhead, because a list of angles is not something you can look at.

const _DIR: String = "res://smoke_test_output/"
var _scene: Node
var _f: int = 0


func _initialize() -> void:
	_scene = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene
	var cam := Camera4D.new()
	cam.rendering_engine_name = "Cross-section"
	cam.focal_length_3d = 1.1
	cam.w_fade_distance = 40.0
	# Straight down over the pen. Looking along -Y, so the basis is built by hand: a
	# look-at helper that assumes a world up cannot aim at the floor.
	cam.position = Vector4(0.0, 44.0, -11.0, 0.0)
	cam.basis = Projection(
		Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
	_scene.add_child(cam)
	cam.current = true


func _process(_d) -> bool:
	_f += 1
	if _f < 50:
		return false
	var pen: Node4D = _scene.get_node("Pen")
	var flock: Node = _scene.get_node("Chickens")
	var rows: Array = []
	# BY NAME, not by "every child". Something else parents anonymous MeshInstance4D nodes
	# under this one - twelve of them, all at the origin - and counting those reported
	# twenty-four birds with half the ring collapsed onto one bearing.
	for bird in flock.get_children():
		if not String(bird.name).begins_with("Chicken"):
			continue
		var gap: Vector4 = (bird as Node4D).global_position - pen.global_position
		rows.append([rad_to_deg(atan2(gap.x, gap.z)), Vector2(gap.x, gap.z).length(), gap.w])
	rows.sort_custom(func(a, b): return a[0] < b[0])
	print("birds: %d" % rows.size())
	var previous: float = float(rows[rows.size() - 1][0]) - 360.0
	var worst: float = 0.0
	for row in rows:
		var gap_deg: float = float(row[0]) - previous
		worst = maxf(worst, gap_deg)
		previous = float(row[0])
		print("  bearing %+7.0f   dist %5.1f   w %+5.1f   gap to previous %5.0f" % [
			row[0], row[1], row[2], gap_deg])
	var even: float = 360.0 / maxf(float(rows.size()), 1.0)
	print("LARGEST EMPTY ARC: %.0f degrees (an even ring of %d is %.0f; a fan is over 200)" % [
		worst, rows.size(), even])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_DIR))
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(_DIR + "flock_ring.png")
		print("SAVED flock_ring")
	return true
