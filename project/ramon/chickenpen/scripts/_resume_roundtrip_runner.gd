extends SceneTree

## The world written down, freed, loaded again and put back: pen_resume_4d.gd's round trip, the way
## the menu does it when a lab runs clean (Ramon, 10 Oct).
##
## PASS 1, THE FIELD. Load playable_world.tscn, let it settle, write down the fresh load (the
## baseline), then play at it through the game's own methods where they exist: a visit to the cave
## (a piece of gold dug out and pocketed, another knocked loose, the miner met), pickups taken
## through the collector (an egg, a bag of azoth, the watch), the keeper's gauntlet given through his
## dialogue's effect, talk flags and dialogue topics, discoveries, a feeder bought, two chickens
## caught and penned and a third carried and put down, Trym's invitation walked home, the player
## moved to another x, z and W with the slice turned, the dev / art look switched. Then capture,
## free the world (and its parked cave), set the discovery statics back to the fresh load's values
## (so only restore() can bring them back), load a fresh world, wait 2 frames, await restore(),
## capture again and compare key by key.
##
## PASS 2, THE CAVE. On the restored world: into the cave by the world's CaveCrossing go(), play a
## little in there, capture, free, reload, restore, compare - and check the player came back IN the
## cave, where they stood.
##
## Prints PASS key / FAIL key: before=... after=... and RESUME ROUNDTRIP: n pass, m fail. Two
## screenshots a pass (before the free, after the restore) to res://smoke_test_output/resume_roundtrip/
## when not headless. Bounded everywhere: every wait loop is capped, and the run quits by itself
## after 90 s of waiting (TIMED OUT). Writes nothing to user:// and saves no scene or resource.
##
## Run windowed small, unfocusable:
##   godot --path <project> --windowed --resolution 1280x720 --position 40,40 \
##     --script res://ramon/chickenpen/scripts/_resume_roundtrip_runner.gd

const Resume := preload("res://ramon/chickenpen/scripts/pen_resume_4d.gd")
const WORLD := "res://ramon/chickenpen/playable_world.tscn"
const OUT_DIR := "res://smoke_test_output/resume_roundtrip/"
const MAX_FRAMES := 600
## Waiting, not loading: the three synchronous loads are taken off the clock.
const WAIT_BUDGET_MS := 90000
## Per key prefix, how far apart two numbers (or positions) may be and still be the same. Things
## that walk about by themselves move a little in the frames between restore and the second capture.
const TOLERANCE := {"chickens/": 0.35, "mithra/": 0.35, "nike/": 0.35, "tutor/": 0.3}
const DEFAULT_TOLERANCE := 0.02
## How far apart two homes on one trough's rim can be (pen_upgrades_4d.gd: 1.2 by 0.75 round it).
const RIM := 2.5

var _start_ms: int = 0
var _loading_ms: int = 0
var _timed_out: bool = false
var _finished: bool = false
var _headless: bool = false
var _pass: int = 0
var _fail: int = 0
## The troughs of the capture being compared (see _same_entry).
var _troughs: Array = []


func _initialize() -> void:
	root.unfocusable = true
	root.gui_disable_input = true
	_headless = DisplayServer.get_name() == "headless"
	_start_ms = Time.get_ticks_msec()
	if not _headless:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run()


func _process(_delta: float) -> bool:
	# The rig captures the mouse in its _ready; this run never takes it.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _finished:
		return false
	if Time.get_ticks_msec() - _start_ms - _loading_ms > WAIT_BUDGET_MS:
		_timed_out = true
		_finished = true
		print("TIMED OUT after %d ms of waiting" % WAIT_BUDGET_MS)
		print("RESUME ROUNDTRIP: %d pass, %d fail (incomplete)" % [_pass, _fail + 1])
		quit(2)
		return true
	return false


