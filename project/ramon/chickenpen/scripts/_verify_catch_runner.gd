extends SceneTree

## Phase 04 end to end: walk up to a chicken, catch it, check it rides above the head
## through ordinary movement AND a slice change, then throw it and check it lands.
var _root: Node
var _f := 0
var _player: CharacterBody4D
var _catcher: Node
var _manager: Node
var _target: Node
var _body: Node4D
var _anchor: Node4D
var _carry_gap_max: float = 0.0
var _w_while_carried: float = 0.0
var _stage := "approach"
var _land_frame := -1
var _throw_from := Vector4.ZERO
var _caught_at := -1


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		_player = _root.get_node("Player")
		_catcher = _root.get_node("Player/Catcher")
		_anchor = _root.get_node("Player/CarryAnchor")
		_manager = _root.get_node("Chickens")
		_target = (_manager.get("agents") as Array)[0]
		_body = _target.get_parent() as Node4D
		print("target chicken: %s at %v" % [_body.name, _body.position])
		return false
	if _f < 40:
		return false

	match _stage:
		"approach":
			# Stand next to it rather than driving the controller: this is testing the
			# catch, not the walking, which has its own tests.
			#
			# Placed ONCE, not every frame. Following the chicken each frame while the
			# catcher moves the chicken onto the player is a feedback loop, and the two
			# of them climbed to y = 27 together before this was spotted - a fault in the
			# test that looked exactly like a fault in the carry.
			if _f == 41:
				_player.global_position = _body.global_position - Vector4(0.0, 0.0, 0.7, 0.0)
			_player.global_basis = Basis4D.from_zx(0.0)
			if _f > 70:
				var candidate: Node = _catcher.call("_best_candidate")
				print("candidate found: %s" % ("yes" if candidate != null else "NO"))
				_catcher.call("_catch", candidate if candidate != null else _target)
				_caught_at = _f
				_stage = "carry"
			return false
		"carry":
			# Move the player about, including through W, and watch the chicken hold on.
			#
			# AWAY FROM NIKE, toward -x. The path used to run +x from the first chicken
			# straight into where Nike stands; at three times the size (28 Sept) her body
			# reaches it, and a player teleported through her dragged the carried chicken -
			# a real body - against her side, 1.7 m behind the anchor. In play the player
			# collides with her too, so that was the test walking through a pig, not the
			# carry letting go.
			_player.global_position += Vector4(-0.02, 0.0, 0.015, 0.01)
			var gap: float = _body.global_position.distance_to(_anchor.global_position)
			# Not in the first few frames. The catcher lifts the chicken from its physics
			# step, and a drawn frame can come before that step has run: the gap is then
			# the chicken's height off the ground to the anchor, 1.7 m, and the test failed
			# about one run in two on it with the carry working perfectly.
			if _f > _caught_at + 5:
				_carry_gap_max = maxf(_carry_gap_max, gap)
			_w_while_carried = _body.global_position.w
			if _f > 190:
				print("carried: max gap to anchor %.4f, chicken w %.3f, player w %.3f" % [
					_carry_gap_max, _w_while_carried, _player.global_position.w])
				print("second catch blocked while carrying: %s" % str(_catcher.get("carried") != null))
				_throw_from = _body.global_position
				_catcher.call("_release", true)
				_stage = "throw"
			return false
		"throw":
			if _f % 40 == 0:
				print("  f%d y %.3f flying %d state %s" % [_f, _body.global_position.y,
					(_catcher.get("_flying") as Array).size(), _target.call("describe")])
			if _catcher.get("_flying").is_empty() and _land_frame < 0:
				_land_frame = _f
				var travel: float = Vector2(_body.global_position.x - _throw_from.x,
					_body.global_position.z - _throw_from.z).length()
				print("thrown: travelled %.2f units, landed at y %.3f, state %s" % [
					travel, _body.global_position.y, _target.call("describe")])
			if _f > 520:
				print("still flying after landing: %s" % str(not _catcher.get("_flying").is_empty()))
				# 0.15 rather than 0.05: this test moves the player from _process while
				# the catcher follows from _physics_process, so one frame of lag is the
				# harness rather than the carry.
				print("verdict: %s" % ("CATCH LOOP WORKS" if _land_frame > 0 and _carry_gap_max < 0.15 else "FAULT"))
				return true
			return false
	return false
