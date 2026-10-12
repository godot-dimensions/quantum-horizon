extends SceneTree
## Drives the player in and out of the head's space and forces each behaviour, checking
## the head actually aims at the player and that the ranking holds.

var _frame := 0
var _root: Node
var _player: CharacterBody4D
var _head: Node4D
var _tip: Node4D
var _att: Node
var _gait: Node
var _spine: Node
var _stage := 0
var _best_alignment := -2.0
var _rest_alignment := 0.0
var _seek_neck := 0.0
var _brace := 0.0
var _states := {}
const STAGES := ["far", "close", "seek", "shake"]

func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_player = _root.get_node("Player")
		_head = _root.get_node("Creature/Barrel/Chest/Neck1/Neck2/Head")
		_tip = _root.get_node("Creature/Barrel/Chest/Neck1/Neck2/Head/B2")
		_att = _root.get_node("HeadAttention")
		_gait = _root.get_node("IKGaitDriver")
		_spine = _root.get_node("SpineNeckSolver")
		_gait.halted = true
		# Long timers so nothing fires except what each stage forces.
		_att.seek_interval_min = 999.0
		_att.seek_interval_max = 999.0
		_att.shake_interval_min = 999.0
		_att.shake_interval_max = 999.0
		_att.wander_interval_min = 999.0
		_att.wander_interval_max = 999.0
		return false
	# Park the player far behind and above, so "near" has to be deliberate.
	var stage: String = STAGES[_stage]
	if stage == "close":
		# Right in front of the head, which sits near (-2.05, 2.8, 0). The previous
		# version of this test parked the player 6 units off - chosen for the SEEK
		# stage - and then wondered why the 4-unit glance never fired.
		_player.global_position = Vector4(-3.2, 2.8, 0.9, 0.0)
	else:
		# Diagonally BEHIND the creature (it faces -X, so +X is behind) and off to one
		# side: the angle the head alone cannot reach.
		_player.global_position = Vector4(3.4, 2.6, 2.2, 0.0)
	_player.linear_velocity = Vector4.ZERO

	if _frame == 30:
		if stage == "seek":
			_att._seek_elapsed = 0.0
		elif stage == "shake":
			_att._shake_elapsed = 0.0

	if _frame > 32:
		# How well the head's own bone points at the player: 1 is dead on.
		var bone: Vector4 = (_tip.global_position - _head.global_position).normalized()
		var to_player: Vector4 = (_player.global_position - _head.global_position).normalized()
		var alignment: float = bone.dot(to_player)
		_best_alignment = maxf(_best_alignment, alignment)
		if stage == "far":
			_rest_alignment = alignment
		if stage == "seek":
			_seek_neck = maxf(_seek_neck, float(_spine.aim_weight))
			for tag in ["HindLA", "HindRK"]:
				if _gait.target_offsets.has(tag):
					_brace = maxf(_brace, (_gait.target_offsets[tag] as Vector4).length())
		_states[_att._state] = true

	if _frame >= 150:
		print("  %-6s best head-to-player alignment %+.3f   states seen: %s" % [
			stage, _best_alignment, ", ".join(PackedStringArray(_states.keys()))])
		_stage += 1
		if _stage >= STAGES.size():
			print("")
			print("seek recruited the neck (peak aim_weight): %.2f" % _seek_neck)
			print("seek braced a hind foot by:               %.3f units" % _brace)
			quit(0)
			return true
		_frame = 20
		_best_alignment = -2.0
		_states.clear()
		# Clear any behaviour still running, or it bleeds into the next stage's reading.
		_att._seek_elapsed = -1.0
		_att._shake_elapsed = -1.0
		_att._wander_elapsed = -1.0
		_att._glance_elapsed = -1.0
		_att._glance_armed = true
	return false
