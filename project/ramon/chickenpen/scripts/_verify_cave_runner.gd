extends SceneTree

## Into the hill and back out, the way play does it, checking that nothing is lost.
##
## The player is put in the bore at the back of the cave mouth and left for the hill's own
## trigger to fire; then the cave has to be there with the field switched off and the
## player standing in it; the walls have to hold; the miner has to be talkable; a blow on
## the monolith has to bring gold out and gold has to reach the belt; the daylight has to
## bring you home, facing out, with the field back; and the hill has to work a second time.
## Headless.

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const QUESTS := preload("res://ramon/chickenpen/scripts/pen_quests_4d.gd")
## Words only the researchers' after-the-blow, up-close lines use.
const ADDRESS_AFTER_WORDS := ["colliders", "milliseconds", "data"]

var _room: Node
var _f := 0
var _fails := 0
var _step := 0
var _wait := 0
var _cave: Node4D
var _gold_before := 0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-52s %s" % ["PASS" if ok else "FAIL", what, detail])


func _player() -> CharacterBody4D:
	return _room.get_node("Player") as CharacterBody4D


func _find_cave() -> Node4D:
	for child in _room.get_children():
		if child.name == "Cave":
			return child as Node4D
	return null


func _gold_count() -> int:
	return int(_room.get_node("UI/Inventory").call("count_of", "found_gold"))


func _hold(at: Vector4) -> void:
	var p := _player()
	p.global_position = at
	p.linear_velocity = Vector4.ZERO


