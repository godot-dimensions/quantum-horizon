extends SceneTree

## R: does it put you back on the default slice, and does the arrow point where you walk?
##
## THE ARROW IS CHECKED AGAINST THE MOVEMENT, not against an opinion about which way +Z
## points. The walker reads Input.get_axis("move_forward", "move_back"), which returns
## MINUS one for forward, and runs it through the rig's basis - so the direction a press
## of W sends you is movement_basis * (0, 0, -1, 0), and the arrow has to match that
## exact expression. Drawn from +Z it pointed exactly backwards.

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")

var _root: Node
var _f := 0
var _step := 0
var _fails: Array = []
var _from: float = 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-36s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _press_r() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	_root.get_node("Player/CameraRig").call("_unhandled_input", key)


func _process(d) -> bool:
	_f += 1
	if _f < 60: return false
	var rig: Node4D = _root.get_node("Player/CameraRig")
	var player: Node4D = _root.get_node("Player")

	match _step:
		0:
			print("\n--- the arrow against the way W actually sends you ---")
			for yaw in [0.0, 0.9, 2.4, -1.7]:
				SliceAngles.tilt(rig, 0.3, -0.2, yaw)
				# What the walker computes for a press of forward.
				var walks: Vector4 = (rig.call("movement_basis") * Vector4(0.0, 0.0, -1.0, 0.0)).normalized()
				# What the dial draws the arrow along.
				var points: Vector4 = (rig.global_basis * Vector4(0.0, 0.0, -1.0, 0.0)).normalized()
				var off: float = rad_to_deg(acos(clampf(walks.dot(points), -1.0, 1.0)))
				_check("yaw %+.1f: arrow matches the walk" % yaw, off < 0.5,
					"%.2f degrees apart" % off)
			print("\n--- R, from a badly lost slice ---")
			player.position = Vector4(0.0, 1.3, 0.0, 2.7)
			SliceAngles.tilt(rig, 0.85, -0.62)
			_from = absf(rig.global_basis.w.x) + absf(rig.global_basis.w.z)
			var was: Vector3 = SliceAngles.angles(rig.basis)
			print("   before: w %+.2f, xw %+.2f, zw %+.2f" % [player.position.w, was.x, was.y])
			_press_r()
		1:
			# Part way through, it should be on its way rather than already there.
			var mid: Vector3 = SliceAngles.angles(rig.basis)
			_check("it eases rather than snapping", absf(mid.x) > 0.001, "xw is %+.3f a frame in" % mid.x)
		_:
			if _f < 120: return false
			var now: Vector3 = SliceAngles.angles(rig.basis)
			print("   after:  w %+.3f, xw %+.3f, zw %+.3f" % [player.position.w, now.x, now.y])
			_check("both rotations are zero", absf(now.x) < 0.001 and absf(now.y) < 0.001,
				"xw %+.4f zw %+.4f" % [now.x, now.y])
			_check("and you are back at w zero", absf(player.position.w) < 0.01,
				"w %+.4f, from +2.70" % player.position.w)
			var n: Vector4 = rig.global_basis.w
			_check("the slice normal is the default one",
				absf(n.x) < 0.001 and absf(n.z) < 0.001 and n.w > 0.999,
				"normal is (%.3f, %.3f, %.3f, %.3f)" % [n.x, n.y, n.z, n.w])
			print("\n%d FAIL(s)" % _fails.size())
			quit(1 if _fails.size() > 0 else 0)
			return true
	_step += 1
	return false
