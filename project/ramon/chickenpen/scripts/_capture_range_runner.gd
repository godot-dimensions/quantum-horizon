extends SceneTree

## The range booth by Trym's shed, from where people will see it: walking over from the
## spawn point, in front of it, at the counter looking down the range, and the same with
## the slice turned. Through the player's rig, like play. Windowed.
##
## Args (after --): tag=<name>   writes res://smoke_test_output/range_<tag>_<n>.png

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const SHOTS := [
	# [stand at (x, z, w), look at (x, y, z, w), pitch degrees, slice xw degrees, distance]
	[Vector3(-2.0, -3.0, 0.0), Vector4(-19.0, 1.5, -9.0, 0.0), 0.0, 0.0, 5.0],
	[Vector3(-12.5, -8.0, 0.0), Vector4(-19.0, 1.6, -9.0, 0.0), 4.0, 0.0, 4.0],
	[Vector3(-19.4, -9.3, 0.0), Vector4(-35.0, 1.4, -9.0, 0.0), 2.0, 0.0, 2.6],
	[Vector3(-19.4, -9.3, 0.0), Vector4(-35.0, 1.4, -9.0, 0.0), 2.0, 60.0, 2.6],
]

var _room: Node
var _f := 0
var _tag := "now"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.substr(4)
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _process(_d: float) -> bool:
	_f += 1
	var player := _room.get_node_or_null("Player") as CharacterBody4D
	var rig := _room.get_node_or_null("Player/CameraRig") as Node4D
	if _f < 20:
		return false
	var n: int = (_f - 20) / 45
	var phase: int = (_f - 20) % 45
	if n >= SHOTS.size():
		quit()
		return true
	var shot: Array = SHOTS[n]
	if phase == 0:
		_hide_hud(_room.get_node("UI"))
	if phase < 30:
		var at: Vector3 = shot[0]
		player.global_position = Vector4(at.x, 0.05, at.y, at.z)
		player.linear_velocity = Vector4.ZERO
		var d: Vector4 = (shot[1] as Vector4) - player.global_position
		rig.set("yaw", atan2(-d.x, -d.z))
		rig.set("pitch", deg_to_rad(shot[2]))
		SliceAngles.tilt(rig, deg_to_rad(shot[3]), 0.0)
		rig.set("distance", shot[4])
		rig.call("_apply")
	if phase == 40:
		var path: String = "res://smoke_test_output/range_%s_%d.png" % [_tag, n]
		root.get_texture().get_image().save_png(path)
		print("   saved %s" % path.get_file())
	return false


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem and not (child is WorldTag4D):
			(child as CanvasItem).visible = false
		_hide_hud(child)
