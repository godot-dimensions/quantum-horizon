extends SceneTree

## The cave, through the pen's own crossing and the pen's own player, like play: arriving,
## halfway down the corridor, where it opens into the chamber, at the plinth, the same with
## the slice turned into W, looking back at the daylight, and the research site.
## Windowed. Positions are the cave's own (cave_rock_4d.gd), offset by where it hangs.
##
## Args (after --): tag=<name>   writes res://smoke_test_output/cave_<tag>_<n>.png
##                  only=N       just that shot
##                  strike=1     land a blow on the monolith before each shot, to see the
##                               researchers react
##                  hud=1        keep the HUD - for the dial (the last two shots are for it)

const SHOTS := [
	# [stand at (x, z, w) in the cave, yaw degrees, pitch, slice xw degrees, distance]
	[Vector3(0.0, -0.5, 0.0), 0.0, 2.0, 0.0, 4.0],
	[Vector3(0.0, -13.0, 0.0), 0.0, 4.0, 0.0, 4.0],
	[Vector3(0.0, -24.5, 0.0), 0.0, 10.0, 0.0, 4.5],
	[Vector3(0.6, -29.0, 0.0), 8.0, 8.0, 0.0, 3.5],
	[Vector3(0.0, -24.5, 0.0), 0.0, 10.0, 90.0, 4.5],
	[Vector3(0.0, -14.0, 0.0), 180.0, 2.0, 0.0, 4.0],
	[Vector3(9.5, -35.5, 0.0), 90.0, 6.0, 0.0, 5.0],
	[Vector3(0.0, -31.2, 0.0), 0.0, 18.0, 0.0, 3.0],
	[Vector3(0.0, -31.2, 0.0), 0.0, 18.0, 90.0, 3.0],
	# The way through W: toward the glowing sheet from beside the plinth with the slice
	# turned (both ways round, since which side it swings to depends on the turn), then
	# from inside the room at the end, looking back.
	[Vector3(0.0, -30.0, 5.5), 33.0, 6.0, 90.0, 3.5],
	[Vector3(0.0, -30.0, 5.5), -33.0, 6.0, 90.0, 3.5],
	[Vector3(0.0, -36.0, 16.0), 90.0, 6.0, 90.0, 3.0],
	[Vector3(0.0, -36.0, 16.0), -90.0, 6.0, 90.0, 3.0],
	# For the dial (hud=1): the way through W and the cube on it, on the slice you arrive
	# in and with the slice turned toward the way through.
	[Vector3(-2.0, -28.0, 0.0), 0.0, 8.0, 0.0, 4.0],
	[Vector3(-2.0, -28.0, 0.0), 0.0, 8.0, 60.0, 4.0],
]

var _room: Node
var _cave: Node4D
var _f := 0
var _tag := "now"
var _only := -1
var _strike := false
var _hud := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.substr(4)
		elif a.begins_with("only="):
			_only = int(a.substr(5))
		elif a == "strike=1":
			_strike = true
		elif a == "hud=1":
			_hud = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _process(_d: float) -> bool:
	_f += 1
	var player := _room.get_node_or_null("Player") as CharacterBody4D
	var rig := _room.get_node_or_null("Player/CameraRig") as Node4D
	if _f == 10:
		var crossing: Node = _room.get_node_or_null("CaveCrossing")
		if crossing == null:
			print("no CaveCrossing")
			quit(1)
			return true
		crossing.call("go")
	if _f == 12:
		for child in _room.get_children():
			if child.name == "Cave":
				_cave = child
		print("   in the cave: %s   player at %s" % [_cave != null, player.global_position])
		if not _hud:
			_hide_hud(_room.get_node("UI"))
	if _f < 30 or _cave == null:
		return false
	var n: int = (_f - 30) / 45
	var phase: int = (_f - 30) % 45
	if _only >= 0:
		if n > 0:
			quit()
			return true
		n = _only
	if n >= SHOTS.size():
		quit()
		return true
	var shot: Array = SHOTS[n]
	if phase < 30:
		var at: Vector3 = shot[0]
		player.global_position = _cave.global_position + _cave.global_basis * Vector4(at.x, 0.05, at.y, at.z)
		player.linear_velocity = Vector4.ZERO
		rig.set("yaw", deg_to_rad(shot[1]))
		rig.set("pitch", deg_to_rad(shot[2]))
		rig.set("_slice_xw", deg_to_rad(shot[3]))
		rig.set("distance", shot[4])
		rig.call("_apply")
	if phase == 20 and _strike:
		var slab: Node4D = _cave.get_node("Monolith")
		_room.get_node("Systems/Pickaxe").emit_signal("mined", slab.global_position + Vector4(0.0, -1.0, 0.7, 0.0), 0.55)
	if phase == 40:
		var path: String = "res://smoke_test_output/cave_%s_%d.png" % [_tag, n]
		root.get_texture().get_image().save_png(path)
		print("   saved %s" % path.get_file())
	return false


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_hud(child)
