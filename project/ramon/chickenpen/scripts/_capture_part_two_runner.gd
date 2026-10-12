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
	# His typing must not land in a capture window.
	root.unfocusable = true
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
		show.set("waits_for_seat", 0.0)
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye)
		_eye.position = Vector4.ZERO
		_eye.current = true
		# AND THE FIGURES HAVE TO PROJECT THROUGH THIS ONE. They are drawn in screen space
		# against whichever camera is live, and in the real room that is the shot camera;
		# here it is this stand-in, and without telling the labels so they were being
		# placed against the player's own camera and landing nowhere near their subjects -
		# which looked exactly like the bug it was supposed to be checking.
		var figures: Node = _root.get_node_or_null("UI/Metrics")
		if figures != null:
			figures.set("_camera", _eye)
		(_root.get_node("Player") as Node4D).global_position = Vector4(0.0, 3.3, 12.0, 0.0)
		return false

	# No question since 30 Sept: slide I hands straight on to part two.
	var moment: int = int(_two.call("current_moment"))
	if moment < 0 or moment > 2:
		if moment > 2 and _shots >= 6:
			print("%d pictures" % _shots)
			quit()
			return true
		return false
	var phase: float = float(_two.get("_phase"))
	# Against THIS moment's length, not the shared one - the walk runs longer.
	var pace: float = 1.55 if moment == 2 else 1.0
	var span: float = float(_two.get("moment_seconds")) * pace

	# IV three times: dressed, bared, and in another gait.
	if moment == 2:
		var beats := [["walking", 0.18], ["rig", 0.44], ["gait", 0.90]]
		for i in beats.size():
			var tag: String = "iv_%s" % beats[i][0]
			if not _seen.has(tag) and phase > span * float(beats[i][1]):
				_seen[tag] = true
				_look_from(Vector4(0.6, 4.0, 12.6, 0.0), Vector4(0.0, 2.2, 0.0, 0.0))
				_pending = "%d_%s" % [_shots, tag]
				return false
		return false

	# The goat pair, from the three-quarter the slide is framed on.
	if moment == 1 and not _seen.has("building") and phase > span * 0.42:
		_seen["building"] = true
		_look_from(Vector4(3.1, 2.5, 4.6, 0.0), Vector4(0.0, 1.4, 0.0, 0.0))
		_pending = "%d_iii_building" % _shots
		return false
	var key_name := "m%d" % moment
	if phase > span * 0.72 and not _seen.has(key_name):
		_seen[key_name] = true
		_look_from(Vector4(3.1, 2.5, 4.6, 0.0), Vector4(0.0, 1.4, 0.0, 0.0))
		# Numbered as the audience sees them: part two's first slide is II.
		_pending = "%d_slide%d" % [_shots, moment + 2]
		return false
	return false
