extends SceneTree

## Does a bird that IS on your slice draw ON the plane?
##
## This is the one property the whole feature rests on, and it is easy to get silently
## wrong: the picture shrinks itself to stay on the panel, and if the birds' heights went
## through a different scaling from the plane's - or through none - the diagram would show
## them aligned when they are not, which is worse than not drawing them at all.
##
## So: put a bird exactly on the player's slice, and check its drawn head lands on the
## drawn surface. Then tilt hard enough to force the shrink, and check it again.

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


## Where the plane's drawn surface sits above (x, z), and where the bird's head is drawn -
## both in the same panel pixels, so they can simply be compared.
func _gap(plane: Node, bird: Node4D) -> Array:
	var pen: Rect2 = plane.call("_footprint")
	var corners: Array = [Vector2(pen.position.x, pen.position.y),
		Vector2(pen.end.x, pen.position.y), Vector2(pen.end.x, pen.end.y),
		Vector2(pen.position.x, pen.end.y)]
	var heights: Array = []
	for c in corners:
		heights.append(float(plane.call("_w_above", c.x, c.y)))
	var flock: Array = plane.call("_flock")
	var everything: Array = heights.duplicate()
	for b in flock:
		everything.append(b[2])
	var fitted: Array = plane.call("_fitted", everything)
	# The shrink the picture actually applied, read back rather than recomputed.
	var shrink: float = 1.0
	for i in heights.size():
		if absf(heights[i]) > 0.001:
			shrink = fitted[i] / heights[i]
			break
	var at: Vector4 = bird.global_position
	# Find this bird in the flock and take the height the panel draws it at.
	var drawn_head: float = NAN
	for i in flock.size():
		if absf(flock[i][0] - at.x) < 0.001 and absf(flock[i][1] - at.z) < 0.001:
			drawn_head = fitted[heights.size() + i]
			break
	var drawn_surface: float = float(plane.call("_w_above", at.x, at.z)) * shrink
	return [drawn_head, drawn_surface, shrink]


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var plane: Node = _root.get_node("UI/SlicePlane")
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var manager: Node = _root.get_node("Chickens")
	var bird: Node4D = (manager.get("agents")[0] as Node).get_parent() as Node4D

	print("\n--- a bird sitting exactly on the player's slice ---")
	for state in [[0.0, 0.0, 0.0, "unrotated"], [0.8, 0.25, 0.0, "tilted, w 0.8"],
			[0.0, 0.9, -0.7, "tilted hard both ways"]]:
		player.position = Vector4(0.0, 1.3, 0.0, state[0])
		SliceAngles.tilt(rig, state[1], state[2])
		# Put the bird on the slice, wherever the slice happens to be above it.
		var at: Vector4 = bird.global_position
		var on: float = float(plane.call("_w_above", at.x, at.z))
		bird.global_position = Vector4(at.x, at.y, at.z, on)
		var g: Array = _gap(plane, bird)
		var off: float = absf(g[0] - g[1])
		_check("%s: head lands on the plane" % state[3], off < 0.001,
			"head %+.3f vs surface %+.3f (shrink %.3f)" % [g[0], g[1], g[2]])

	print("\n--- and one a known distance off it ---")
	player.position = Vector4(0.0, 1.3, 0.0, 0.0)
	SliceAngles.tilt(rig, 0.0, 0.0)
	var at2: Vector4 = bird.global_position
	bird.global_position = Vector4(at2.x, at2.y, at2.z,
		float(plane.call("_w_above", at2.x, at2.z)) + 1.25)
	var g2: Array = _gap(plane, bird)
	_check("a bird 1.25 off draws 1.25 off", absf((g2[0] - g2[1]) - 1.25 * g2[2]) < 0.001,
		"drawn gap %+.3f against 1.25 x shrink %.3f" % [g2[0] - g2[1], g2[2]])

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