## Waits are counted in DRAWN frames. A slow headless frame catches up with several physics
## ticks in a row, so a wait counted in ticks could run out before anything's _process -
## the researchers' lines, the gold pickup - had seen the move it was waiting on. Flaky
## that way: the same check passed and failed on alternate runs.
func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
	return false


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f < 10:
		return false
	if _wait > 0:
		return false
	var hill = CaveHill.new()
	match _step:
		0:
			# Into the bore, where the hill's trigger is.
			var way: Array = hill.way_in()
			_hold(way[0] - Vector4(0.0, 1.2, 0.0, 0.0))
			_step = 1
			_wait = 10
		1:
			_cave = _find_cave()
			_check("walking into the bore opens the cave", _cave != null)
			if _cave == null:
				return _done()
			var world: Node4D = _room.get_node("World")
			_check("and switches the field off", not world.visible and world.process_mode == Node.PROCESS_MODE_DISABLED)
			var local: Vector4 = _player().global_position - _cave.global_position
			_check("the pen's own player is standing in it", local.length() < 3.0, "at %s in the cave" % local)
			_check("the quest line for the hill ticks", QUESTS._visited.has("cave"))
			var bounds: Node = _room.get_node("Systems/Bounds")
			_check("the field's own bounds are asleep", bounds.process_mode == Node.PROCESS_MODE_DISABLED)
			# Walk into a wall: stand well inside the rock beside the corridor.
			_hold(_cave.global_position + Vector4(6.0, 0.05, -14.0, 0.0))
			_step = 2
			_wait = 3
		2:
			var local: Vector4 = _player().global_position - _cave.global_position
			_check("the walls hold", absf(local.x) < 3.2, "pushed back to x %.2f" % local.x)
			# Walk right up to the surveyor.
			var surveyor: Node4D = _cave.get_node("SurveyorHead")
			_hold(Vector4(surveyor.global_position.x + 1.2, 0.05, surveyor.global_position.z + 1.2, surveyor.global_position.w))
			_step = 20
			_wait = 3
		20:
			var said: String = String(_cave.get_node("UI/SurveyorTag").get("_text"))
			var gap: Vector4 = _cave.get_node("SurveyorHead").global_position - _player().global_position
			_check("up close, a researcher asks you not to touch anything", said.contains("touch") or said.contains("tripod") or said.contains("line of sight"), "\"%s\"  (%.2f m away)" % [said, Vector2(gap.x, gap.z).length()])
			# Stand by the miner.
			var head: Node4D = _cave.get_node("MinerHead")
			_hold(Vector4(head.global_position.x - 0.6, 0.05, head.global_position.z + 1.6, head.global_position.w))
			_step = 3
			_wait = 3
		3:
			var driver: Node = _cave.get_node("Systems/MinerDriver")
			_check("the miner can be talked to", bool(driver.call("_can_talk")))
			# A blow on the monolith where a piece of gold sits.
			var gold: Node = _cave.get_node("Gold")
			var orbs: Array = gold.get("_orbs")
			var orb: Node4D = orbs[0]
			var pick: Node = _room.get_node("Systems/Pickaxe")
			_gold_before = _gold_count()
			var was: Vector4 = orb.global_position
			pick.emit_signal("mined", was, 0.6)
			_check("a blow on the seam brings gold out", orb.visible)
			_check("and it stays where the blow landed", orb.global_position.distance_to(was) < 0.01, "%.2f m off" % orb.global_position.distance_to(was))
			var murmurs: Node = _cave.get_node("Systems/Murmurs")
			_check("the researchers panic at the blow", bool(murmurs.call("is_panicking")) and float(_cave.get_node("Sampler").get("_panic")) > 0.0)
			# In play a revealed piece is knocked out to where the blow landed, on the slab's
			# face. The blow here was struck at the piece itself, inside the slab, so it is
			# brought out to the front of the plinth by hand - standing a body inside the
			# slab's own colliders gets it thrown hundreds of metres by the depenetration.
			var stand: Vector4 = _cave.global_position + Vector4(0.0, 1.55, -36.0 + 1.9, 0.0)
			_hold(stand)
			# Through its parent, not global_position: see _place_global in the gold script.
			var parent: Node4D = orb.get_parent()
			orb.position = parent.global_basis.inverse() * (stand + Vector4(0.0, 0.8, -0.4, 0.0) - parent.global_position)
			_step = 4
			_wait = 2
		4:
			var orb: Node4D = (_cave.get_node("Gold").get("_orbs") as Array)[0]
			var gap: float = (orb.global_position - _player().global_position).length()
			_check("and walking into it puts it on the belt", _gold_count() > _gold_before, "%d -> %d  (%.2f m from it, visible %s)" % [_gold_before, _gold_count(), gap, orb.visible])
			_check("the miner knows it was struck", bool(_cave.get_node("Systems/MinerDriver").get("_struck")))
			# Let them calm down, then walk up to the one with the tablet.
			_cave.get_node("Systems/Murmurs").set("_panic", 0.0)
			var reader: Node4D = _cave.get_node("ReaderHead")
			_hold(Vector4(reader.global_position.x + 1.2, 0.05, reader.global_position.z + 1.3, reader.global_position.w))
			_step = 42
			_wait = 3
		42:
			var said: String = String(_cave.get_node("UI/ReaderTag").get("_text"))
			_check("afterwards, up close, they admit the data was good", ADDRESS_AFTER_WORDS.any(func(w): return said.contains(w)) and not said.contains("%"), "\"%s\"" % said)
			# Out through the daylight.
			var exit: Node4D = _cave.get_node("ExitArch")
			_hold(exit.global_position + Vector4(0.0, 0.05, -0.6, 0.0))
			_step = 5
			_wait = 8
		5:
			_check("the daylight takes you home", _find_cave() == null or _find_cave().is_queued_for_deletion())
			var world: Node4D = _room.get_node("World")
			_check("with the field back on", world.visible and world.process_mode == Node.PROCESS_MODE_INHERIT)
			var p := _player()
			var mouth_z: float = CaveHill.MOUTH.z
			_check("set down in the mouth of the cave", absf(p.global_position.x - CaveHill.MOUTH.x) < 3.0 and p.global_position.z > mouth_z - 6.5 and p.global_position.z < mouth_z + 1.0, "at %s" % p.global_position)
			var yaw: float = float(_room.get_node("Player/CameraRig").get("yaw"))
			_check("facing out of the hill", absf(angle_difference(yaw, PI)) < 0.2, "yaw %.2f" % yaw)
			_check("and the gold came home with you", _gold_count() > _gold_before)
			# And again.
			var way: Array = hill.way_in()
			_hold(way[0] - Vector4(0.0, 1.2, 0.0, 0.0))
			_step = 6
			_wait = 10
		6:
			_check("the hill works a second time", _find_cave() != null)
			return _done()
	return false


func _done() -> bool:
	print("\n%d FAIL(s)" % _fails)
	quit(1 if _fails > 0 else 0)
	return true
