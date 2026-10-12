extends SceneTree

## Lets the behaviour run itself and logs every state change, to check it actually cycles
## rather than sticking in whichever state it reached first. Nothing is forced here - the
## companion runner does that to photograph the poses.

const _NAMES: Array = ["WALK", "ROOT", "GOING_DOWN", "LYING", "GETTING_UP"]

var _antics: Node
var _nike: Node4D
var _last: int = -1
var _frames: int = 0
var _changes: int = 0
var _seen := {}


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	_nike = scene.get_node("Nike")
	_antics = scene.get_node("Nike/Antics")
	# THE TIMERS ARE SHORTENED FOR THE TEST, not the frame count raised. 4000 render
	# frames with vsync off is about two seconds of SIMULATED time, and a walk leg alone
	# lasts five to eleven - so the first version of this sat in WALK for the whole run and
	# reported the machine broken. Frames are not seconds; see lofting_gotchas.md.
	_antics.set("walk_seconds", Vector2(0.5, 0.8))
	_antics.set("root_seconds", Vector2(0.4, 0.6))
	_antics.set("lie_seconds", Vector2(0.7, 1.0))
	_antics.set("down_seconds", 0.25)
	_antics.set("up_seconds", 0.35)
	_antics.set("lie_chance", 0.5)
	var horse: Node = scene.get_node("Creature/Strider")
	horse.get_node("Walker").set_process_mode(Node.PROCESS_MODE_DISABLED)
	horse.get_node("Hide").visible = false


func _process(_d) -> bool:
	_frames += 1
	var now: int = int(_antics.get("state"))
	if now != _last:
		_last = now
		_changes += 1
		_seen[now] = int(_seen.get(now, 0)) + 1
		print("frame %5d  ->  %-11s  z=%+.2f" % [_frames, _NAMES[now], _nike.position.z])
	if _frames < 4000:
		return false
	print("--- %d changes over %d frames ---" % [_changes, _frames])
	for key in _NAMES.size():
		print("  %-11s entered %d time(s)" % [_NAMES[key], int(_seen.get(key, 0))])
	return true
