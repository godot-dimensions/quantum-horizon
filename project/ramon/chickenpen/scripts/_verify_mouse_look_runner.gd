extends SceneTree

## Push the mouse right: does the view turn right?
##
## Worth a runner rather than a guess. The rig's camera sits at +Z of a from_zx(yaw)
## frame and looks BACK at the player, so the view direction is the negative of the arm -
## which is exactly the kind of double negative this project has got backwards before.
## Measured by where the camera ends up and which way it ends up looking, not by reading
## the sign off the line that was changed.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _push(rig: Node, dx: float) -> void:
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(dx, 0.0)
	rig.call("_unhandled_input", move)


func _process(_d) -> bool:
	_f += 1
	if _f < 50: return false
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var camera: Node4D = _root.get_node("Player/CameraRig/Pitch/Camera4D")
	# The rig ignores motion unless the mouse is captured, and headless Godot will not
	# capture a mouse it has no window for - so this one has to run windowed.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("   (mouse could not be captured - run this windowed, not headless)")
		quit(2)
		return true

	rig.set("yaw", 0.0)
	rig.call("_apply")
	var before_arm: Vector4 = camera.global_position - rig.global_position
	# The camera looks along its own -Z. Flat, because pitch is not the question here.
	var before_view: Vector4 = -(camera.global_basis * Vector4(0.0, 0.0, 1.0, 0.0))
	var before: float = atan2(before_view.x, before_view.z)

	# A firm shove to the right.
	_push(rig, 40.0)
	var after_arm: Vector4 = camera.global_position - rig.global_position
	var after_view: Vector4 = -(camera.global_basis * Vector4(0.0, 0.0, 1.0, 0.0))
	var after: float = atan2(after_view.x, after_view.z)

	var turned: float = wrapf(after - before, -PI, PI)
	print("\n--- mouse pushed right ---")
	print("   view bearing %+.3f -> %+.3f rad, a turn of %+.3f" % [before, after, turned])
	print("   camera arm x %+.2f -> %+.2f  (it should swing towards +X)"
		% [before_arm.x, after_arm.x])
	# Facing -Z, turning towards -X is turning to your right, and that is a POSITIVE
	# change in the atan2(x, z) bearing the whole scene measures headings with.
	var ok: bool = turned > 0.05
	print("\n   %s the view turns RIGHT when the mouse goes right"
		% ["PASS" if ok else "FAIL"])
	print("\n%d FAIL(s)" % (0 if ok else 1))
	quit(0 if ok else 1)
	return true
