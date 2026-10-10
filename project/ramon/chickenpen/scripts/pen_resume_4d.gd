extends RefCounted

## Writes the playable world down as plain data and puts it back on a freshly loaded copy, so a
## player who left it continues where they were, with what they had done.
##
## WHY IT EXISTS: LABS RUN CLEAN (Ramon, 10 Oct: "we are testing performance too"). While a lab
## launched from the menu runs, the world is not held in memory any more: it is freed, and loaded
## again from playable_world.tscn when the player returns to it. Everything a fresh load resets has
## to come back from here. Callers preload or load this file (no class_name).
##
## THE CALL CONTRACT
##   - capture(world): while the world is still IN the tree, just before it is taken out. Returns a
##     Dictionary of plain data only (bools, ints, floats, strings, Vector4, Projection, arrays and
##     dictionaries of those). Nothing in it refers to a node, so it outlives the world.
##   - clear_root_leftovers(tree): any time before the world is loaded again (the laptop trip calls
##     it at capture time). Removes root metas that would make a reload misbehave.
##   - await restore(world, data): on a FRESH instance of playable_world.tscn that is in the tree,
##     is the tree's current scene (the cave's crossing adds the cave to current_scene), and whose
##     _ready has run; wait 2 process frames after adding it, then AWAIT this - it is a coroutine
##     (it waits for the reset sweep if it has not run yet, one frame for the cave to build when the
##     player was in it, and one physics frame to settle the player). It takes at most a few frames.
##     Every item is guarded: a node or property that is missing only skips that item, with a
##     push_warning, and never stops the rest.
##
## WHAT IS WRITTEN DOWN AND PUT BACK
##   - Where you were: the player's x, y, z and W, the avatar's facing (its stance frame), the
##     camera rig's frame (heading and the slice it cuts, its w column), pitch, zoom, framing preset.
##   - Which place you were in: the cave (re-entered through the world's own CaveCrossing.go(), then
##     put back where you stood, with the spot it will send you home to); the theatre is a show and
##     is not re-entered - you come back where walking out of it would have put you, with Trym's
##     homecoming as the walk out would have staged it.
##   - The belt: items, stack counts, the slot in hand.
##   - Pickups taken (hidden, stopped, the way the collector leaves them; the egg tally reads them).
##   - The flock: per chicken id, home, position, returned, ever carried; penned birds re-penned
##     standing, the count and the finished state (completion line, locator off, the party) put back
##     without the confirm sound, the chorus or the confetti.
##   - Feeders bought (rebuilt with their signal held, so no blip and no Nike dash), the gauntlet
##     worn, the keeper's locator gate, Trym's invitation (waiting, back home with him beside the
##     door, or - if you left mid-errand - the errand started again from his first line).
##   - Quest and talk flags of every talk driver, Nike's carry unlock, the tutor's spent hints, the
##     crow line, the W door, the opening line, and every DialoguePlayer4D's visited topics, flags
##     and asked-any, found by what they can do, keyed by path.
##   - Discoveries kept in statics (which the load's reset sweep clears, so they are set again after
##     it): the kata cache (and its chest hidden), the wall pivot, the meadow thought, the W guide's
##     uses, spent and done, the look guide's seen, praised and switched, the balloon found and its
##     ticket, the balloon crew met and flown, the places visited (cave, range).
##   - Mithra's and Nike's spot (not while Nike is in your arms), the dev or art look, the path
##     network's revealed stretches, data metas on the world root (cave_first_look_said and the like).
##   - The cave: its gold (found, and revealed pieces where they were knocked loose), the miner's
##     flags, its dialogue, its root metas (dreamer_met, dreamer_told_strike, dreamer_skip_refused).
##     Restored whether you were in it, or had visited it and left (then it is built again and parked
##     out of the tree in CaveCrossing._kept, exactly as the crossing parks it).
##
## KNOWN LIMITATIONS
##   - The cave's monolith comes back whole: voxel carves have no carve-at-point API to replay. Gold
##     that had been revealed but not picked up comes back where it was knocked loose.
##   - Left as a fresh load has them (safe to reset): HUD toggles, prompts, anything carried (a
##     carried chicken goes back to where it lives, the cat and Nike are put down), cinematics,
##     raids, balloon rides, the theatre show, the wolf raid timer, ambient animation, the far room
##     of the cave (it streams itself, and forgets its own talk when it unloads anyway), confetti.
##     The lookout journal and the outfit are already saved to disk by the game.
##   - A bird near a trough has its home rewritten every frame by the trough (pen_upgrades_4d.gd), at
##     a rim spot picked from its instance id, so after a reload it may stand at another spot on the
##     same trough's rim.
##   - Building the cave costs a stall in restore's frames, as walking in does: measured about 0.3 s
##     to rebuild a parked cave and about 1 s to re-enter it (10 Oct, Ramon's PC).
##   - A visited cave left parked in CaveCrossing._kept is never freed by freeing the world (it is
##     out of the tree, so nothing reaches it). The caller frees it (pen_laptop_trip_4d.gd
##     _free_world does); this file does not change pen_crossing_4d.gd.

const VERSION := 1
const WORLD_PATH := "res://ramon/chickenpen/playable_world.tscn"
## Frames restore() will wait for the world's _ready and reset sweep before giving up the wait.
const SETTLE_CAP := 600
## Nodes walked when looking for dialogue players, at most.
const WALK_CAP := 200000

## Talk drivers and the like whose plain flags are all there is to them, by path from the world root.
const FLAGS := {
	"Systems/TalkDriver": ["_met", "_has_gauntlet"],
	"Systems/TrymDriver": ["_met", "_owes_an_opinion", "_shown_it", "_heard_opinion", "_gave_ticket"],
	"Systems/MithraDriver": ["_hinted", "_gave_watch", "_gave_clock", "_gifted", "_met"],
	"Systems/NikeDriver": ["_met"],
	"Systems/NikeGrab": ["unlocked"],
	"Systems/ProfessorDriver": ["_met", "_carved"],
	"Systems/RangeMasterDriver": ["_met"],
	"Systems/CampGuideDriver": ["_met"],
	"Systems/CrowLine": ["_said"],
	"World/WDoor": ["_used_once"],
}

