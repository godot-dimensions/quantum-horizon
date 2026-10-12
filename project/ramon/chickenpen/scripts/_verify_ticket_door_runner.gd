extends SceneTree

## The ticket raises a real door in front of you, rather than teleporting you.
##
## This runner used to also cover building the theatre early and parking it in the farm,
## which measured well - 3,946 ms at the threshold down to 2.0 - and was reverted anyway.
## A parked theatre is a WorldEnvironment4D with `current = true` sitting in the tree, and
## an environment is not a visual node: `visible = false` hides meshes and does nothing at
## all about the sky, the tonemapping or the mood. The farm turned into the inside of the
## cinema while the player was still standing in a field.
##
## The lesson is worth more than the milliseconds: adding a whole scene to the tree adds
## everything in it that claims something GLOBAL, and visibility is not a way to hold those
## back. The cost lives in the cinema now, where it belongs.

var _root: Node
var _f := 0
var _fails: Array = []
var _ticket: Node
var _arch: Node4D
var _player: Node4D
var _crossing: Node


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 40:
		return false
	_ticket = _root.get_node_or_null("Systems/Rewatch")
	_arch = _root.get_node_or_null("World/TrymCabin/TrymDoor") as Node4D
	_player = _root.get_node_or_null("Player") as Node4D
	_crossing = _root.get_node_or_null("Crossing")
	if _ticket == null or _arch == null or _player == null or _crossing == null:
		_check("the pieces are in the scene", false, "Rewatch / TrymDoor / Player / Crossing")
		return _finish()

	print("\n--- nothing is built until you go ---")
	_check("no theatre is standing by", not bool(_crossing.call("is_away"))
		and _root.get_node_or_null("Theatre") == null,
		"the farm has the sky and the camera to itself")

	print("\n--- and the ticket raises a real door ---")
	_player.global_position = Vector4(2.0, 1.2, 6.0, 0.0)
	_arch.set("armed", false)
	_ticket.call("_raise_the_door")
	var gap: Vector4 = _arch.global_position - _player.global_position
	_check("it goes up in front of you, not somewhere else",
		absf(Vector2(gap.x, gap.z).length() - float(_ticket.get("door_ahead"))) < 0.2,
		"%.1f m ahead, where Trym's own door is across the field"
			% Vector2(gap.x, gap.z).length())
	_check("in your slice",
		is_equal_approx(_arch.global_position.w, _player.global_position.w),
		"no rotating to reach your own door")
	_check("and it opens rather than teleporting you",
		bool(_arch.get("armed")) and not bool(_crossing.call("is_away")),
		"armed - you are still in the field until you walk through it")
	_check("which somebody is already listening for",
		_arch.is_connected("entered", Callable(_root.get_node("Invitation"), "_on_entered")),
		"the arch announces it, the invitation turns it into a trip")
	_check("and the ticket knows the door is its own",
		bool(_ticket.get("_own_door")),
		"so it folds it away again when you come back - nothing else will")
	return _finish()


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
