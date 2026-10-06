extends SceneTree

## Where does the player's slice sit, in world w, over the pen's footprint?
##
## Derived from the rig's own basis rather than from sin/cos of the two slice angles,
## because the composition order of from_xw and from_zw is one more thing to get wrong.
## A point Q is on the slice when (Q - P) dot W == 0, so the w the slice sits at over a
## given (x, z) falls straight out of that. This checks the answer behaves: flat at zero
## when unrotated, tilting one way for xw and the other for zw.

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


## The world w at which the slice crosses the vertical line through (x, z).
func _w_at(player: Node4D, rig: Node4D, x: float, z: float, y: float) -> float:
	var p: Vector4 = player.global_position
	var n: Vector4 = rig.global_basis.w
	if absf(n.w) < 0.02:
		return NAN
	return p.w - ((x - p.x) * n.x + (y - p.y) * n.y + (z - p.z) * n.z) / n.w


func _corners(player: Node4D, rig: Node4D, label: String) -> void:
	var out: Array = []
	for c in [[-5.0, -15.5], [5.0, -15.5], [5.0, -6.5], [-5.0, -6.5]]:
		out.append("%+.2f" % _w_at(player, rig, c[0], c[1], 0.0))
	print("   %-26s corners at w %s" % [label, out])


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	player.position = Vector4(0.0, 1.3, 0.0, 0.0)

	print("\n--- the slice, as w over the pen's four corners ---")
	print("   (-5,-15.5) (5,-15.5) (5,-6.5) (-5,-6.5)")
	SliceAngles.tilt(rig, 0.0, 0.0)
	_corners(player, rig, "home")
	player.position = Vector4(0.0, 1.3, 0.0, 1.5)
	_corners(player, rig, "stepped ana 1.5")
	player.position = Vector4(0.0, 1.3, 0.0, 0.0)
	SliceAngles.tilt(rig, 0.35, 0.0)
	_corners(player, rig, "xw 20 deg")
	SliceAngles.tilt(rig, 0.0, 0.35)
	_corners(player, rig, "zw 20 deg")
	SliceAngles.tilt(rig, 0.35, 0.35)
	_corners(player, rig, "both 20 deg")
	quit(0)
	return true
