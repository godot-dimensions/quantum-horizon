extends SceneTree

## Looks at the two framings this session added: the spawn view, and the keeper two-shot.
##
## Run with --write-movie so the frames land as PNGs; the numbers printed alongside are
## there to explain a frame that looks wrong, not to replace looking at it.

var _scene: Node
var _f: int = 0


func _initialize() -> void:
	_scene = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _report(cam: Camera4D, what: String, at: Vector4) -> void:
	var fwd: Vector4 = -cam.global_basis.z
	var to: Vector4 = at - cam.global_position
	var a := Vector2(fwd.x, fwd.z).normalized()
	var b := Vector2(to.x, to.z).normalized()
	print("%s: camera at %.2f,%.2f,%.2f  %.1f m from the mark, %.1f deg off it" % [
		what, cam.global_position.x, cam.global_position.y, cam.global_position.z,
		Vector2(to.x, to.z).length(), rad_to_deg(absf(a.angle_to(b)))])


func _process(_d) -> bool:
	_f += 1
	var player: Node4D = _scene.get_node("Player")
	var pen: Node4D = _scene.get_node("Pen")
	var keeper: Node4D = _scene.get_node("World/KeeperPost/KeeperHead")
	if _f == 20:
		_report(_scene.get_node("Player/CameraRig/Pitch/Camera4D"), "SPAWN", pen.global_position)
	if _f == 60:
		# Walk up to him, looking at him, the way you would arrive on foot.
		var rig: Node4D = _scene.get_node("Player/CameraRig")
		player.global_position = Vector4(3.52, 1.2, -3.83, 0.0)
		rig.set("yaw", deg_to_rad(30.5))
		rig.call("_apply")
	if _f == 75:
		var driver: Node = _scene.get_node("Systems/TalkDriver")
		var talk: Node = _scene.get_node("Systems/Talk")
		driver.call("_before_begin")
		talk.call("begin", driver.call("_entry_node"))
		print("conversation open: %s" % str(talk.call("is_running")))
	if _f == 95:
		var staged: Camera4D = _scene.get_node("World/KeeperTalkCam")
		print("staged camera is the current one: %s" % str(staged.get("current")))
		_report(staged, "TWO-SHOT", keeper.global_position)
		print("  player is %.2f m from that camera" % (
			staged.global_position - player.global_position).length())
	return _f > 110
