extends SceneTree

## Pen layout, Phase C0 (6 Oct 2026): which way the camera faces after coming home from the cave,
## frame by frame, and what turned it. Walks in by the hill's way in, out by the cave's exit arch,
## and prints the rig's yaw for 60 frames from the moment the crossing puts you down.
##
##   CreationLab/scripts/lab_run.sh windowed pl_probe_yaw res://ramon/PenLayout/scripts/_probe_return_yaw_runner.gd [scene]

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")

var _room: Node


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://ramon/chickenpen/playable_world.tscn"
	_room = (load(scene) as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	await _frames(30)
	var player := _room.get_node("Player") as CharacterBody4D
	var rig := player.get_node("CameraRig") as Node4D
	var crossing: Node = _room.get_node("CaveCrossing")
	var hill: Node4D = CaveHill.node_in(_room)
	var way: Vector4 = (CaveHill.new().way_in() as Array)[0]
	for i in 30:
		player.global_position = CaveHill.to_world(hill, way - Vector4(0.0, 1.2, 0.0, 0.0))
		player.linear_velocity = Vector4.ZERO
		await physics_frame
		if bool(crossing.call("is_away")):
			break
	print("in the cave: %s, yaw %.2f" % [crossing.call("is_away"), float(rig.get("yaw"))])
	await _frames(20)
	var cave: Node4D = crossing.get("_theatre") as Node4D
	var exit: Node4D = cave.get_node("ExitArch") if cave != null else null
	if exit == null:
		print("PROBE: no exit arch")
		quit(1)
		return
	var hz: Vector4 = hill.global_basis.z
	print("hill heading %.2f, expected yaw out of the hill %.2f" % [atan2(hz.x, hz.z), wrapf(PI + atan2(hz.x, hz.z), -PI, PI)])
	var back_at: int = -1
	for f in 200:
		if back_at < 0:
			player.global_position = exit.global_position + Vector4(0.0, 0.05, -0.6, 0.0)
			player.linear_velocity = Vector4.ZERO
		await physics_frame
		if back_at < 0 and not bool(crossing.call("is_away")):
			back_at = f
		if back_at >= 0 and (f - back_at < 12 or (f - back_at) % 10 == 0):
			print("  frame +%d: yaw %.2f, tilt %.2f, at %s" % [f - back_at, float(rig.get("yaw")), GroundBasis4D.tilt(rig.basis), str(player.global_position)])
		if back_at >= 0 and f - back_at > 60:
			break
	print("PROBE DONE")
	quit(0)
