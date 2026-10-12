extends SceneTree

## Nike in the chicken pen, end to end: is he there, is the lofted girl gone, does G do
## NOTHING until he has asked to be carried, does it work afterwards, does F still talk to
## him from arm's length but NOT while he is being carried, does the player's gait sink
## under him, and does he land on the ground rather than in the air.
##
## THE UNLOCK IS DRIVEN THROUGH THE REAL DIALOGUE, not by calling the driver's handler.
## The script announces `wants_carrying` on the second line of the node where he invites
## it, so the only honest test is to open that node and advance past that line. The
## dialogue advances on a raw ENTER/SPACE/F key rather than on an input action, which is
## why this sends an InputEventKey for that and InputEventAction for everything else.

var _root: Node
var _player: Node4D
var _nike: Node4D
var _grab: Node
var _talk: Node
var _antics: Node
var _avatar: Node4D
var _rest_y: float = 0.0
var _f: int = 0
var _stage: int = 0
var _drop_from: Vector4 = Vector4.ZERO


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
	_player = _root.get_node("Player")
	_nike = _root.get_node("World/Nike")
	_grab = _root.get_node("Systems/NikeGrab")
	_talk = _root.get_node("Systems/NikeTalk")
	_antics = _root.get_node("World/Nike/Antics")
	_avatar = _root.get_node("Player/Avatar")
	print("girl removed: %s" % str(_root.get_node_or_null("World/LoftedGirl") == null))
	print("carry key: %s   starts locked: %s" % [
		_grab.call("carry_key"), str(not bool(_grab.get("unlocked")))])


func _action(name: StringName) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = name
		ev.pressed = down
		Input.parse_input_event(ev)


## The dialogue reads a raw key, not an action.
func _advance() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ENTER
		ev.pressed = down
		Input.parse_input_event(ev)


func _process(_d) -> bool:
	_f += 1
	match _stage:
		0:
			if _f == 8:
				_rest_y = _avatar.position.y
				_player.global_position = Vector4(7.5, 1.2, 4.0, 0.0)
				_player.linear_velocity = Vector4.ZERO
			if _f == 22:
				_action(&"carry_pig")
			if _f == 36:
				print("G WHILE LOCKED: holding %s (want false)" % str(_grab.get("holding")))
				_talk.call("begin", "a_hand")
				_stage = 1
				_f = 0
		1:
			# Taps to get through the first line and bring on the second, which is the one
			# carrying the effect.
			if _f == 14 or _f == 30 or _f == 46:
				_advance()
			if _f == 62:
				print("UNLOCKED BY CONVERSATION: %s" % str(_grab.get("unlocked")))
				_talk.call("stop")
				_stage = 2
				_f = 0
		2:
			if _f == 6:
				_save("nike_prompts")
			if _f == 10:
				var gap: Vector4 = _nike.global_position - _player.global_position
				print("AT PRESS: xz %.2f  |w| %.2f  |y| %.2f  unlocked %s  can_grab %s" % [
					Vector2(gap.x, gap.z).length(), absf(gap.w), absf(gap.y),
					str(_grab.get("unlocked")), str(_grab.call("_can_grab"))])
				_action(&"carry_pig")
			if _f == 40:
				_save("nike_prompt_holding")
			if _f == 90:
				print("HOLDING: %s   antics suspended: %s" % [
					str(_grab.get("holding")), str(_antics.get("suspended"))])
				print("AVATAR y: rest %+.3f carrying %+.3f  (sank %.3f)" % [
					_rest_y, _avatar.position.y, _rest_y - _avatar.position.y])
				_drop_from = _nike.global_position
				_action(&"catch_target")
				_stage = 3
				_f = 0
		3:
			if _f == 30:
				# F while carrying must do NOTHING. Not because the keys collide - they
				# do not any more - but because a conversation panel over an animal held
				# above your head was clutter.
				print("F WHILE CARRYING: talking %s (want false)  still holding %s" % [
					str(_talk.call("is_running")), str(_grab.get("holding"))])
				_talk.call("stop")
				_action(&"carry_pig")
				_stage = 4
				_f = 0
		4:
			if _f == 30:
				print("PUT DOWN: holding %s  moved %.2f  suspended %s  y %+.3f" % [
					str(_grab.get("holding")), _nike.global_position.distance_to(_drop_from),
					str(_antics.get("suspended")), _nike.position.y])
				return true
	if _f > 700:
		print("TIMED OUT in stage %d" % _stage)
		return true
	return false


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/"))
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png("res://smoke_test_output/%s.png" % name)
		print("SAVED %s" % name)
