extends SceneTree

## The CHICKENS sign through the player's own camera, first on the home slice and then with
## the rig's slice turned 180 degrees through W - the exact thing right-drag does in play.
## The second picture should read backwards: chirality, made visible.
##
## THROUGH THE RIG, NOT A TEST CAMERA. Rotating a bare Camera4D by half a turn in its own
## x-w plane changed nothing on screen - observed, not explained; why was not looked into -
## whereas turning the rig's slice, which rotates the frame the camera hangs off, flips the
## picture exactly as play does. That is the path worth checking, so it is the one used.
## Windowed. Writes res://smoke_test_output/sign_flip_0.png and sign_flip_180.png

var _room: Node
var _f := 0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _process(_d: float) -> bool:
	_f += 1
	var sign := _room.get_node_or_null("World/PenSign") as Node4D
	var player := _room.get_node_or_null("Player") as Node4D
	var rig := _room.get_node_or_null("Player/CameraRig") as Node4D
	if sign == null or player == null or rig == null:
		print("missing sign, player or rig")
		quit()
		return true
	if _f == 20:
		# Stand three metres in front of the sign, facing it.
		var face: Vector4 = sign.global_basis.z.normalized()
		player.global_position = sign.global_position + face * 3.0
		var back: Vector4 = -face
		rig.set("yaw", atan2(-back.x, -back.z))
		rig.set("pitch", deg_to_rad(-4.0))
		rig.call("_apply")
	if _f == 70:
		rig.set("_slice_xw", PI)
		rig.call("_apply")
	if _f == 60 or _f == 110:
		var tag: String = "0" if _f == 60 else "180"
		root.get_texture().get_image().save_png("res://smoke_test_output/sign_flip_%s.png" % tag)
		print("   saved sign_flip_%s.png   slice xw %.2f" % [tag, float(rig.get("_slice_xw"))])
	if _f > 110:
		quit()
		return true
	return false
