extends SceneTree

## Pictures of the whole crossing: Trym walking out of his shed, the door he raises, and
## the presentation on the other side of it.
##
## A FREE CAMERA, not the player's. The orbit rig parks the player body between the lens
## and everything worth photographing; a camera of its own can stand where the picture is.
## It is DUPLICATED from the scene's, because a fresh Camera4D renders wireframe on black
## and would photograph a different game.
##
## AND THE SHOW IS RUN FAST. The talk is a minute long by design; for six photographs that
## is six thousand frames of waiting. The act length is shortened on the instance before it
## starts, which changes the pacing and nothing else about what is drawn.

var _root: Node
var _f := 0
var _shot := 0
var _pending := ""
var _eye: Camera4D
var _inv: Node
var _arch: Node4D
var _trym: Node4D
var _player: Node4D
var _theatre: Node
var _seen := {}


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _look_from(eye: Vector4, target: Vector4) -> void:
	var f: Vector4 = (target - eye).normalized()
	_eye.global_position = eye
	_eye.global_basis = Basis4D.from_zx(atan2(-f.x, -f.z)) \
		* Basis4D.from_yz(asin(clampf(f.y, -1.0, 1.0)))


func _save(name: String) -> void:
	_pending = name


func _process(_d) -> bool:
	_f += 1
	if _f < 70:
		return false
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/cross_%s.png" % _pending)
		print("saved cross_%s.png" % _pending)
		_pending = ""
		_shot += 1
		return false

	if _eye == null:
		_inv = _root.get_node("Invitation")
		_arch = _root.get_node("World/TrymDoor") as Node4D
		_trym = _root.get_node("World/Trym") as Node4D
		_player = _root.get_node("Player") as Node4D
		_eye = (_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_root.add_child(_eye)
		_eye.position = Vector4.ZERO
		_eye.current = true
		# Out of shot, and far enough that he does not react to the player at all.
		_player.global_position = Vector4(40.0, 1.3, 40.0, 0.0)
		_inv.call("offer")
		return false

	var figure: Node4D = _trym.get_node_or_null("Figure") as Node4D
	var at: Vector4 = figure.global_position if figure != null else _trym.global_position
	# Keyed off his BEAT, not off how far he has got. Distance thresholds photograph
	# whatever happens to be true at some arbitrary metre mark; the beat is the thing the
	# picture is of.
	var beat: int = int(_inv.get("_beat"))

	# 1. on his feet at the desk, mid-invitation. Camera inside the shed with him - the
	# shed's own cutaway follows the PLAYER's camera, and this is not that camera.
	# Not the frame he starts talking on - the frame he is UP. The get-up takes most of a
	# second and the first attempt at this photographed a man still folded onto his stool.
	if not _seen.has("asks") and beat >= 1 and bool(_trym.call("is_standing")):
		_seen["asks"] = true
		_look_from(Vector4(-9.0, 1.7, -13.3, 0.0), at + Vector4(0.0, 0.9, 0.0, 0.0))
		_save("1_asks")
		return false
	# 2. out through the shed door, mid-stride.
	if not _seen.has("walks") and beat == 2 and at.z > -11.0:
		_seen["walks"] = true
		_look_from(Vector4(-6.3, 2.0, -10.4, 0.0), at + Vector4(0.0, 0.9, 0.0, 0.0))
		_save("2_walks")
		return false
	# 3. the door up behind him, him turned back to the player.
	if not _seen.has("door") and beat >= 4:
		_seen["door"] = true
		_look_from(Vector4(-5.4, 2.5, -1.2, 0.0),
			_arch.global_position + Vector4(0.0, 1.4, 0.0, 0.0))
		_save("3_door")
		return false
	# 4. he goes when somebody comes to stand with him - so come and stand with him. The
	# first version of this teleported straight to the DOOR, which is two metres past him
	# and, it turns out, close enough to photograph but not what he is waiting for: he
	# stood there indefinitely and the run never reached the theatre.
	if _seen.has("door") and figure != null and figure.visible:
		_player.global_position = Vector4(at.x + 1.4, 1.2, at.z + 1.4, 0.0)
		return false
	# 5. and then through the door after him.
	if _seen.has("door") and _theatre == null:
		_player.global_position = Vector4(_arch.global_position.x, 1.2,
			_arch.global_position.z, 0.0)
		_theatre = _root.get_node_or_null("Theatre")
		if _theatre == null:
			return false
		var show: Node = _theatre.get_node("Show")
		show.set("opening_seconds", 3.0)
		show.set("act_seconds", 4.5)
		_eye = (_theatre.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).duplicate()
		_theatre.add_child(_eye)
		_eye.position = Vector4.ZERO
		_eye.current = true
		return false

	# What the player ACTUALLY sees on arrival: from where their own camera sits, five
	# metres behind them down the aisle. The fixed camera the rest of these shots use
	# would not have caught the way out parked in the middle of the frame, which is the
	# thing that was wrong with the last version of this room.
	if _theatre != null and not _seen.has("arrival"):
		_seen["arrival"] = true
		# Where their own camera sits: five metres back up the walkway, above the rake.
		_look_from(Vector4(0.0, 3.5, 9.6, 0.0), Vector4(0.0, 1.3, 0.2, 0.0))
		_save("7_arrival")
		return false
	if _theatre != null and not _seen.has("wayout"):
		_seen["wayout"] = true
		_look_from(Vector4(-2.8, 2.4, 1.4, 0.0),
			(_theatre.get_node("ExitArch") as Node4D).global_position
				+ Vector4(0.0, 0.9, 0.0, 0.0))
		_save("8_wayout")
		return false

	if _theatre != null:
		var show: Node = _theatre.get_node("Show")
		var act: int = int(show.call("current_act"))
		var key: String = "act%d" % act
		# Late in the act, not on the frame it turns over: the exhibit has risen by then,
		# the caption has faded up, and he has crossed to the drum and put his arm out.
		var late: bool = float(show.get("_phase")) > float(show.get("act_seconds")) * 0.75
		if act >= 0 and late and not _seen.has(key):
			_seen[key] = true
			# From the house, over the drum, with the presenter down on the left.
			_look_from(Vector4(1.4, 3.6, 9.2, 0.0), Vector4(-0.6, 1.5, 0.0, 0.0))
			_save("%d_act%d" % [4 + act, act])
			return false
		if act >= 3 and _seen.has("act2"):
			print("%d pictures" % _shot)
			quit()
			return true
	return false
