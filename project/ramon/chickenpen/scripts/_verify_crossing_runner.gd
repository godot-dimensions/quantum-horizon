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
var _stopped_at: float = 0.0


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
			# The shortcut in and out, exercised as a keypress rather than as a method
			# call - a debug key that is wired to nothing is a debug key that does nothing.
			var jump := InputEventKey.new()
			jump.keycode = int(_crossing.get("debug_key"))
			jump.pressed = true
			Input.parse_input_event(jump)
			if _inv == null or _crossing == null or _arch == null or _trym == null:
				print("\n%d FAIL(s)" % _fails.size()); quit(1); return true
			_check("the door starts dark", not bool(_arch.get("armed")), "armed = false")
			_stage = 5
		5:
			_check("and C drops you straight into the cinema",
				bool(_crossing.call("is_away")), "no invitation needed")
			_check("with the trip staged, so coming back is the real thing",
				int(_inv.get("_beat")) == 6 and not (_trym.get_node("Figure") as Node4D).visible,
				"door up, Trym through it - as if you had followed him")
			# OUT THROUGH THE DOOR, not by calling come_back(). This is the path actually
			# walked - in by the shortcut, out on foot - and testing the two halves
			# separately left it uncovered.
			var room2: Node = _root.get_node_or_null("Theatre")
			_check("the cinema is there to walk out of", room2 != null, "Theatre")
			if room2 != null:
				var way_out: Vector4 = (room2.get_node("ExitArch") as Node4D).global_position
				(room2.get_node("Player") as Node4D).global_position = way_out + Vector4(0.0, 1.2, 0.0, 0.0)
			_stage = 6
		6:
			if bool(_crossing.call("is_away")):
				return false
			_check("and walking out of it brings you home",
				not bool(_crossing.call("is_away")), "on foot, not by method call")
			_check("running the whole homecoming, not half of it",
				(_trym.get_node("Figure") as Node4D).visible
					and not bool(_arch.get("armed"))
					and bool(_root.get_node("Systems/TrymDriver").get("_owes_an_opinion")),
				"he is out here, the door is folding away, and he owes you an opinion")
			var home: Vector4 = (_root.get_node("Player") as Node4D).global_position
			_check("and puts you down where the door was",
				Vector2(home.x - _arch.global_position.x,
					home.z - _arch.global_position.z).length() < 2.5,
				"%.1f m from the doorway, not wherever C was pressed"
					% Vector2(home.x - _arch.global_position.x,
						home.z - _arch.global_position.z).length())
			# And back to square one, so the REAL invitation can be tested after it. The
			# shortcut marks the offer as made; without this the rest of the run waits
			# forever for a door that is never raised a second time.
			_inv.call("reset")
			_root.get_node("Systems/TrymDriver").call("reset")
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
			_check("the door went up in front of him",
				_arch.global_position.z > fig.z,
				"door at z %.1f, he is at z %.1f - on the way he was already walking"
					% [_arch.global_position.z, fig.z])
			_check("his tag came with him",
				absf((_root.get_node("World/TrymHead") as Node4D).global_position.z - fig.z) < 1.5,
				"TrymHead follows the figure")
			_stopped_at = fig.z
			_check("and he is waiting rather than leaving", _figure().visible,
				"he asked you to follow him, so he does not go without you")
			_stage = 15
		15:
			# He called you over and he will stand there until you come - so come. He only
			# goes through once somebody is near enough to follow him.
			var him: Vector4 = _figure().global_position
			_player.global_position = Vector4(him.x + 1.6, 1.2, him.z + 1.6, 0.0)
			# Straight after him, while he is still mid-stride, because that is what he
			# asked for and it is the case that used to come home to a door that never
			# shut and a Trym still switched off inside it.
			if int(_inv.get("_beat")) < 5:
				return false
			print("\n--- and goes through it ---")
			# Sampled while he is STILL WALKING, because that is when we follow him now -
			# so the question is not where he ended up but whether he ever went backwards.
			# The door being ahead of his stopping point is checked above; this catches the
			# about-face.
			_check("he carried straight on, never turning back",
				_figure().global_position.z >= _stopped_at - 0.3,
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
			# Through the doorway a metre off its middle - inside the opening, outside
			# the old circular trigger, and the reason walking out sometimes did
			# nothing at all.
			var door: Node4D = exit as Node4D
			var edge: Vector4 = door.global_basis * Vector4(1.0, 0.0, 0.0, 0.0)
			var out_at: Vector4 = door.global_position + edge + Vector4(0.0, 1.2, 0.0, 0.0)
			(room.get_node("Player") as Node4D).global_position = out_at
			_stage = 35
		35:
			if bool(_crossing.call("is_away")):
				return false
			_check("walking through it off-centre still counts", true,
				"a metre off the middle of a 2.2 m opening")
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
			_check("he came back out with you", _figure().visible
				and both > 0.8 and both < 4.5,
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