func _run() -> void:
	# ---------------------------------------------------------------- pass 1: the field
	print("\n=== PASS 1: the field ===")
	var world: Node = _load_world()
	await _settle(world)
	if _timed_out:
		return
	var baseline: Dictionary = Resume.capture(world)
	await _play_in_the_field(world)
	if _timed_out:
		return
	await _frames(30)
	var before: Dictionary = Resume.capture(world)
	_report_changes(baseline, before)
	await _shot("pass1_before")
	await _free_world(world)
	_scrub_statics(baseline)
	world = _load_world()
	await _frames(2)
	var t0: int = Time.get_ticks_msec()
	var f0: int = Engine.get_process_frames()
	await Resume.restore(world, before)
	print("   restore took %d ms over %d frames" % [Time.get_ticks_msec() - t0, Engine.get_process_frames() - f0])
	if _timed_out:
		return
	var after: Dictionary = Resume.capture(world)
	_compare("field", before, after)
	_check_field(world, before)
	await _frames(10)
	await _shot("pass1_after")

	# ---------------------------------------------------------------- pass 2: the cave
	print("\n=== PASS 2: the cave ===")
	await _play_in_the_cave(world)
	if _timed_out:
		return
	await _frames(20)
	var before2: Dictionary = Resume.capture(world)
	await _shot("pass2_before")
	await _free_world(world)
	_scrub_statics(baseline)
	world = _load_world()
	await _frames(2)
	t0 = Time.get_ticks_msec()
	f0 = Engine.get_process_frames()
	await Resume.restore(world, before2)
	print("   restore took %d ms over %d frames" % [Time.get_ticks_msec() - t0, Engine.get_process_frames() - f0])
	if _timed_out:
		return
	var after2: Dictionary = Resume.capture(world)
	_compare("cave", before2, after2)
	_check_cave(world, before2)
	await _frames(10)
	await _shot("pass2_after")

	_finished = true
	print("\nRESUME ROUNDTRIP: %d pass, %d fail" % [_pass, _fail])
	print("   (%d ms loading, %d ms waiting)" % [_loading_ms, Time.get_ticks_msec() - _start_ms - _loading_ms])
	await _free_world(world)
	quit(0 if _fail == 0 else 1)


# ================================================================== playing

