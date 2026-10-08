extends SceneTree

## Does the ring on the walkway actually do anything, and does stepping off undo it?
##
##   godot --path project --rendering-method forward_plus --resolution 640x400 \
##       --script res://sandbox/water4d/_probe_rotation_point_runner.gd
##
## Two failures to rule out, and neither shows in a screenshot. The ring test is written in
## the ROOM's frame while the player's position is in the WORLD's - identical while the room
## sat at the origin, 36 m apart now - so the first check is simply whether standing on the
## painted ring registers at all. The second is the reset: a slice left turned after walking
## away is a slice the player has to undo by hand.

const RING_WORLD := Vector4(36.0, 0.05, 10.5, 0.0)
const AWAY_WORLD := Vector4(0.0, 0.05, 30.0, 0.0)

var _frames: int = 0
var _root: Node = null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load("res://ramon/Arboretum/arboretum.tscn") as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	if _frames < 8:
		return false

	var ok := true
	var annex: Node4D = _root.get_node_or_null(^"WaterAnnex") as Node4D
	var point: Node = _root.get_node_or_null(^"WaterAnnex/RotationPoint")
	var player: Node4D = _root.get(&"player") as Node4D
	if annex == null or point == null or player == null:
		print("  FAIL - missing WaterAnnex, RotationPoint or player")
		quit(1)
		return true
	var rig: Node = player.get_node_or_null(^"CameraRig")
	if rig == null:
		print("  FAIL - the player has no CameraRig")
		quit(1)
		return true

	# THE FLAG IS THE WHOLE MECHANISM. The rig owns slice turning and rebuilds its basis every
	# frame; the gallery switches the flag off at startup. So what has to be checked is the
	# flag, not any rotation this node performs - the previous probe checked the arithmetic of
	# a turn that the rig was overwriting before it ever reached the screen.
	var gallery_default: bool = bool(rig.get(&"slice_turning"))
	print("  gallery's own setting: slice_turning = %s" % gallery_default)
	if gallery_default:
		print("  NOTE - the gallery is not disabling slice turning; the ring has nothing to lend")

	# --- standing on the ring ------------------------------------------------------------
	player.global_position = RING_WORLD
	var here: Vector4 = annex.global_to_local(player.global_position)
	print("  on the ring at %s -> room-local %s -> %s"
			% [RING_WORLD, here, annex.call(&"is_on_rotation_point", here)])
	point.call(&"_process", 1.0 / 60.0)
	var on_ring_flag: bool = bool(rig.get(&"slice_turning"))
	print("  standing on it:  slice_turning = %s" % on_ring_flag)
	if not on_ring_flag:
		print("  FAIL - the ring does not enable 4D rotation")
		ok = false

	# --- stepping off ----------------------------------------------------------------------
	# Leave the slice turned, so the reset has something to undo.
	rig.set(&"_slice_xw", 0.4)
	player.global_position = AWAY_WORLD
	point.call(&"_process", 1.0 / 60.0)
	var off_flag: bool = bool(rig.get(&"slice_turning"))
	var homing: float = float(rig.get(&"_homing"))
	print("  after stepping off: slice_turning = %s, homing for %.2f s" % [off_flag, homing])
	if off_flag != gallery_default:
		print("  FAIL - stepping off did not put slice_turning back to the gallery's setting")
		ok = false
	if homing <= 0.0:
		print("  FAIL - stepping off did not send the slice home")
		ok = false

	print("")
	print("  %s" % ("PASS - the ring turns the slice, and stepping off resets it." if ok else "see above."))
	quit(0 if ok else 1)
	return true
