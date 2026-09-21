extends SceneTree

## Once you stop rotating, does your slice stay put while you look around and walk?
##
## Two couplings, both of which made the game unplayable and neither of which was obvious
## from the code:
##
## LOOKING. The rig built from_zx(yaw) outermost, so yaw turned the slice normal too and
## a look-around re-cut the world.
##
## WALKING. Walking inside a tilted slice has a w component - your forward axis leans
## through W - and it shared the ana key's 30% throttle, so every step slid you out of
## your own slice.
##
## The test for both is the same: pick a fixed point in the world, and watch the w at
## which your slice crosses it. Nothing you do except a deliberate slice rotation or an
## ana/kata press should move that number.

var _root: Node
var _f := 0
var _fails: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-40s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var player: Node4D = _root.get_node("Player")
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var plane: Node = _root.get_node("UI/SlicePlane")

	print("\n--- looking around, with a slice rotation dialled in ---")
	for tilt in [[0.17, 0.0, "xw 10 deg"], [0.35, 0.0, "xw 20 deg"],
			[0.0, 0.35, "zw 20 deg"], [0.35, 0.35, "both 20 deg"]]:
		player.position = Vector4(0.0, 1.3, 0.0, 0.0)
		rig.set("_slice_xw", tilt[0]); rig.set("_slice_zw", tilt[1])
		var lo: float = 1.0e9
		var hi: float = -1.0e9
		for i in 17:
			rig.set("yaw", float(i) * TAU / 16.0)
			rig.call("_apply")
			var at: float = float(plane.call("_w_above", 5.0, -15.5))
			lo = minf(lo, at); hi = maxf(hi, at)
		_check("%s: a full turn moves nothing" % tilt[2], hi - lo < 0.001,
			"slice at the pen's far corner spans %.4f" % (hi - lo))

	print("\n--- walking, with a slice rotation dialled in ---")
	# Walk along the rig's own forward axis, which is what the movement code now does at
	# one speed in all four components.
	for tilt in [[0.35, 0.0, "xw 20 deg"], [0.35, 0.35, "both 20 deg"]]:
		player.position = Vector4(0.0, 1.3, 0.0, 0.0)
		rig.set("yaw", 0.6)
		rig.set("_slice_xw", tilt[0]); rig.set("_slice_zw", tilt[1])
		rig.call("_apply")
		var before: float = float(plane.call("_w_above", 5.0, -15.5))
		var forward: Vector4 = (rig.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
		player.position += forward * 6.0
		var after: float = float(plane.call("_w_above", 5.0, -15.5))
		_check("%s: six paces move nothing" % tilt[2], absf(after - before) < 0.001,
			"slice at the pen's far corner %+.3f -> %+.3f" % [before, after])
		# And the w the player is at really did change - they walked THROUGH w, which is
		# what staying in a tilted slice means.
		_check("%s: and you did travel through W" % tilt[2], absf(player.position.w) > 0.5,
			"player w is now %+.2f" % player.position.w)

	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