func _play_in_the_field(world: Node) -> void:
	var player: Node4D = world.get_node("Player")
	var rig: Node4D = world.get_node("Player/CameraRig")
	var belt: Node = world.get_node("UI/Inventory")

	# The keeper hands over the gauntlet, through his dialogue's own effect (the driver, the award
	# and the belt all hear it). Its reveal runs while the rest is played.
	world.get_node("Systems/Talk").emit_signal("effect", "give_gauntlet")

	# A visit to the cave: a piece of gold knocked loose and pocketed, another knocked loose and
	# left, the miner met and told of the strike, the first look had; then home, the cave parked.
	var cave_crossing: Node = world.get_node("CaveCrossing")
	cave_crossing.call("go")
	await _frames(6)
	var cave: Node = cave_crossing.get("_theatre")
	if cave == null:
		_fail_line("setup/cave visit", "the cave did not open")
	else:
		var gold: Node = cave.get_node("Gold")
		var orbs: Array = gold.get("_orbs")
		gold.call("_on_mined", (orbs[0] as Node4D).global_position, 0.3)
		gold.call("_on_mined", (orbs[3] as Node4D).global_position, 0.3)
		# Pocketed as gold _process does when you walk up to a loose piece.
		var found: Array = gold.get("_found")
		found[0] = true
		(orbs[0] as Node4D).visible = false
		belt.call("add_item", "found_azoth")
		var miner: Node = cave.get_node("Systems/MinerDriver")
		miner.call("_entry_node")
		miner.call("_note_mined")
		cave.set_meta(&"dreamer_met", true)
		world.set_meta(&"cave_first_look_said", true)
		await _frames(3)
		cave_crossing.call("come_back")
		await _frames(6)

	# Pickups through the collector, the way walking into them takes them.
	var collector: Node = world.get_node("Systems/Collector")
	for name in ["PenEggA", "AzothBag1", "PocketWatch"]:
		collector.call("_take", world.get_node("World/Pickups/" + name))
	belt.call("add_item", "found_egg")
	belt.call("_choose", 1)

	# Talk flags, through the drivers' own methods.
	world.get_node("Systems/TalkDriver").call("_entry_node")
	world.get_node("Systems/MithraTalk").emit_signal("effect", "watch_hinted")
	world.get_node("Systems/MithraDriver").call("_entry_node")
	world.get_node("Systems/MithraDriver").call("gave_a_chicken")
	world.get_node("Systems/NikeGrab").call("unlock")
	world.get_node("Systems/ProfessorDriver").call("_entry_node")
	world.get_node("Systems/ProfessorDriver").call("note_mined")
	world.get_node("Systems/RangeMasterDriver").call("_entry_node")
	world.get_node("Systems/CampGuideDriver").call("_entry_node")
	world.get_node("Systems/CrowLine").set("_said", true)
	world.get_node("World/WDoor").set("_used_once", true)
	# Dialogue topics and flags.
	world.get_node("Systems/Talk").call("set_flag", "resume_test", true)
	(world.get_node("Systems/TrymTalk").get("_visited") as Dictionary)["offer"] = true
	world.get_node("Systems/MithraTalk").set("_asked_any", true)

	# Discoveries (statics, as the finds set them), and the cache's chest gone as its opening ends.
	_static("res://ramon/chickenpen/discovery/pen_kata_cache_4d.gd", "found", true)
	var chest: Node4D = world.get_node("World/KataCache").get("_chest")
	if chest != null:
		chest.visible = false
	_static("res://ramon/chickenpen/discovery/pen_wall_pivot_4d.gd", "shown", true)
	_static("res://ramon/chickenpen/discovery/pen_meadow_thought_4d.gd", "said", true)
	var guide: GDScript = load("res://ramon/chickenpen/discovery/pen_w_guide_4d.gd")
	(guide.get("uses") as Dictionary)["step"] = 3
	(guide.get("done") as Dictionary)["kata_cache"] = true
	_static("res://ramon/chickenpen/discovery/dream_shifter/pen_look_guide_4d.gd", "seen", true)
	_static("res://ramon/chickenpen/discovery/pen_balloon_crew_talk_4d.gd", "met", true)
	_static("res://ramon/chickenpen/lookout/balloon_4d.gd", "found", true)
	_static("res://ramon/chickenpen/lookout/balloon_4d.gd", "ticket", true)
	(load("res://ramon/chickenpen/scripts/pen_quests_4d.gd") as GDScript).call("mark_visited", "range")
	(world.get_node("Systems/Tutor").get("_shown") as Dictionary)["ana"] = true
	var network: Node = world.get_node_or_null("World/Paths")
	if network != null and "_found" in network:
		(network.get("_found") as Dictionary)[0] = Vector2(0.0, 5.0)

	# A trough off the keeper (one azoth).
	if not bool(world.get_node("Pen/Upgrades").call("buy", "feeder")):
		_fail_line("setup/feeder", "could not buy a feeder")

	# Two chickens caught and penned, a third carried and put down in the field.
	var manager: Node = world.get_node("Chickens")
	var agents: Array = manager.get("agents")
	var pen: Node4D = world.get_node("Pen")
	var spots: Array = [Vector4(1.8, 0.0, -1.6, 0.0), Vector4(1.6, 0.0, 1.5, 0.0)]
	for i in 2:
		var agent: Node = agents[i]
		agent.call("on_caught")
		agent.call("on_released")
		(agent.get_parent() as Node4D).position = pen.position + spots[i]
		agent.call("on_landed", true)
		manager.call("note_returned", agent)
	var loose: Node = agents[2]
	loose.call("on_caught")
	loose.call("on_released")
	var loose_home: Vector4 = loose.get("home_position")
	(loose.get_parent() as Node4D).position = loose_home + Vector4(1.2, 0.0, 0.8, 0.0)
	loose.call("on_landed", false)

	# Trym's invitation, walked home (the debug key's staging, then the real homecoming).
	var invite: Node = world.get_node("Invitation")
	invite.call("stage_as_if_followed")
	invite.call("rearm")
	await _frames(10)

	# The look switched.
	var look: Node = world.get_node("Systems/Look")
	look.call("set_dev", not bool(look.get("dev")))

	# Somewhere else, at another W, with the slice turned and the camera moved.
	player.position = Vector4(20.0, 1.0, 24.0, 1.3)
	player.set("linear_velocity", Vector4.ZERO)
	player.set("_facing", 0.9)
	rig.set("yaw", 2.2)
	rig.call("drag_slice", Vector2(deg_to_rad(32.0), deg_to_rad(-9.0)))
	rig.set("pitch", deg_to_rad(-21.0))
	rig.set("_zoom_target", 6.4)
	rig.call("_apply")

	# The gauntlet has had its reveal by now; wait for it to be on the arm (bounded).
	var award: Node = world.get_node("Systems/GauntletAward")
	var waited: int = 0
	while waited < MAX_FRAMES and int(award.get("stage")) != 3 and not _timed_out:
		await create_timer(0.03).timeout
		waited += 1
	if int(award.get("stage")) != 3:
		_fail_line("setup/gauntlet", "never reached the arm (stage %d)" % int(award.get("stage")))


