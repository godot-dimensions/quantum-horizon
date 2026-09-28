extends SceneTree

## What is on the skyline, from the middle of the pen: four compass directions on the home
## slice, then the same four with the slice turned a quarter through W. The second row is
## the part a flat 3D backdrop gets wrong - turning into W swaps x for w, so a ring of hills
## laid out only in x and z shows empty field there.
##
## Through the player's rig, like play. Windowed.
## Args (after --): tag=<name>   writes res://smoke_test_output/horizon_<tag>_<n>.png
## Optional: at=x,z   stand somewhere other than the origin.   pitch=<deg>   default 4.
##           ui=1       keep the HUD; by default it is hidden so the skyline can be read.
##           hills=<path>  show this baked mesh on World/Hills instead of the scene's own,
##                      to look at a bake before the scene uses it.

var _room: Node
var _f := 0
var _shot := 0
var _tag := "now"
var _at := Vector2.ZERO
var _pitch := 4.0
var _ui := false
var _hills := ""
const YAWS := [0.0, 90.0, 180.0, 270.0]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="):
			_tag = a.substr(4)
		elif a.begins_with("at="):
			var p: PackedStringArray = a.substr(3).split(",")
			_at = Vector2(float(p[0]), float(p[1]))
		elif a.begins_with("pitch="):
			_pitch = float(a.substr(6))
		elif a == "ui=1":
			_ui = true
		elif a.begins_with("hills="):
			_hills = a.substr(6)
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	if _hills != "":
		(_room.get_node("World/Hills") as MeshInstance4D).mesh = load(_hills) as Mesh4D
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
	# One shot every 40 frames; the first 20 let the scene settle.
	var n: int = (_f - 20) / 40
	var phase: int = (_f - 20) % 40
	if _f < 20:
		return false
	if n >= YAWS.size() * 2:
		quit()
		return true
	if phase == 0:
		if not _ui:
			_hide_hud(_room.get_node("UI"))
		player.global_position = Vector4(_at.x, 0.1, _at.y, 0.0)
		player.linear_velocity = Vector4.ZERO
		rig.set("yaw", deg_to_rad(YAWS[n % YAWS.size()]))
		rig.set("pitch", deg_to_rad(_pitch))
		rig.set("_slice_xw", 0.0 if n < YAWS.size() else PI * 0.5)
		rig.call("_apply")
	if phase == 30:
		var path: String = "res://smoke_test_output/horizon_%s_%d.png" % [_tag, n]
		root.get_texture().get_image().save_png(path)
		print("   saved %s   yaw %d  slice xw %d" % [path.get_file(), int(YAWS[n % YAWS.size()]), 0 if n < YAWS.size() else 90])
	return false


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		elif child is CanvasLayer:
			(child as CanvasLayer).visible = false
		_hide_hud(child)
