extends SceneTree

## Pictures of the chair, the sit and the shots. Windowed, because --headless has no
## rendering device and get_image() comes back null.
##
## THE PLAYER'S OWN CAMERA TAKES THESE, whichever one that is - the orbit rig before the
## sit, the shot camera after it. That is the point: these are the frames somebody
## actually gets, not a director's view of them.

var _root: Node
var _f := 0
var _pending := ""
var _shots := 0
var _player: CharacterBody4D
var _seat: Node
var _camera: Node
var _two: Node
var _seen := {}
var _held_for := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _shoot(tag: String) -> void:
	_pending = tag


func _process(_d) -> bool:
	_f += 1
	if _f < 50:
		return false
	if _pending != "":
		root.get_texture().get_image().save_png(
			"res://smoke_test_output/seat_%s.png" % _pending)
		print("saved seat_%s.png" % _pending)
		_pending = ""
		_shots += 1
		return false

	if _player == null:
		_player = _root.get_node("Player") as CharacterBody4D
		_seat = _root.get_node("UI/Seat")
		_camera = _root.get_node("ShotCamera")
		_two = _root.get_node("PartTwo")
		var show: Node = _root.get_node("Show")
		show.set("act_seconds", 7.0)
		show.set("opening_seconds", 6.0)
		var stage: Node4D = _root.get_node("Stage") as Node4D
		# Half way down the rake, which is where the aside fires and where the chair
		# starts offering itself.
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.52) + 0.18,
			lerpf(top.z, foot.z, 0.52), 0.0)
		return false

	# The chair, lit, with the prompt over it.
	if not _seen.has("offer") and bool(_seat.call("is_offering")):
		_seen["offer"] = true
		_shoot("0_offer")
		return false
	if _seen.has("offer") and not _seen.has("pressed"):
		_seen["pressed"] = true
		_seat.call("sit")
		return false
	# Mid-sit, a good way in. NOT the first frame the camera is held: that one is still the
	# player's own view, easing out of the back of their own head, and it is the one the
	# first version of this kept catching.
	if _seen.has("pressed") and bool(_camera.call("is_holding")):
		_held_for += 1
	if _held_for == 60 and not _seen.has("mid"):
		_seen["mid"] = true
		_shoot("1_sitting")
		return false
	if _seen.has("mid") and not _seen.has("down") and bool(_seat.call("is_settled")):
		_seen["down"] = true
		_shoot("2_seated")
		return false

	# And then whatever the show is doing, one frame per act.
	var show: Node = _root.get_node("Show")
	var act: int = int(show.get("_act"))
	var shot: String = String(_camera.call("shot_name"))
	var tag := "%d_act%d_%s" % [3 + act, act, shot]
	if _seen.has("down") and act >= 0 and not _seen.has(tag) \
			and float(show.get("_phase")) > 4.0:
		_seen[tag] = true
		_shoot(tag)
		return false
	if act > 2 or _f > 4000:
		print("%d pictures" % _shots)
		quit()
		return true
	return false