func _play_in_the_cave(world: Node) -> void:
	var player: Node4D = world.get_node("Player")
	var rig: Node4D = world.get_node("Player/CameraRig")
	var cave_crossing: Node = world.get_node("CaveCrossing")
	var kept: Variant = cave_crossing.get("_kept")
	print("   the parked cave is %s" % ("there" if kept is Node and is_instance_valid(kept) else "MISSING"))
	cave_crossing.call("go")
	await _frames(6)
	var cave: Node4D = cave_crossing.get("_theatre")
	if cave == null:
		_fail_line("setup/cave", "the cave did not open")
		return
	var gold: Node = cave.get_node("Gold")
	var orbs: Array = gold.get("_orbs")
	gold.call("_on_mined", (orbs[4] as Node4D).global_position, 0.3)
	var miner: Node = cave.get_node("Systems/MinerDriver")
	miner.call("_note_mined")
	miner.call("_entry_node")
	cave.set_meta(&"dreamer_told_strike", true)
	cave.get_node("Systems/MinerTalk").call("set_flag", "resume_cave_test", true)
	world.get_node("UI/Inventory").call("add_item", "found_azoth")
	# Down the corridor towards the chamber, a little ana, the slice turned less than the far room's
	# 12 degrees (it streams in past that and forgets its own talk when it goes).
	player.position = cave.global_position + cave.global_basis * Vector4(0.6, 0.05, -24.5, 0.4)
	player.set("linear_velocity", Vector4.ZERO)
	player.set("_facing", -0.4)
	rig.basis = GroundBasis4D.sliced(Basis4D.from_zx(deg_to_rad(15.0)), Vector2(-deg_to_rad(9.0), 0.0))
	rig.set("pitch", deg_to_rad(6.0))
	rig.set("_zoom_target", 4.2)
	rig.call("_apply")


# ================================================================== checking

func _compare(label: String, before: Dictionary, after: Dictionary) -> void:
	_troughs = (before.get("feeders", {}) as Dictionary).get("at", [])
	var a: Dictionary = _flatten(before)
	var b: Dictionary = _flatten(after)
	var keys: Array = a.keys()
	for k in b.keys():
		if not keys.has(k):
			keys.append(k)
	keys.sort()
	for k in keys:
		var key: String = "%s/%s" % [label, k]
		if not a.has(k):
			_fail_line(key, "before=<missing> after=%s" % _short(b[k]))
		elif not b.has(k):
			_fail_line(key, "before=%s after=<missing>" % _short(a[k]))
		elif _same_entry(String(k), a[k], b[k]):
			_pass_line(key)
		else:
			_fail_line(key, "before=%s after=%s" % [_short(a[k]), _short(b[k])])


## A chicken near a trough has its home rewritten every frame by the trough's gather loop
## (pen_upgrades_4d.gd _process), at a spot on the trough's rim picked from the agent's instance id -
## which a reloaded bird does not share. So that home is compared within the rim (2.5 m across), and
## everything else about the bird as usual.
func _same_entry(key: String, a: Variant, b: Variant) -> bool:
	if key.begins_with("chickens/") and a is Dictionary and b is Dictionary:
		var x: Dictionary = (a as Dictionary).duplicate()
		var y: Dictionary = (b as Dictionary).duplicate()
		var home_ok: bool = _same(x.get("home"), y.get("home"), _tolerance(key)) 			or (_by_trough(x.get("home")) and _by_trough(y.get("home")) and _same(x.get("home"), y.get("home"), RIM))
		x.erase("home")
		y.erase("home")
		return home_ok and _same(x, y, _tolerance(key))
	return _same(a, b, _tolerance(key))