## Discoveries held in static vars (a reload keeps statics, but the reset sweep clears these).
const STATICS := {
	"res://ramon/chickenpen/discovery/pen_kata_cache_4d.gd": ["found"],
	"res://ramon/chickenpen/discovery/pen_wall_pivot_4d.gd": ["shown"],
	"res://ramon/chickenpen/discovery/pen_meadow_thought_4d.gd": ["said"],
	"res://ramon/chickenpen/discovery/pen_w_guide_4d.gd": ["uses", "spent", "done"],
	"res://ramon/chickenpen/discovery/dream_shifter/pen_look_guide_4d.gd": ["seen", "praised", "switched"],
	"res://ramon/chickenpen/discovery/pen_balloon_crew_talk_4d.gd": ["met", "flown"],
	"res://ramon/chickenpen/lookout/balloon_4d.gd": ["found", "ticket"],
	"res://ramon/chickenpen/scripts/pen_quests_4d.gd": ["_visited"],
}

## The cave's own flags, by path from the cave's root.
const CAVE_FLAGS := {
	"Systems/MinerDriver": ["_met", "_struck", "_remarked"],
}

## Root metas a reload must not find: a cinematic request the new world would play on arrival.
const ROOT_LEFTOVERS: Array[StringName] = [&"pen_cinematic", &"pen_cinematic_return"]


# ================================================================== capture

## Everything worth keeping, as plain data. Call while [param world] is still in the tree.
static func capture(world: Node) -> Dictionary:
	if world == null or not is_instance_valid(world):
		push_warning("PenResume: no world to write down.")
		return {}
	var data: Dictionary = {"version": VERSION, "scene": String(world.scene_file_path)}
	var place: Dictionary = _capture_place(world)
	data["place"] = place
	data["player"] = _capture_player(world, place)
	data["rig"] = _capture_rig(world)
	data["inventory"] = _capture_inventory(world)
	data["pickups"] = _capture_pickups(world)
	data["chickens"] = _capture_chickens(world)
	data["game"] = _capture_game(world)
	data["feeders"] = _capture_feeders(world)
	data["gauntlet"] = _capture_gauntlet(world)
	data["flags"] = _capture_flags(world, FLAGS)
	data["statics"] = _capture_statics()
	data["dialogue"] = _capture_dialogue(world, _skipped_subtrees(world))
	data["invitation"] = _capture_invitation(world, place, data["flags"])
	data["mithra"] = _capture_mithra(world)
	data["nike"] = _capture_nike(world)
	data["look"] = _capture_look(world)
	data["tutor"] = _capture_tutor(world)
	data["paths"] = _capture_paths(world)
	data["root_metas"] = _capture_metas(world)
	data["cave"] = _capture_cave(world)
	return data


## Which place the player is in: the cave, the theatre, or the field.
static func _capture_place(world: Node) -> Dictionary:
	var place: Dictionary = {"cave": false, "theatre": false}
	var cave_crossing: Node = world.get_node_or_null(^"CaveCrossing")
	if cave_crossing != null and cave_crossing.has_method("is_away"):
		place["cave"] = bool(cave_crossing.call("is_away"))
		place["cave_was_at"] = _read(cave_crossing, "_was_at", Vector4.ZERO)
		place["cave_testing"] = bool(_read(cave_crossing, "_testing_trip", false))
	elif cave_crossing == null:
		push_warning("PenResume: no CaveCrossing, so which place you were in is not written down.")
	var crossing: Node = world.get_node_or_null(^"Crossing")
	if crossing != null and crossing.has_method("is_away") and bool(crossing.call("is_away")):
		# The theatre is a show and is not re-entered: home is where walking out of it puts you
		# (pen_crossing_4d.gd come_back), in the player's parent's frame.
		place["theatre"] = true
		var was: Vector4 = _read(crossing, "_was_at", Vector4.ZERO)
		var back: Vector4 = was
		if not bool(_read(crossing, "_testing_trip", false)):
			var offset: Vector4 = _read(crossing, "return_offset", Vector4(0.0, 0.0, 1.6, 0.0))
			var frame_path: NodePath = _read(crossing, "return_frame_path", NodePath())
			var frame: Node4D = crossing.get_node_or_null(frame_path) as Node4D if not frame_path.is_empty() else null
			back = was + (frame.global_basis * offset if frame != null else offset)
		place["theatre_return"] = back
	return place


static func _capture_player(world: Node, place: Dictionary) -> Dictionary:
	var player: Node4D = _node(world, "Player", "the player") as Node4D
	if player == null:
		return {}
	var out: Dictionary = {"position": player.position}
	if bool(place.get("theatre", false)):
		out["position"] = _to_parent_frame(player, place["theatre_return"])
	var stance: Variant = _read(player, "_stance", null)
	if stance is Projection:
		out["stance"] = stance
	return out


static func _capture_rig(world: Node) -> Dictionary:
	var rig: Node4D = _node(world, "Player/CameraRig", "the camera rig") as Node4D
	if rig == null:
		return {}
	# Mid-conversation the zoom target is the talk framing; what the player had is the rest distance.
	var talking: bool = bool(_read(rig, "_talking", false))
	var zoom: float = float(_read(rig, "_rest_distance" if talking else "_zoom_target", _read(rig, "distance", 5.0)))
	return {
		"basis": rig.basis,
		"pitch": float(_read(rig, "pitch", -0.15)),
		"zoom": zoom,
		"pivot": float(_read(rig, "_home_pivot", _read(rig, "pivot_height", 1.1))),
		"preset": int(_read(rig, "preset", 0)),
	}


static func _capture_inventory(world: Node) -> Dictionary:
	var belt: Node = _node(world, "UI/Inventory", "the belt")
	if belt == null:
		return {}
	return {
		"items": _read(belt, "items", []),
		"counts": _read(belt, "counts", {}),
		"selected": int(_read(belt, "selected", -1)),
	}


## The pickups the collector has taken: hidden and stopped (pen_collector_4d.gd _take).
static func _capture_pickups(world: Node) -> Dictionary:
	var pickups: Node = _node(world, "World/Pickups", "the pickups")
	if pickups == null:
		return {}
	var taken: Array = []
	for node in pickups.get_children():
		var item: Node4D = node as Node4D
		if item != null and ("kind" in item) and not item.visible:
			taken.append(String(item.name))
	taken.sort()
	return {"taken": taken}


