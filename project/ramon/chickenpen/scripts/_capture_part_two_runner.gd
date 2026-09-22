extends SceneTree

## Pictures of part two. Windowed, because --headless has no rendering device and
## get_image() comes back null.
##
## The goat gets two of them - the control balls on their own, and the skin closed over
## them - because that pair IS the exhibit's argument and a single picture of a finished
## goat would be a picture of a goat. The walking creature gets three for the same reason:
## dressed, skinned back to its handles, and dressed again in a different gait.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0
var _eye: Camera4D
var _two: Node
var _seen := {}


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _look_from(eye: Vector4, target: Vector4) -> void:
	var f: Vector4 = (target - eye).normalized()
	_eye.global_position = eye
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) \
		* Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/two_%s.png" % _pending)
		print("saved two_%s.png" % _pending)
		_pending = ""
		_shots += 1
		return false

	if _eye == null:
		_two = _root.get_node("PartTwo")
		var show: Node = _root.get_node("Show")
		show.set("opening_seconds", 1.0)
		show.set("act_seconds", 0.5)
		show.set("closing_seconds", 0.3)
		_two.set("moment_seconds", 7.0)
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye)
		_eye.position = Vector4.ZERO
		_eye.current = true
		(_root.get_node("Player") as Node4D).global_position = Vector4(0.0, 3.3, 12.0, 0.0)
		return false

	# Answer the prompt the moment it is up.
	var prompt: Node = _root.get_node("UI/Prompt")
	if bool(prompt.call("is_asking")) and not _seen.has("asked"):
		_seen["asked"] = true
		_look_from(Vector4(0.0, 3.3, 9.0, 0.0), Vector4(0.0, 1.5, 0.2, 0.0))
		_pending = "0_the_ask"
		return false
	if _seen.has("asked") and not _seen.has("said_yes"):
		_seen["said_yes"] = true
		var key := InputEventKey.new()
		key.keycode = int(prompt.get("yes_key"))
		key.pressed = true
		Input.parse_input_event(key)
		return false

	var moment: int = int(_two.call("current_moment"))
	if moment < 0 or moment > 6:
		if moment > 6 and _shots >= 10:
			print("%d pictures" % _shots)
			quit()
			return true
		return false
	var phase: float = float(_two.get("_phase"))
	# Against THIS moment's length, not the shared one: the creature runs half again as
	# long as the rest, and measuring its beats against the shared number caught the skin
	# coming off rather than the gait changing.
	var span: float = float(_two.get("moment_seconds")) * (1.55 if moment == 4 else 1.0)
	var late: bool = phase > span * 0.72

	# THE CREATURE, THREE TIMES. Backed off and side-on: it is 5.9 long against a 6.2 drum,
	# and a walk cycle is a thing you read from the side.
	if moment == 4:
		var beats := [["walking", 0.18], ["rig", 0.44], ["gait", 0.90]]
		for i in beats.size():
			var tag: String = "c_%s" % beats[i][0]
			if not _seen.has(tag) and phase > span * float(beats[i][1]):
				_seen[tag] = true
				_look_from(Vector4(0.6, 4.0, 12.6, 0.0), Vector4(0.0, 2.2, 0.0, 0.0))
				_pending = "%d_creature_%s" % [5 + i, beats[i][0]]
				return false
		return false

	# The build moment twice: half assembled, and reshaped.
	if moment == 3 and not _seen.has("half") and phase > float(_two.get("moment_seconds")) * 0.30:
		_seen["half"] = true
		_look_from(Vector4(2.8, 2.2, 3.8, 0.0), Vector4(0.0, 1.5, 0.0, 0.0))
		_pending = "4_building"
		return false
	# The goat twice: the workings, then the skin.
	if moment == 2 and not _seen.has("balls") and phase > 1.2:
		_seen["balls"] = true
		_look_from(Vector4(2.8, 2.2, 3.8, 0.0), Vector4(0.0, 1.5, 0.0, 0.0))
		_pending = "3_goat_balls"
		return false
	var key_name := "m%d" % moment
	if late and not _seen.has(key_name):
		_seen[key_name] = true
		if moment == 2 or moment == 3:
			_look_from(Vector4(2.8, 2.2, 3.8, 0.0), Vector4(0.0, 1.5, 0.0, 0.0))
		else:
			_look_from(Vector4(1.1, 3.4, 8.4, 0.0), Vector4(0.0, 1.5, 0.0, 0.0))
		_pending = "%d_moment%d" % [moment + (1 if moment < 4 else 4), moment + 4]
		return false
	return false
