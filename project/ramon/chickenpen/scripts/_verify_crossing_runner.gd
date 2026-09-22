extends SceneTree

## The whole crossing, end to end: Trym offers, walks out of his shed, raises a door, goes
## through it - then the player follows, the farm goes to sleep, and coming back finds it
## exactly as it was left.
##
## IT WALKS THE CLOCK ITSELF. Every beat of this is a timer or a distance, so the test
## steps frames and waits for the world to say it is ready rather than guessing how many
## frames a get-up takes. A fixed frame count is a test that passes on the machine it was
## written on.

var _root: Node
var _f := 0
var _stage := 0
var _fails: Array = []
var _inv: Node
var _trym: Node4D
var _arch: Node4D
var _crossing: Node
var _player: Node4D
var _desk_at := Vector4.ZERO
var _guard := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-40s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _v(v: Vector4) -> String:
	return "(%.1f, %.1f, %.1f, %.1f)" % [v.x, v.y, v.z, v.w]


func _figure() -> Node4D:
	return _trym.get_node_or_null("Figure") as Node4D


func _showing(path: String) -> bool:
	var node: CanvasItem = _root.get_node_or_null(path) as CanvasItem
	return node != null and node.visible


func _process(delta: float) -> bool:
	_f += 1
	if _f < 30:
		return false
	_guard += 1
	if _guard > 60000:
		print("   FAIL stuck at stage %d" % _stage)
		quit(1)
		return true

	match _stage:
		0:
			_inv = _root.get_node_or_null("Invitation")
			_crossing = _root.get_node_or_null("Crossing")
			_trym = _root.get_node_or_null("World/Trym") as Node4D
			_arch = _root.get_node_or_null("World/TrymDoor") as Node4D
			_player = _root.get_node_or_null("Player") as Node4D
			print("\n--- the pieces are in the scene ---")
			_check("an invitation", _inv != null, "Invitation")
			_check("a crossing", _crossing != null, "Crossing")
			_check("a door for Trym to raise", _arch != null, "World/TrymDoor")
			if _inv == null or _crossing == null or _arch == null or _trym == null:
				print("\n%d FAIL(s)" % _fails.size()); quit(1); return true
			_check("the door starts dark", not bool(_arch.get("armed")), "armed = false")
			_desk_at = (_trym.get_node("DeskTop") as Node4D).global_position
			# Something switched OFF before the crossing, to prove coming back does not
			# switch it on again. Restoring "every Control under UI" would un-park the
			# dials Ramon asked to be put away and pop open every dialogue box in the
			# scene - so the crossing remembers what it actually hid, and nothing else.
			var parked: CanvasItem = _root.get_node("UI/Debug") as CanvasItem
			if parked != null:
				parked.visible = false
			_check("the door is not even there yet", not _arch.visible,
				"hidden, not merely lowered - a shut door has its lintel at ground level")
			var talk: Node = _root.get_node("Systems/TrymTalk")
			_check("his script carries the invite",
				TrymScript.NODES.has("show_you")
					and String(TrymScript.NODES["show_you"].get("do", "")) == "trym_invite",
				"show_you does trym_invite")
			# Exactly as the dialogue would: the effect arms it, the end of the
			# conversation starts it.
			talk.emit_signal("effect", "trym_invite")
			talk.emit_signal("ended")
			_check("and that is what sets him off", bool(_inv.call("has_offered")),
				"armed on the effect, walked on the end of the conversation")
			_stage = 1
		1:
			# He speaks, then walks. Wait for the door to come up.
			if not bool(_arch.get("armed")):
				return false
			print("\n--- he walks out and raises it ---")
			var fig: Vector4 = _figure().global_position
			_check("he left the shed", fig.z > -12.0,
				"figure at %s, desk still at %s" % [_v(fig), _v(_desk_at)])
			_check("the furniture stayed behind",
				(_trym.get_node("DeskTop") as Node4D).global_position.is_equal_approx(_desk_at),
				"desk has not moved")
			_check("the door went up behind him",
				_arch.global_position.z < fig.z,
				"door at z %.1f, he is at z %.1f - facing you across it"
					% [_arch.global_position.z, fig.z])
			_check("his tag came with him",
				absf((_root.get_node("World/TrymHead") as Node4D).global_position.z - fig.z) < 1.5,
				"TrymHead follows the figure")
			_check("and he is waiting rather than leaving", _figure().visible,
				"he asked you to follow him, so he does not go without you")
			_stage = 15
		15:
			# He called you over and he will stand there until you come - so come. He only
			# goes through once somebody is near enough to follow him.
			var him: Vector4 = _figure().global_position
			_player.global_position = Vector4(him.x + 1.6, 1.2, him.z + 1.6, 0.0)
			if _figure().visible:
				return false
			print("\n--- and goes through it ---")
			_check("he walked through it, not past it",
				_figure().global_position.z < _arch.global_position.z,
				"gone at z %.1f, door at z %.1f"
					% [_figure().global_position.z, _arch.global_position.z])
			_check("and the door is left standing", bool(_arch.get("armed")),
				"open behind him")
			_stage = 2
		2:
			# Let the door finish opening, then walk the player into it.
			_player.global_position = Vector4(_arch.global_position.x, 1.2,
				_arch.global_position.z, 0.0)
			if not bool(_crossing.call("is_away")):
				return false
			print("\n--- through it ---")
			var theatre: Node = null
			for child in _root.get_children():
				if child.name == "Theatre":
					theatre = child
			_check("the theatre is here", theatre != null, "added beside the farm")
			_check("the farm is asleep, not unloaded",
				_root.get_node("World").process_mode == Node.PROCESS_MODE_DISABLED \
					and is_instance_valid(_root.get_node("Chickens")),
				"World disabled, Chickens still in the tree")
			_check("and its HUD is off", not _showing("UI/SlicePlane") \
				and not _showing("UI/Inventory"), "no farm dials over the show")
			_check("the presentation has its own player",
				theatre != null and theatre.get_node_or_null("Player") != null, "Theatre/Player")
			_stage = 3
		3:
			# The way home. The theatre's own runner already proves the exit LIGHTS when
			# the first act begins, and the arch's own code decides when somebody has
			# walked into it - what is not covered anywhere else is what happens when it
			# fires. So this checks the wire is on, and then pulls it.
			var room: Node = _root.get_node_or_null("Theatre")
			if room == null:
				return false
			var exit: Node = room.get_node_or_null("ExitArch")
			print("\n--- the way home ---")
			_check("the exit is wired to the crossing",
				exit != null and exit.is_connected("entered", Callable(_crossing, "come_back")),
				"ExitArch.entered -> Crossing.come_back")
			_crossing.call("come_back")
			_stage = 4
		4:
			var leaving: Node = _root.get_node_or_null("Theatre")
			# queue_free is deferred, so the node can still be in the tree on the frame the
			# crossing says it has gone. Asking whether it is ON ITS WAY OUT is the honest
			# question; asking whether it has already vanished is a race.
			_check("the theatre is gone", leaving == null or leaving.is_queued_for_deletion(),
				"freed on the way out")
			_check("the farm is awake",
				_root.get_node("World").process_mode == Node.PROCESS_MODE_INHERIT
					and _root.get_node("Player").process_mode == Node.PROCESS_MODE_INHERIT,
				"World and Player running")
			_check("its HUD is back", _showing("UI/SlicePlane"), "the dial is drawing again")
			_check("what was already hidden stayed hidden", not _showing("UI/Debug"),
				"coming back only restores what the crossing itself put away")
			_check("the farm camera has it again",
				(_root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).current,
				"current = true")
			_check("the chickens are the same ones",
				_root.get_node("Chickens").get_child_count() > 0,
				"%d still in the scene" % _root.get_node("Chickens").get_child_count())
			_check("the player is put down in front of the door, not in it",
				(_root.get_node("Player") as Node4D).global_position.z
					> _arch.global_position.z + 1.0,
				"back at z %.1f, door at z %.1f"
					% [(_root.get_node("Player") as Node4D).global_position.z,
						_arch.global_position.z])
			_check("and the door can be walked again",
				not bool(_arch.get("_used")), "rearm() ran over the tree")
			var both: float = (_figure().global_position
				- (_root.get_node("Player") as Node4D).global_position).length()
			_check("he came out with you, on your side of it", _figure().visible
				and _figure().global_position.z > _arch.global_position.z
				and both > 0.8 and both < 4.0,
				"%.1f m from you, door at z %.1f" % [both, _arch.global_position.z])
			_check("and the door is folding away", not bool(_arch.get("armed")),
				"disarmed - it lifts into the air and goes")
			_check("his conversation marker came with him",
				absf((_root.get_node("World/TrymStand") as Node4D).global_position.z
					- _figure().global_position.z) < 3.0,
				"talking to him no longer teleports you into the shed")
			_check("and he owes you an opinion",
				bool(_root.get_node("Systems/TrymDriver").get("_owes_an_opinion")),
				"next thing he says is 'so, what did you think'")
			print("\n%d FAIL(s)" % _fails.size())
			quit(1 if _fails.size() > 0 else 0)
			return true
	return false
