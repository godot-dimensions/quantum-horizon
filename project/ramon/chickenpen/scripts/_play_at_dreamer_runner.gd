extends SceneTree

## Starts the pen and puts you in the far room in front of the dreamer, then leaves you to
## play: through the cave's own crossing, the far room streamed in as it would be, you set
## down a few metres before it facing it, and from then on nothing here touches anything.
## For looking at the dreamer without the walk (Ramon, 28 Sept: "can you open the game for
## me in front of him?"). Windowed or fullscreen, as launched.

var _room: Node
var _cave: Node4D
var _f := 0
var _settle := 0
var _done := false


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _place() -> void:
	var p := _room.get_node("Player") as CharacterBody4D
	p.global_position = _cave.global_position + Vector4(0.0, 0.05, -30.5, 36.0)
	p.linear_velocity = Vector4.ZERO
	var rig := p.get_node("CameraRig") as Node4D
	var d: Vector4 = _cave.global_position + Vector4(0, 6.2, -36, 36) - p.global_position
	rig.set("yaw", atan2(-d.x, -d.z))
	rig.set("pitch", deg_to_rad(12.0))
	rig.call("_apply")


func _process(_d: float) -> bool:
	if _done:
		return false
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave":
				_cave = c
		# Straight to the far room: no "what is this place?" on the way past the chamber.
		_room.set_meta(&"cave_first_look_said", true)
	if _f < 14 or _cave == null:
		return false
	_place()
	if bool(_cave.get_node("FarStream").call("is_loaded")):
		_settle += 1
		if _settle > 20:
			_done = true
			print("   in front of the dreamer - over to you")
	return false