## On a trough's rim (within 2 m of one, flat).
func _by_trough(home: Variant) -> bool:
	if not (home is Vector4):
		return false
	for spot in _troughs:
		var gap: Vector4 = (home as Vector4) - (spot as Vector4)
		if Vector2(gap.x, gap.z).length() <= 2.0:
			return true
	return false


## What play changed, against the fresh load: the round trip proves nothing about keys play left alone.
func _report_changes(baseline: Dictionary, played: Dictionary) -> void:
	var a: Dictionary = _flatten(baseline)
	var b: Dictionary = _flatten(played)
	var changed: Array = []
	for k in b:
		if not a.has(k) or not _same_entry(String(k), a[k], b[k]):
			changed.append(k)
	changed.sort()
	print("   play changed %d of %d keys: %s" % [changed.size(), b.size(), ", ".join(changed)])


## What the data cannot say about itself: the world's nodes after a restore.
func _check_field(world: Node, before: Dictionary) -> void:
	var chest: Node4D = world.get_node("World/KataCache").get("_chest")
	_check("field/check/kata chest hidden", chest != null and not chest.visible)
	var taken_ok: bool = true
	for name in (before["pickups"]["taken"] as Array):
		var item: Node4D = world.get_node("World/Pickups/" + String(name))
		taken_ok = taken_ok and not item.visible and not item.is_processing()
	_check("field/check/pickups hidden and stopped", taken_ok and not (before["pickups"]["taken"] as Array).is_empty())
	var award: Node = world.get_node("Systems/GauntletAward")
	_check("field/check/gauntlet model on the arm", award.get("_worn") != null)
	var troughs: int = world.get_node("Pen/Upgrades").get_child_count()
	_check("field/check/feeders built (%d)" % troughs, troughs == (before["feeders"]["at"] as Array).size() and troughs > 0)
	var progress: Label = world.get_node("UI/Progress")
	_check("field/check/progress label '%s'" % progress.text, progress.text.begins_with("Chickens returned: 2/"))
	var crossing: Node = world.get_node("CaveCrossing")
	var kept: Variant = crossing.get("_kept")
	var kept_ok: bool = kept is Node and is_instance_valid(kept) and not (kept as Node).is_inside_tree()
	_check("field/check/visited cave parked out of the tree", kept_ok)
	if kept_ok:
		var found: Array = (kept as Node).get_node("Gold").get("_found")
		_check("field/check/parked cave's gold dug out", bool(found[0]))
	_check("field/check/not in the cave", not bool(crossing.call("is_away")))


func _check_cave(world: Node, before: Dictionary) -> void:
	var crossing: Node = world.get_node("CaveCrossing")
	_check("cave/check/player back IN the cave", bool(crossing.call("is_away")))
	var player: Node4D = world.get_node("Player")
	var want: Vector4 = before["player"]["position"]
	_check("cave/check/player where they stood (%.3f m off)" % (player.position - want).length(), (player.position - want).length() < 0.1)
	var cave: Node = crossing.get("_theatre")
	_check("cave/check/one cave, under the world", cave != null and cave.get_parent() == world)
	var bounds: Node = world.get_node("Systems/Bounds")
	_check("cave/check/the field's bounds asleep", bounds.process_mode == Node.PROCESS_MODE_DISABLED)


func _check(key: String, ok: bool) -> void:
	if ok:
		_pass_line(key)
	else:
		_fail_line(key, "not so")


func _pass_line(key: String) -> void:
	_pass += 1
	print("PASS %s" % key)


func _fail_line(key: String, why: String) -> void:
	_fail += 1
	print("FAIL %s: %s" % [key, why])