## Per chicken id: where it lives, where it is, whether it is home and whether it was ever carried.
##
## The state is written as what restore() will make of it, not the moment's mood: a bird at home is
## PENNED (one on its way to the coop, in it or on its roof is put back on the pen floor at its
## home), a loose one is LOOSE (idling, wandering, startled: it picks its own again), and only
## CARRIED, THROWN and RECOVERING are kept as they are - restore() sends those back where they live.
static func _capture_chickens(world: Node) -> Dictionary:
	var manager: Node = _node(world, "Chickens", "the flock")
	if manager == null or not ("agents" in manager):
		return {}
	var out: Dictionary = {}
	for agent in (manager.get("agents") as Array):
		if agent == null or not is_instance_valid(agent):
			continue
		var creature: Node4D = (agent as Node).get_parent() as Node4D
		if creature == null:
			continue
		var id: int = int(_read(agent, "chicken_id", 0))
		var returned: bool = bool(_read(agent, "returned", false))
		var state: String = _state_name(agent, "State", int(_read(agent, "state", 0)))
		var home: Vector4 = _read(agent, "home_position", creature.position)
		var at: Vector4 = creature.position
		if returned:
			if state in ["TO_COOP", "NESTING", "ROOSTING"]:
				at = home
			state = "PENNED"
		elif not (state in ["CARRIED", "THROWN", "RECOVERING"]):
			state = "LOOSE"
		out[id] = {
			"state": state,
			"returned": returned,
			"ever_carried": bool(_read(agent, "ever_carried", false)),
			"home": home,
			"position": at,
		}
	return out


static func _capture_game(world: Node) -> Dictionary:
	var game: Node = _node(world, "Systems/Game", "the game")
	if game == null:
		return {}
	return {"opening": bool(_read(game, "_opening", false)), "finished": bool(_read(game, "_finished", false))}


static func _capture_feeders(world: Node) -> Dictionary:
	var upgrades: Node = _node(world, "Pen/Upgrades", "the feeders")
	if upgrades == null:
		return {}
	return {"at": _read(upgrades, "_feeders", [])}


static func _capture_gauntlet(world: Node) -> Dictionary:
	var award: Node = _node(world, "Systems/GauntletAward", "the gauntlet award")
	if award == null:
		return {}
	return {"stage": _state_name(award, "Stage", int(_read(award, "stage", 0)))}


