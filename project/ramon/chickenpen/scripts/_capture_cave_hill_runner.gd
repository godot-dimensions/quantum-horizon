extends SceneTree

## The hill with the hole, from where people will see it: the spawn point, walking up to
## the mouth, looking into the bore, the same with the slice turned through W, and with
## the slice turned from further off. Through the player's rig, like play. Windowed.
##
## Args (after --): tag=<name>  writes res://smoke_test_output/cave_hill_<tag>_<n>.png
##                  hide=A,B    hide these nodes first (paths from the scene root)
##                  only=N      take shot N alone
##                  unlit=A,B   set these lights' energy to 0 (paths from the scene root)
##                  ambient0=1  no ambient light and no sky in it

const SHOTS := [
	# [stand at (x, z, w), look at (x, y, z, w), pitch degrees, slice xw degrees, distance]
	[Vector3(16.5, -21.0, 0.0), Vector4(16.5, 2.5, -30.0, 0.0), 4.0, 0.0, 4.0],
	[Vector3(9.0, -22.5, 0.0), Vector4(16.5, 1.5, -29.0, 0.0), 2.0, 0.0, 4.0],
	[Vector3(24.0, -22.5, 0.0), Vector4(16.5, 1.5, -29.0, 0.0), 2.0, 0.0, 4.0],
	[Vector3(16.5, -29.8, 0.0), Vector4(16.5, 1.6, -40.0, 0.0), 0.0, 0.0, 3.0],
	[Vector3(4.6, -2.0, 0.0), Vector4(17.0, 2.0, -30.0, 0.0), 2.0, 0.0, 5.0],
	[Vector3(16.5, -21.0, 0.0), Vector4(16.5, 2.5, -30.0, 0.0), 4.0, 60.0, 4.0],
]

var _room: Node
var _f := 0
var _tag := "now"
var _hide: PackedStringArray = []
var _unlit: PackedStringArray = []
var _only := -1
var _ambient0 := false


func _initialize() -> void:
	# Never takes the keyboard: typing elsewhere while this window is up must not reach
	# the pen (C opens the theatre, E and Q step through W).
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.substr(4)
		elif a.begins_with("hide="):
			_hide = a.substr(5).split(",")
		elif a.begins_with("unlit="):
			_unlit = a.substr(6).split(",")
		elif a.begins_with("only="):
			_only = int(a.substr(5))
		elif a == "ambient0=1":
			_ambient0 = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _process(_d: float) -> bool:
	_f += 1
	var player := _room.get_node_or_null("Player") as CharacterBody4D
	var rig := _room.get_node_or_null("Player/CameraRig") as Node4D
	if player == null or rig == null:
		print("missing player or rig")
		quit()
		return true
	if _f < 20:
		return false
	var n: int = (_f - 20) / 45
	var phase: int = (_f - 20) % 45
	if n >= SHOTS.size() or (_only >= 0 and n > 0):
		quit()
		return true
	if _only >= 0:
		n = _only
	var shot: Array = SHOTS[n]
	if phase == 0:
		for path in _hide:
			var node := _room.get_node_or_null(path) as Node4D
			if node != null:
				node.visible = false
		_hide_hud(_room.get_node("UI"))
		for path in _unlit:
			var light := _room.get_node_or_null(path)
			if light != null:
				light.set("light_energy", 0.0)
		if _ambient0:
			var env := _room.get_node("World/Environment")
			env.set("ambient_light_color", Color.BLACK)
			env.set("ambient_light_sky_contribution", 0.0)
	if phase < 30:
		# Held in place every frame, since gravity and the bounds would otherwise move it.
		var at: Vector3 = shot[0]
		var ground := 0.0
		player.global_position = Vector4(at.x, ground + 1.0, at.y, at.z)
		player.linear_velocity = Vector4.ZERO
		var look: Vector4 = shot[1]
		var d: Vector4 = look - player.global_position
		rig.set("yaw", atan2(-d.x, -d.z))
		rig.set("pitch", deg_to_rad(shot[2]))
		rig.set("_slice_xw", deg_to_rad(shot[3]))
		rig.set("distance", shot[4])
		rig.call("_apply")
	if phase == 40:
		var path: String = "res://smoke_test_output/cave_hill_%s_%d.png" % [_tag, n]
		root.get_texture().get_image().save_png(path)
		print("   saved %s" % path.get_file())
	return false


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_hud(child)