## Top-level sections split one level, so each driver, chicken and dialogue is its own key.
func _flatten(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in data:
		var v: Variant = data[k]
		if v is Dictionary and not (v as Dictionary).is_empty():
			for k2 in v:
				out["%s/%s" % [k, k2]] = v[k2]
		else:
			out[str(k)] = v
	return out


func _tolerance(key: String) -> float:
	for prefix in TOLERANCE:
		if key.begins_with(String(prefix)):
			return float(TOLERANCE[prefix])
	return DEFAULT_TOLERANCE


func _same(a: Variant, b: Variant, tol: float, depth: int = 0) -> bool:
	if depth > 24:
		return false
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if ta in [TYPE_INT, TYPE_FLOAT] and tb in [TYPE_INT, TYPE_FLOAT]:
		return absf(float(a) - float(b)) <= tol
	if ta != tb:
		return false
	match ta:
		TYPE_VECTOR4:
			return ((a as Vector4) - (b as Vector4)).length() <= tol
		TYPE_VECTOR2:
			return ((a as Vector2) - (b as Vector2)).length() <= tol
		TYPE_PROJECTION:
			var p: Projection = a
			var q: Projection = b
			return (p.x - q.x).length() <= tol and (p.y - q.y).length() <= tol \
				and (p.z - q.z).length() <= tol and (p.w - q.w).length() <= tol
		TYPE_ARRAY:
			var x: Array = a
			var y: Array = b
			if x.size() != y.size():
				return false
			for i in x.size():
				if not _same(x[i], y[i], tol, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			var x: Dictionary = a
			var y: Dictionary = b
			if x.size() != y.size():
				return false
			for k in x:
				if not y.has(k) or not _same(x[k], y[k], tol, depth + 1):
					return false
			return true
		_:
			return a == b


func _short(v: Variant) -> String:
	var s: String = str(v)
	return s if s.length() <= 300 else s.substr(0, 300) + "..."


# ================================================================== the world

func _load_world() -> Node:
	var t0: int = Time.get_ticks_msec()
	var packed: PackedScene = load(WORLD) as PackedScene
	var world: Node = packed.instantiate()
	root.add_child(world)
	current_scene = world
	var took: int = Time.get_ticks_msec() - t0
	_loading_ms += took
	print("   loaded the world in %d ms" % took)
	return world


## Until the game's _ready (and its reset sweep) has run, then a little more (bounded).
func _settle(world: Node) -> void:
	var game: Node = world.get_node_or_null("Systems/Game")
	var waited: int = 0
	while waited < MAX_FRAMES and not _timed_out and (game == null or not game.is_node_ready()):
		await process_frame
		waited += 1
	await _frames(20)


## Out of the tree and freed, with the cave the crossing may have parked (as the laptop trip does).
func _free_world(world: Node) -> void:
	if world == null or not is_instance_valid(world):
		return
	Resume.clear_root_leftovers(self)
	var crossing: Node = world.get_node_or_null("CaveCrossing")
	if crossing != null:
		var kept: Variant = crossing.get("_kept")
		if kept is Node and is_instance_valid(kept) and not (kept as Node).is_inside_tree():
			(kept as Node).free()
	root.remove_child(world)
	world.queue_free()
	await _frames(3)


## The discovery statics back to the fresh load's values, so the reload cannot inherit them.
func _scrub_statics(baseline: Dictionary) -> void:
	var statics: Dictionary = baseline.get("statics", {})
	for path in statics:
		var script: GDScript = load(String(path)) as GDScript
		if script == null:
			continue
		for name in statics[path]:
			var value: Variant = statics[path][name]
			script.set(String(name), value.duplicate(true) if (value is Dictionary or value is Array) else value)


func _static(path: String, name: String, value: Variant) -> void:
	(load(path) as GDScript).set(name, value)


func _frames(n: int) -> void:
	for i in mini(n, MAX_FRAMES):
		if _timed_out:
			return
		await process_frame


func _shot(name: String) -> void:
	if _headless or _timed_out:
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		print("   no image for %s" % name)
		return
	var path: String = OUT_DIR + name + ".png"
	image.save_png(path)
	print("   saved %s" % path)
