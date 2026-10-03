extends SceneTree

## Would composing the other way round decouple looking from slicing?
##
## The rig builds from_zx(yaw) * from_xw(xw) * from_zw(zw). The slice normal is that
## basis's w column, and yaw is applied OUTERMOST, so it rotates the normal along with
## everything else - which is why turning your head re-cuts the world.
##
## Swapped, the slice rotations sit outside and yaw inside. Yaw's own w column is
## (0,0,0,1) because from_zx only touches x and z, so the product's w column is the slice
## rotations' alone and cannot depend on yaw. Checked here rather than asserted.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _swing(build: Callable, xw: float, zw: float) -> float:
	var first: Vector4 = Vector4.ZERO
	var worst: float = 0.0
	for i in 9:
		var n: Vector4 = (build.call(float(i) * TAU / 8.0, xw, zw) as Projection).w
		if i == 0:
			first = n
		worst = maxf(worst, acos(clampf(n.dot(first), -1.0, 1.0)))
	return rad_to_deg(worst)


func _process(_d) -> bool:
	_f += 1
	if _f < 40: return false
	var now := func(yaw, xw, zw): return Basis4D.orthonormalized(
		Basis4D.from_zx(yaw) * Basis4D.from_xw(xw) * Basis4D.from_zw(zw))
	var swapped := func(yaw, xw, zw): return Basis4D.orthonormalized(
		Basis4D.from_xw(xw) * Basis4D.from_zw(zw) * Basis4D.from_zx(yaw))

	print("\n--- how far the slice normal swings over a full look-around ---")
	print("   %-16s %12s %12s" % ["slice rotation", "as built", "swapped"])
	for pair in [[0.0, 0.0, "none"], [0.17, 0.0, "xw 10"], [0.35, 0.0, "xw 20"],
			[0.0, 0.35, "zw 20"], [0.35, 0.35, "both 20"], [0.7, -0.5, "40 / -29"]]:
		print("   %-16s %9.1f deg %9.1f deg"
			% [pair[2], _swing(now, pair[0], pair[1]), _swing(swapped, pair[0], pair[1])])

	# And the thing that actually matters: does the camera still turn normally?
	print("\n--- does the view still yaw the same amount? ---")
	for yaw in [0.6, 1.8]:
		var a: Projection = swapped.call(yaw, 0.35, 0.35)
		var b: Projection = swapped.call(0.0, 0.35, 0.35)
		var turn: float = acos(clampf((a * Vector4(0,0,1,0)).normalized()
			.dot((b * Vector4(0,0,1,0)).normalized()), -1.0, 1.0))
		print("   asked for %.1f deg of yaw, the forward axis turned %.1f deg"
			% [rad_to_deg(yaw), rad_to_deg(turn)])
	quit(0)
	return true