## Plain flags off the nodes in [param table] ({path: [property, ...]}), paths from [param base].
static func _capture_flags(base: Node, table: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for path in table:
		var node: Node = base.get_node_or_null(NodePath(String(path)))
		if node == null:
			push_warning("PenResume: %s is missing, its flags are not written down." % path)
			continue
		var flags: Dictionary = {}
		for prop in table[path]:
			if String(prop) in node:
				flags[prop] = _read(node, String(prop), null)
			else:
				push_warning("PenResume: %s has no %s." % [path, prop])
		out[path] = flags
	return out


static func _capture_statics() -> Dictionary:
	var out: Dictionary = {}
	for path in STATICS:
		var script: GDScript = _script(String(path))
		if script == null:
			continue
		var values: Dictionary = {}
		for name in STATICS[path]:
			if String(name) in script:
				values[name] = _pure(script.get(String(name)))
			else:
				push_warning("PenResume: %s has no static %s." % [path, name])
		out[path] = values
	return out


## Every DialoguePlayer4D under [param base] (not inside [param skip]): visited topics, flags, asked.
static func _capture_dialogue(base: Node, skip: Array) -> Dictionary:
	var out: Dictionary = {}
	for talk in _find_dialogues(base, skip):
		out[String(base.get_path_to(talk))] = {
			"visited": _read(talk, "_visited", {}),
			"flags": _read(talk, "_flags", {}),
			"asked_any": bool(_read(talk, "_asked_any", false)),
		}
	return out


static func _capture_invitation(world: Node, place: Dictionary, flags: Dictionary) -> Dictionary:
	var invite: Node = _node(world, "Invitation", "Trym's invitation")
	if invite == null:
		return {}
	var out: Dictionary = {
		"beat": _state_name(invite, "Beat", int(_read(invite, "_beat", 0))),
		"offered": bool(_read(invite, "_offered", false)),
		"armed": bool(_read(invite, "_armed", false)),
	}
	var trym: Object = _read_object(invite, "_trym")
	if trym != null:
		var figure: Object = _read_object(trym, "_figure")
		out["trym"] = {
			"walk": _read(trym, "_walk", Vector4.ZERO),
			"walk_facing": float(_read(trym, "_walk_facing", 0.0)),
			"taken": bool(_read(trym, "_taken", false)),
			"visible": bool(figure.get("visible")) if figure != null else true,
		}
	var marker: Node4D = _read_object(invite, "_marker") as Node4D
	if marker != null:
		out["marker"] = marker.position
	# In the theatre, coming home is what rearm() does on the way out: HOME, him beside you, and his
	# question about the show still to come.
	var beat: String = String(out["beat"])
	if bool(place.get("theatre", false)) and beat in ["CALLING", "LEAVING", "OPEN"]:
		out["beat"] = "HOME"
		out["settle_near_player"] = true
		var trym_flags: Dictionary = flags.get("Systems/TrymDriver", {})
		if not trym_flags.is_empty() and not bool(trym_flags.get("_heard_opinion", false)):
			trym_flags["_owes_an_opinion"] = true
	return out


static func _capture_mithra(world: Node) -> Dictionary:
	var mithra: Node4D = _node(world, "Mithra", "Mithra") as Node4D
	if mithra == null:
		return {}
	return {"position": mithra.position, "home": _read(mithra, "_home", mithra.position), "facing": float(_read(mithra, "_facing", PI))}


## Nike's spot and the middle of his patch, unless he is in your arms (then he is put down at home).
static func _capture_nike(world: Node) -> Dictionary:
	var nike: Node4D = _node(world, "World/Nike", "Nike") as Node4D
	if nike == null:
		return {}
	var grab: Node = world.get_node_or_null(^"Systems/NikeGrab")
	if grab != null and bool(_read(grab, "holding", false)):
		return {}
	var antics: Node = nike.get_node_or_null(^"Antics")
	return {"position": nike.position, "home": _read(antics, "_home", nike.position) if antics != null else nike.position}


static func _capture_look(world: Node) -> Dictionary:
	var look: Node = _node(world, "Systems/Look", "the look switch")
	if look == null:
		return {}
	return {"dev": bool(_read(look, "dev", false))}


static func _capture_tutor(world: Node) -> Dictionary:
	var tutor: Node = _node(world, "Systems/Tutor", "the tutor")
	if tutor == null:
		return {}
	var label: Label = _read_object(tutor, "_label") as Label
	return {
		"shown": _read(tutor, "_shown", {}),
		"start_w": float(_read(tutor, "_start_w", 0.0)),
		"off_for": float(_read(tutor, "_off_for", 0.0)),
		"showing": String(_read(tutor, "_showing", "")),
		"left": float(_read(tutor, "_left", 0.0)),
		"text": label.text if label != null else "",
	}


static func _capture_paths(world: Node) -> Dictionary:
	var network: Node = _node(world, "World/Paths", "the path network")
	if network == null:
		return {}
	return {"found": _read(network, "_found", {}), "node_found": _read(network, "_node_found", {})}


## Metas on [param node] whose values are plain data.
static func _capture_metas(node: Node) -> Dictionary:
	var out: Dictionary = {}
	for key in node.get_meta_list():
		var value: Variant = node.get_meta(key)
		if _is_plain(value):
			out[String(key)] = _pure(value)
	return out


## The cave: in it (CaveCrossing's live room) or visited and left (parked in _kept), or never seen.
static func _capture_cave(world: Node) -> Dictionary:
	var crossing: Node = world.get_node_or_null(^"CaveCrossing")
	if crossing == null:
		return {"where": "none"}
	var cave: Node = null
	var where: String = "none"
	if crossing.has_method("is_away") and bool(crossing.call("is_away")):
		cave = _read_object(crossing, "_theatre") as Node
		where = "in"
	else:
		cave = _read_object(crossing, "_kept") as Node
		where = "parked"
	if cave == null:
		return {"where": "none"}
	var out: Dictionary = {"where": where}
	var gold: Node = cave.get_node_or_null(^"Gold")
	if gold != null and ("_found" in gold) and ("_orbs" in gold):
		var orbs: Array = []
		for orb in (gold.get("_orbs") as Array):
			var o: Node4D = orb as Node4D
			orbs.append({"visible": o.visible, "position": o.position} if o != null and is_instance_valid(o) else {})
		out["gold"] = {"found": _pure(gold.get("_found")), "orbs": orbs}
	else:
		push_warning("PenResume: the cave has no gold to write down.")
	out["flags"] = _capture_flags(cave, CAVE_FLAGS)
	out["dialogue"] = _capture_dialogue(cave, _far_room(cave))
	out["metas"] = _capture_metas(cave)
	return out


# ================================================================== restore

## Puts [param data] (from [method capture]) back on a fresh [param world]. A coroutine: await it.
static func restore(world: Node, data: Dictionary) -> void:
	if world == null or not is_instance_valid(world) or data.is_empty():
		return
	var tree: SceneTree = world.get_tree()
	if tree == null:
		push_warning("PenResume: the world is not in the tree, so nothing is restored.")
		return
	if int(data.get("version", 0)) != VERSION:
		push_warning("PenResume: written by version %s, reading as %d." % [str(data.get("version")), VERSION])
	if String(data.get("scene", "")) != "" and String(data.get("scene", "")) != String(world.scene_file_path):
		push_warning("PenResume: written from %s, restoring onto %s." % [data.get("scene"), world.scene_file_path])
	# The game's reset sweep (Systems/Game._ready) clears quest state and statics; it has to be done
	# before anything here is set, or it would wipe it again.
	var game: Node = world.get_node_or_null(^"Systems/Game")
	var waited: int = 0
	while waited < SETTLE_CAP and is_instance_valid(world) and (not world.is_node_ready() or (game != null and is_instance_valid(game) and not game.is_node_ready())):
		await tree.process_frame
		waited += 1
	if not is_instance_valid(world):
		return
	_restore_metas(world, _dict(data, "root_metas"))
	_restore_statics(_dict(data, "statics"))
	_restore_flags(world, _dict(data, "flags"))
	_restore_dialogue(world, _dict(data, "dialogue"))
	_restore_inventory(world, _dict(data, "inventory"))
	_restore_pickups(world, _dict(data, "pickups"))
	_restore_feeders(world, _dict(data, "feeders"))
	_restore_gauntlet(world, _dict(data, "gauntlet"))
	_restore_keeper(world)
	_restore_look(world, _dict(data, "look"))
	_restore_kata_chest(world)
	_restore_paths(world, _dict(data, "paths"))
	_restore_invitation(world, _dict(data, "invitation"), _dict(data, "player"))
	_restore_mithra(world, _dict(data, "mithra"))
	_restore_nike(world, _dict(data, "nike"))
	_restore_chickens(world, _dict(data, "chickens"))
	_restore_game(world, _dict(data, "game"))
	_restore_tutor(world, _dict(data, "tutor"))
	_refresh_quests(world)
	var place: Dictionary = _dict(data, "place")
	var cave: Dictionary = _dict(data, "cave")
	if bool(place.get("cave", false)):
		await _enter_cave(world, place, cave)
		if not is_instance_valid(world):
			return
	else:
		if String(cave.get("where", "none")) == "parked":
			_park_cave(world, cave)
		# Where the last trip in started (the next go() writes it again; kept for what reads it).
		var crossing: Node = world.get_node_or_null(^"CaveCrossing")
		if crossing != null and place.has("cave_was_at"):
			_write(crossing, "_was_at", place["cave_was_at"], "the way home from the cave")
			_write(crossing, "_testing_trip", bool(place.get("cave_testing", false)), "the cave trip's kind")
	_place_player(world, _dict(data, "player"), _dict(data, "rig"))
	# One physics frame for the body to settle on the floor, then exactly where it was again.
	await tree.physics_frame
	if is_instance_valid(world):
		_place_player(world, _dict(data, "player"), _dict(data, "rig"))


## Removes the root metas that would make a reload of the world misbehave.
static func clear_root_leftovers(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	for key in ROOT_LEFTOVERS:
		if tree.root.has_meta(key):
			tree.root.remove_meta(key)


static func _restore_metas(node: Node, metas: Dictionary) -> void:
	for key in metas:
		node.set_meta(StringName(String(key)), _pure(metas[key]))


static func _restore_statics(statics: Dictionary) -> void:
	for path in statics:
		var script: GDScript = _script(String(path))
		if script == null:
			continue
		var values: Dictionary = statics[path]
		for name in values:
			_write(script, String(name), values[name], "%s static %s" % [String(path).get_file(), name])


static func _restore_flags(base: Node, flags: Dictionary) -> void:
	for path in flags:
		var node: Node = base.get_node_or_null(NodePath(String(path)))
		if node == null:
			push_warning("PenResume: %s is missing, its flags are skipped." % path)
			continue
		var values: Dictionary = flags[path]
		for prop in values:
			_write(node, String(prop), values[prop], "%s.%s" % [path, prop])


static func _restore_dialogue(base: Node, dialogue: Dictionary) -> void:
	for path in dialogue:
		var talk: Node = base.get_node_or_null(NodePath(String(path)))
		if talk == null or not _is_dialogue(talk):
			push_warning("PenResume: no dialogue player at %s, its topics are skipped." % path)
			continue
		var entry: Dictionary = dialogue[path]
		_write(talk, "_visited", entry.get("visited", {}), "%s visited" % path)
		_write(talk, "_flags", entry.get("flags", {}), "%s flags" % path)
		_write(talk, "_asked_any", bool(entry.get("asked_any", false)), "%s asked" % path)


## Straight into the belt's own arrays: add_item would play the pick-up sound for every item.
static func _restore_inventory(world: Node, belt_data: Dictionary) -> void:
	if belt_data.is_empty():
		return
	var belt: Node = _node(world, "UI/Inventory", "the belt")
	if belt == null:
		return
	_write(belt, "items", belt_data.get("items", []), "belt items")
	_write(belt, "counts", belt_data.get("counts", {}), "belt counts")
	var items: Array = belt.get("items") if "items" in belt else []
	var selected: int = int(belt_data.get("selected", -1))
	_write(belt, "selected", selected if selected < items.size() else -1, "belt selection")
	# Nothing was just picked up: the fresh load's flash (from stocking the pickaxe) goes.
	_write(belt, "_flash", 0.0, "belt flash")
	if belt is CanvasItem:
		(belt as CanvasItem).queue_redraw()


static func _restore_pickups(world: Node, pickups_data: Dictionary) -> void:
	if pickups_data.is_empty():
		return
	var pickups: Node = _node(world, "World/Pickups", "the pickups")
	if pickups == null:
		return
	for name in pickups_data.get("taken", []):
		var item: Node4D = pickups.get_node_or_null(NodePath(String(name))) as Node4D
		if item == null:
			push_warning("PenResume: no pickup %s." % name)
			continue
		item.visible = false
		item.set_process(false)


## Rebuilt with signals held: feeder_raised would blip and send Nike running for each one.
static func _restore_feeders(world: Node, feeders_data: Dictionary) -> void:
	var at: Array = feeders_data.get("at", [])
	if at.is_empty():
		return
	var upgrades: Node = _node(world, "Pen/Upgrades", "the feeders")
	if upgrades == null or not upgrades.has_method("_raise_feeder") or not ("_feeders" in upgrades):
		push_warning("PenResume: the feeders cannot be rebuilt.")
		return
	if not (upgrades.get("_feeders") as Array).is_empty():
		return
	var was_blocked: bool = upgrades.is_blocking_signals()
	upgrades.set_block_signals(true)
	for spot in at:
		if spot is Vector4:
			upgrades.call("_raise_feeder", spot)
	upgrades.set_block_signals(was_blocked)


## Worn if it was given at all: a reveal or a flight in progress ends on the arm, where it would have.
static func _restore_gauntlet(world: Node, gauntlet_data: Dictionary) -> void:
	var stage: String = String(gauntlet_data.get("stage", "IDLE"))
	if stage == "IDLE" or stage == "":
		return
	var award: Node = _node(world, "Systems/GauntletAward", "the gauntlet award")
	if award == null or not award.has_method("_wear"):
		return
	if _state_name(award, "Stage", int(_read(award, "stage", 0))) == "WORN":
		return
	award.call("_wear")


## The keeper's locator gate follows the gauntlet, as his own _on_effect does.
static func _restore_keeper(world: Node) -> void:
	var keeper: Node = world.get_node_or_null(^"Systems/TalkDriver")
	if keeper == null or not keeper.has_method("_show_locator"):
		return
	if bool(_read(keeper, "gate_locator", false)):
		keeper.call("_show_locator", bool(_read(keeper, "_has_gauntlet", false)))


## Through the look's own switch, only if it differs (the session static usually carries it over).
static func _restore_look(world: Node, look_data: Dictionary) -> void:
	if look_data.is_empty():
		return
	var look: Node = _node(world, "Systems/Look", "the look switch")
	if look == null or not look.has_method("set_dev"):
		return
	var dev: bool = bool(look_data.get("dev", false))
	if bool(_read(look, "dev", false)) == dev:
		return
	# The look guide hears look_changed as the player switching; this is not the player.
	var guide: Node = world.get_node_or_null(^"Systems/LookGuide")
	if guide != null and "_self_switch" in guide:
		guide.set("_self_switch", true)
	look.call("set_dev", dev)
	if guide != null and "_self_switch" in guide:
		guide.set("_self_switch", false)


## A found cache has no chest left in it (pen_kata_cache_4d.gd _animate's end).
static func _restore_kata_chest(world: Node) -> void:
	var script: GDScript = _script("res://ramon/chickenpen/discovery/pen_kata_cache_4d.gd")
	if script == null or not bool(script.get("found")):
		return
	var cache: Node = world.get_node_or_null(^"World/KataCache")
	var chest: Node4D = _read_object(cache, "_chest") as Node4D if cache != null else null
	if chest != null:
		chest.visible = false


static func _restore_paths(world: Node, paths_data: Dictionary) -> void:
	if paths_data.is_empty():
		return
	var network: Node = _node(world, "World/Paths", "the path network")
	if network == null:
		return
	_write(network, "_found", paths_data.get("found", {}), "paths found")
	_write(network, "_node_found", paths_data.get("node_found", {}), "path nodes found")
	if network.has_method("_push_reveal"):
		network.call("_push_reveal")


static func _restore_invitation(world: Node, invite_data: Dictionary, player_data: Dictionary) -> void:
	if invite_data.is_empty():
		return
	var invite: Node = _node(world, "Invitation", "Trym's invitation")
	if invite == null:
		return
	var beat: String = String(invite_data.get("beat", "WAITING"))
	match beat:
		"WAITING":
			_write(invite, "_offered", bool(invite_data.get("offered", false)), "invitation offered")
			_write(invite, "_armed", bool(invite_data.get("armed", false)), "invitation armed")
		"HOME":
			_write(invite, "_offered", true, "invitation offered")
			_write(invite, "_armed", false, "invitation armed")
			_write(invite, "_beat", _state_value(invite, "Beat", "HOME", 7), "invitation beat")
			# Past his "Right. Back where we started." (HOME's timer clears the line at 0 and parks at -99).
			_write(invite, "_timer", -99.0, "invitation timer")
			_write(invite, "_home_to", Vector4.ZERO, "invitation walk home")
			var trym: Object = _read_object(invite, "_trym")
			var trym_data: Dictionary = invite_data.get("trym", {})
			if trym != null and not trym_data.is_empty():
				if trym.has_method("take_over") and bool(trym_data.get("taken", true)):
					trym.call("take_over")
				_write(trym, "_walk", trym_data.get("walk", Vector4.ZERO), "Trym's walk")
				_write(trym, "_walk_facing", float(trym_data.get("walk_facing", 0.0)), "Trym's facing")
				if trym.has_method("set_figure_visible"):
					trym.call("set_figure_visible", bool(trym_data.get("visible", true)))
			if bool(invite_data.get("settle_near_player", false)) and trym != null:
				# Out of the theatre: beside you, put down over a few frames as rearm() does.
				var at: Vector4 = player_data.get("position", Vector4.ZERO)
				_write(invite, "_settle_to", Vector4(at.x + 1.6, 0.0, at.z + 1.4, at.w), "Trym's spot")
				_write(invite, "_settle_frames", 5, "Trym's settling")
				if trym.has_method("set_figure_visible"):
					trym.call("set_figure_visible", true)
			var marker: Node4D = _read_object(invite, "_marker") as Node4D
			if marker != null and invite_data.has("marker"):
				if bool(invite_data.get("settle_near_player", false)):
					var at2: Vector4 = player_data.get("position", Vector4.ZERO)
					marker.global_position = Vector4(at2.x + 2.7, 0.0, at2.z + 2.3, 0.0)
				else:
					marker.position = invite_data["marker"]
		"":
			pass
		_:
			# Left mid-errand: he starts it again from his first line.
			if invite.has_method("offer"):
				invite.call("offer")


static func _restore_mithra(world: Node, mithra_data: Dictionary) -> void:
	if mithra_data.is_empty():
		return
	var mithra: Node4D = _node(world, "Mithra", "Mithra") as Node4D
	if mithra == null:
		return
	mithra.position = mithra_data.get("position", mithra.position)
	_write(mithra, "_home", mithra_data.get("home", mithra.position), "Mithra's home")
	_write(mithra, "_target", mithra.position, "Mithra's target")
	_write(mithra, "_facing", float(mithra_data.get("facing", PI)), "Mithra's facing")
	if "linear_velocity" in mithra:
		mithra.set("linear_velocity", Vector4.ZERO)
	if mithra.has_method("_apply_facing"):
		mithra.call("_apply_facing")


static func _restore_nike(world: Node, nike_data: Dictionary) -> void:
	if nike_data.is_empty():
		return
	var nike: Node4D = _node(world, "World/Nike", "Nike") as Node4D
	if nike == null:
		return
	nike.position = nike_data.get("position", nike.position)
	var antics: Node = nike.get_node_or_null(^"Antics")
	if antics != null:
		_write(antics, "_home", nike_data.get("home", nike.position), "Nike's home")


## The flock, then the count. Penned birds land standing (chicken_agent_4d.gd on_landed); a bird
## that was in your arms or in the air goes back to where it lives.
static func _restore_chickens(world: Node, chickens: Dictionary) -> void:
	if chickens.is_empty():
		return
	var manager: Node = _node(world, "Chickens", "the flock")
	if manager == null or not ("agents" in manager):
		return
	var by_id: Dictionary = {}
	for agent in (manager.get("agents") as Array):
		if agent != null and is_instance_valid(agent):
			by_id[int(_read(agent, "chicken_id", 0))] = agent
	for key in chickens:
		var id: int = int(key)
		var agent: Node = by_id.get(id) as Node
		if agent == null:
			push_warning("PenResume: no chicken %d." % id)
			continue
		var creature: Node4D = agent.get_parent() as Node4D
		if creature == null:
			continue
		var c: Dictionary = chickens[key]
		var state: String = String(c.get("state", "IDLE"))
		var home: Vector4 = c.get("home", creature.position)
		var at: Vector4 = c.get("position", home)
		if bool(c.get("returned", false)):
			# In the coop, on its roof or on the way: back on the pen floor at its home.
			if state in ["TO_COOP", "NESTING", "ROOSTING"]:
				at = home
			creature.position = at
			_write(agent, "home_position", home, "chicken home")
			_write(agent, "returned", true, "chicken returned")
			_write(agent, "ever_carried", true, "chicken carried")
			_write(agent, "_penned_walking", false, "chicken standing")
			_settle_chicken(agent, creature, home)
			if agent.has_method("_enter"):
				agent.call("_enter", _state_value(agent, "State", "PENNED", 6))
		else:
			if state in ["CARRIED", "THROWN", "RECOVERING"]:
				at = home
			creature.position = at
			_write(agent, "home_position", home, "chicken home")
			_write(agent, "ever_carried", bool(c.get("ever_carried", false)), "chicken carried")
			_settle_chicken(agent, creature, home)
			if agent.has_method("_enter"):
				agent.call("_enter", _state_value(agent, "State", "IDLE", 0))


## No stale stuck timer, and the walker's own wander circle round where it now lives.
static func _settle_chicken(agent: Node, creature: Node4D, home: Vector4) -> void:
	_write(agent, "_last_seen", creature.position, "chicken last seen")
	_write(agent, "_path", 0.0, "chicken path")
	_write(agent, "_stuck_elapsed", 0.0, "chicken stuck")
	var walker: Node = creature.get_node_or_null(^"Walker")
	if walker != null and "_wander_centre" in walker:
		walker.set("_wander_centre", home)


## The count, the opening line and the finished state, without the sounds a gain or a finish plays.
static func _restore_game(world: Node, game_data: Dictionary) -> void:
	var game: Node = _node(world, "Systems/Game", "the game")
	var manager: Node = world.get_node_or_null(^"Chickens")
	if game == null or manager == null or not manager.has_method("returned_count"):
		return
	var home: int = int(manager.call("returned_count"))
	var total: int = (manager.get("agents") as Array).size() if "agents" in manager else 0
	var done: bool = total > 0 and home >= total
	# Set before the count is shown, so it is not a gain (the confirm cluck) or a finish (the chorus).
	_write(game, "_last_returned", home, "the count")
	_write(game, "_finished", done, "finished")
	if not game_data.is_empty():
		_write(game, "_opening", bool(game_data.get("opening", false)) and not done, "the opening line")
	if game.has_method("_on_progress"):
		game.call("_on_progress", home, total)
	var objective: Label = game.get_node_or_null(_read(game, "objective_label_path", NodePath())) as Label
	if done:
		if objective != null:
			objective.text = String(_read(game, "completion_text", objective.text))
		var locator: Node = game.get_node_or_null(_read(game, "locator_path", NodePath()))
		if locator != null:
			locator.set_physics_process(false)
			var readout: Label = locator.get_node_or_null(_read(locator, "readout_path", NodePath())) as Label
			if readout != null:
				readout.text = "Locator: nothing left to find."
		var cues: Node = game.get_node_or_null(_read(game, "cues_path", NodePath()))
		if cues != null and cues.has_method("quiet"):
			cues.call("quiet")
		for agent in (manager.get("agents") as Array):
			if agent != null and is_instance_valid(agent) and bool(_read(agent, "returned", false)) and agent.has_method("celebrate"):
				agent.call("celebrate", true)
	elif objective != null and not bool(_read(game, "_opening", false)):
		objective.text = String(_read(game, "objective_text", objective.text))


## The hints already given stay given; the one the fresh load put up comes down if it was one of them.
static func _restore_tutor(world: Node, tutor_data: Dictionary) -> void:
	if tutor_data.is_empty():
		return
	var tutor: Node = _node(world, "Systems/Tutor", "the tutor")
	if tutor == null:
		return
	var shown: Dictionary = tutor_data.get("shown", {})
	_write(tutor, "_shown", shown, "tutor hints")
	_write(tutor, "_start_w", float(tutor_data.get("start_w", 0.0)), "tutor start W")
	_write(tutor, "_off_for", float(tutor_data.get("off_for", 0.0)), "tutor time off the slice")
	# The hint that was up, with the time it had left (or none): not the one the fresh load put up.
	_write(tutor, "_showing", String(tutor_data.get("showing", "")), "tutor hint")
	_write(tutor, "_left", float(tutor_data.get("left", 0.0)), "tutor hint time")
	var label: Label = _read_object(tutor, "_label") as Label
	if label != null:
		label.text = String(tutor_data.get("text", "")) if String(tutor_data.get("showing", "")) != "" else ""


static func _refresh_quests(world: Node) -> void:
	var quests: Node = world.get_node_or_null(^"UI/Quests")
	if quests != null and quests.has_method("_poll"):
		quests.call("_poll")


## Back into the cave through the world's own crossing, then its contents as they were.
static func _enter_cave(world: Node, place: Dictionary, cave_data: Dictionary) -> void:
	var crossing: Node = _node(world, "CaveCrossing", "the cave's crossing")
	if crossing == null or not crossing.has_method("go"):
		return
	var tree: SceneTree = world.get_tree()
	if tree.current_scene != world:
		# go() adds the cave to the current scene; anywhere else it would outlive the world.
		push_warning("PenResume: the world is not the current scene, so the cave is not re-entered.")
		return
	if not bool(crossing.call("is_away")):
		crossing.call("go")
	await tree.process_frame
	if not is_instance_valid(world) or not is_instance_valid(crossing):
		return
	var cave: Node = _read_object(crossing, "_theatre") as Node
	if cave == null:
		push_warning("PenResume: the cave did not open.")
		return
	_apply_cave(cave, cave_data)
	_write(crossing, "_was_at", place.get("cave_was_at", Vector4.ZERO), "the way home from the cave")
	_write(crossing, "_testing_trip", bool(place.get("cave_testing", false)), "the cave trip's kind")


## A cave visited and left: built again and parked out of the tree, the way come_back() parks it.
## Added and taken out within this call, so no frame (and no physics step) runs with it in.
static func _park_cave(world: Node, cave_data: Dictionary) -> void:
	var crossing: Node = _node(world, "CaveCrossing", "the cave's crossing")
	if crossing == null or not bool(_read(crossing, "keep_scene", false)):
		return
	var kept: Object = _read_object(crossing, "_kept")
	if kept != null or (crossing.has_method("is_away") and bool(crossing.call("is_away"))):
		return
	var packed: PackedScene = _read_object(crossing, "theatre_scene") as PackedScene
	if packed == null:
		push_warning("PenResume: no cave scene to park.")
		return
	var cave: Node = packed.instantiate()
	# Under the world root, where go() puts it: its paths up to the player and the belt resolve.
	world.add_child(cave)
	_apply_cave(cave, cave_data)
	world.remove_child(cave)
	crossing.set("_kept", cave)
	# Its sky claimed the world on the way in; the farm's back, as come_back() does.
	var env: Node = world.get_node_or_null(_read(crossing, "farm_environment_path", NodePath("World/Environment")))
	if env == null:
		env = world.get_node_or_null(^"World/Environment")
	if env != null and env.has_method("make_current"):
		env.call("make_current")


static func _apply_cave(cave: Node, cave_data: Dictionary) -> void:
	var gold_data: Dictionary = cave_data.get("gold", {})
	var gold: Node = cave.get_node_or_null(^"Gold")
	if not gold_data.is_empty() and gold != null and ("_found" in gold) and ("_orbs" in gold):
		var found: Array = gold.get("_found")
		var orbs: Array = gold.get("_orbs")
		var found_data: Array = gold_data.get("found", [])
		var orbs_data: Array = gold_data.get("orbs", [])
		for i in mini(found.size(), found_data.size()):
			found[i] = bool(found_data[i])
		for i in mini(orbs.size(), orbs_data.size()):
			var orb: Node4D = orbs[i] as Node4D
			var o: Dictionary = orbs_data[i]
			if orb == null or o.is_empty():
				continue
			orb.visible = bool(o.get("visible", false))
			orb.position = o.get("position", orb.position)
	elif not gold_data.is_empty():
		push_warning("PenResume: the cave's gold is missing, skipped.")
	_restore_flags(cave, cave_data.get("flags", {}))
	_restore_dialogue(cave, cave_data.get("dialogue", {}))
	_restore_metas(cave, cave_data.get("metas", {}))


## Where you stood, which way you faced, and the slice you were looking through.
static func _place_player(world: Node, player_data: Dictionary, rig_data: Dictionary) -> void:
	var player: Node4D = _node(world, "Player", "the player") as Node4D
	if player == null:
		return
	if player_data.has("position"):
		player.position = player_data["position"]
	if "linear_velocity" in player:
		player.set("linear_velocity", Vector4.ZERO)
	_write(player, "_down", 0.0, "knock-down")
	_write(player, "input_enabled", true, "player input")
	var rig: Node4D = player.get_node_or_null(^"CameraRig") as Node4D
	if rig != null and not rig_data.is_empty():
		var preset: int = int(rig_data.get("preset", 0))
		if rig.has_method("use_preset") and int(_read(rig, "preset", preset)) != preset and int(_read(rig, "start_preset", -1)) >= 0:
			rig.call("use_preset", preset)
		_write(rig, "_homing", 0.0, "rig trip home")
		if rig_data.get("basis") is Projection:
			rig.basis = rig_data["basis"]
		_write(rig, "pitch", float(rig_data.get("pitch", -0.15)), "rig pitch")
		var zoom: float = float(rig_data.get("zoom", 5.0))
		_write(rig, "distance", zoom, "rig distance")
		_write(rig, "_zoom_target", zoom, "rig zoom")
		_write(rig, "_rest_distance", zoom, "rig rest distance")
		var pivot: float = float(rig_data.get("pivot", 1.1))
		_write(rig, "pivot_height", pivot, "rig pivot")
		_write(rig, "_home_pivot", pivot, "rig home pivot")
		if rig.has_method("_apply"):
			rig.call("_apply")
	# The stance last: the walker's facing is measured against the rig's slice.
	if player_data.get("stance") is Projection:
		_write(player, "_stance", player_data["stance"], "player stance")
		var avatar: Node4D = player.get_node_or_null(^"Avatar") as Node4D
		if avatar != null:
			avatar.basis = player_data["stance"]


# ================================================================== helpers

## [param data]'s [param key] if it is a Dictionary, else an empty one (a damaged entry skips its item).
static func _dict(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	if value is Dictionary:
		return value
	push_warning("PenResume: %s is not a dictionary, skipped." % key)
	return {}


static func _node(world: Node, path: String, what: String) -> Node:
	var node: Node = world.get_node_or_null(NodePath(path))
	if node == null:
		push_warning("PenResume: %s (%s) is missing, skipped." % [what, path])
	return node


## A property as plain data, or [param fallback] if [param object] has no such property.
static func _read(object: Object, prop: String, fallback: Variant) -> Variant:
	if object == null or not is_instance_valid(object) or not (prop in object):
		return fallback
	return _pure(object.get(prop))


## A property that holds an object (never written into the data).
static func _read_object(object: Object, prop: String) -> Object:
	if object == null or not is_instance_valid(object) or not (prop in object):
		return null
	var value: Variant = object.get(prop)
	if value is Object and is_instance_valid(value):
		return value as Object
	return null


## Sets [param prop] if [param object] has it. Arrays and dictionaries are filled in place, so a
## typed property keeps its type (Array[String], Array[Vector4]) and its own instance.
static func _write(object: Object, prop: String, value: Variant, what: String) -> bool:
	if object == null or not is_instance_valid(object):
		return false
	if not (prop in object):
		push_warning("PenResume: %s has nothing to write into, skipped." % what)
		return false
	var current: Variant = object.get(prop)
	if current is Array and value is Array:
		(current as Array).assign(_pure(value))
		return true
	if current is Dictionary and value is Dictionary:
		(current as Dictionary).assign(_pure(value))
		return true
	if current != null and typeof(current) != typeof(value):
		var both_numbers: bool = typeof(current) in [TYPE_INT, TYPE_FLOAT] and typeof(value) in [TYPE_INT, TYPE_FLOAT]
		if not both_numbers:
			push_warning("PenResume: %s expected %s, got %s, skipped." % [what, type_string(typeof(current)), type_string(typeof(value))])
			return false
		value = int(value) if typeof(current) == TYPE_INT else float(value)
	object.set(prop, value)
	return true


static func _script(path: String) -> GDScript:
	if not ResourceLoader.exists(path):
		push_warning("PenResume: no script at %s, its statics are skipped." % path)
		return null
	return load(path) as GDScript


## A deep copy holding plain data only: objects, callables, signals and RIDs are dropped.
static func _pure(value: Variant, depth: int = 0) -> Variant:
	if depth > 24:
		return null
	match typeof(value):
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return null
		TYPE_ARRAY:
			var out: Array = []
			for item in value:
				out.append(_pure(item, depth + 1))
			return out
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key in value:
				var k: Variant = _pure(key, depth + 1)
				if k != null:
					out[k] = _pure(value[key], depth + 1)
			return out
		_:
			return value


static func _is_plain(value: Variant) -> bool:
	return not (typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID])


## An enum value's name, from the script's own enum (so the data does not depend on its order).
static func _state_name(node: Object, enum_name: String, value: int) -> String:
	var values: Dictionary = _enum_of(node, enum_name)
	for key in values:
		if int(values[key]) == value:
			return String(key)
	return str(value)


static func _state_value(node: Object, enum_name: String, name: String, fallback: int) -> int:
	var values: Dictionary = _enum_of(node, enum_name)
	return int(values.get(name, fallback))


static func _enum_of(node: Object, enum_name: String) -> Dictionary:
	if node == null:
		return {}
	var script: Script = node.get_script() as Script
	if script == null:
		return {}
	var map: Dictionary = script.get_script_constant_map()
	return map.get(enum_name, {}) if map.get(enum_name) is Dictionary else {}


static func _to_parent_frame(node: Node4D, global_point: Vector4) -> Vector4:
	var parent: Node4D = node.get_parent() as Node4D
	if parent == null:
		return global_point
	return parent.global_basis.inverse() * (global_point - parent.global_position)


static func _is_dialogue(node: Node) -> bool:
	return node.has_method("set_flag") and node.has_method("get_flag") and ("_visited" in node) and ("_flags" in node)


## Rooms the world holds that are not the world's own: the theatre and the cave while you are in
## them (the cave is written down on its own).
static func _skipped_subtrees(world: Node) -> Array:
	var out: Array = []
	for path in ["Crossing", "CaveCrossing"]:
		var crossing: Node = world.get_node_or_null(NodePath(path))
		var room: Object = _read_object(crossing, "_theatre") if crossing != null else null
		if room != null:
			out.append(room)
	return out


## The cave's far room, if it is loaded: it streams in and out and forgets its own talk anyway.
static func _far_room(cave: Node) -> Array:
	var stream: Node = cave.get_node_or_null(^"FarStream")
	var far: Object = _read_object(stream, "_far") if stream != null else null
	return [far] if far != null else []


static func _find_dialogues(base: Node, skip: Array) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [base]
	var walked: int = 0
	while not stack.is_empty() and walked < WALK_CAP:
		walked += 1
		var node: Node = stack.pop_back()
		if skip.has(node):
			continue
		if _is_dialogue(node):
			out.append(node)
		for child in node.get_children():
			stack.append(child)
	if walked >= WALK_CAP:
		push_warning("PenResume: stopped looking for dialogue after %d nodes." % WALK_CAP)
	return out
