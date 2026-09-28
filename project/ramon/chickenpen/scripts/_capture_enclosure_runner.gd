extends SceneTree

## Trym's shed with the slice turned a quarter through W - the view that used to look
## straight out of the open end of the building - with the two W walls off and then on.
## Windowed. Writes res://smoke_test_output/enclosure_open.png and enclosure_closed.png

var _room: Node
var _f := 0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _process(_d: float) -> bool:
	_f += 1
	var shed := _room.get_node_or_null("World/Shed") as Node4D
	var player := _room.get_node_or_null("Player") as Node4D
	var rig := _room.get_node_or_null("Player/CameraRig") as Node4D
	if shed == null or player == null or rig == null:
		print("missing")
		quit()
		return true
	if _f == 20:
		shed.set("close_in_w", false)
		player.global_position = shed.global_position + Vector4(0.0, 0.0, 9.0, 0.0)
		rig.set("yaw", 0.0)
		rig.set("pitch", deg_to_rad(-6.0))
		rig.set("_slice_zw", 0.0)
		rig.set("_slice_xw", PI * 0.5)
		rig.call("_apply")
	if _f == 70:
		shed.set("close_in_w", true)
	if _f == 60 or _f == 110:
		var tag: String = "open" if _f == 60 else "closed"
		root.get_texture().get_image().save_png("res://smoke_test_output/enclosure_%s.png" % tag)
		print("   saved enclosure_%s.png" % tag)
	if _f > 110:
		quit()
		return true
	return false
