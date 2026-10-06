extends SceneTree

## Does simply LOOKING AROUND change which slice you are in?
##
## It should not: yaw is an ordinary 3D turn and the slice should only move when you hold
## the W-drag. But the rig's basis is from_zx(yaw) * from_xw(xw) * from_zw(zw), and the
## slice normal is that basis's w column - so if yaw rotates the w column, turning your
## head silently re-cuts the world.
##
## Measured two ways, because either alone could mislead: the angle the slice normal
## sweeps through, and what that does to a real thing in the world - the w at which the
## slice crosses the pen's far corner.

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _sweep(player: Node4D, rig: Node4D, plane: Node, xw: float, zw: float, label: String) -> void:
	var first: Vector4 = Vector4.ZERO
	var worst_turn: float = 0.0
	var lo: float = 1.0e9
	var hi: float = -1.0e9
	for i in 9:
		var yaw: float = float(i) * TAU / 8.0
		SliceAngles.tilt(rig, xw, zw, yaw)
		var n: Vector4 = rig.global_basis.w
		if i == 0:
			first = n
		worst_turn = maxf(worst_turn, acos(clampf(n.dot(first), -1.0, 1.0)))
		var at_corner: float = float(plane.call("_w_above", 5.0, -15.5))
		lo = minf(lo, at_corner); hi = maxf(hi, at_corner)
	print("   %-28s normal swings %5.1f deg | slice at the pen's far corner: %+.2f to %+.2f"
		% [label, rad_to_deg(worst_turn), lo, hi])


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var plane: Node = _root.get_node("UI/SlicePlane")
	player.position = Vector4(0.0, 1.3, 0.0, 0.0)

	print("\n--- turning all the way round, at each slice rotation ---")
	_sweep(player, rig, plane, 0.0, 0.0, "no slice rotation")
	_sweep(player, rig, plane, 0.17, 0.0, "xw 10 deg")
	_sweep(player, rig, plane, 0.35, 0.0, "xw 20 deg")
	_sweep(player, rig, plane, 0.0, 0.35, "zw 20 deg")
	_sweep(player, rig, plane, 0.35, 0.35, "both 20 deg")
	quit(0)
	return true
