extends SceneTree

## The pen's two looks (look/pen_look_4d.gd, PenLayout/PLAN_DEV_LOOK.md part D): opened as a player
## opens it, in the dev look, then taken apart.
##   1. it opens in DEV, the art drawn under the curtain first
##   2. no node hidden by the look; every collider still there
##   3. the blockouts are there, as children of their landmarks, never saved (no owner)
##   4. the ground shows the dev floor in DEV and its paint in ART
##   5. fifty switches: every mesh and material back as it was each time
##   6. the cinema held in ART while away, DEV again after
##   7. the cave's tunnel held in ART, DEV again outside
##   8. a save puts the art back exactly, and the look comes back after
##   9. a main-green rebake in DEV: what it rebuilds comes into the look
##
##   lab_run.sh windowed look res://ramon/chickenpen/look/_verify_look_runner.gd

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")

var _room: Node
var _look: Node
var _fails: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 400000:
		print("LOOK TEST: gave up")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Every MeshInstance4D under World and the pen, not the look's own: node -> [mesh, material].
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for r in [_room.get_node("World"), _room.get_node("Pen")]:
		for node in (r as Node).find_children("*", "MeshInstance4D", true, false):
			if not node.has_meta(&"_look_own"):
				out[node] = [(node as MeshInstance4D).mesh, (node as MeshInstance4D).material_override]
	return out


func _same(a: Dictionary, b: Dictionary) -> int:
	var off: int = 0
	for n in a:
		if not is_instance_valid(n) or not b.has(n):
			continue
		if a[n][0] != b[n][0] or a[n][1] != b[n][1]:
			off += 1
	return off


## Every Node4D's own visible flag, but the path network's marks (its looks show and hide those
## themselves) and the look's own.
func _differing(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for n in a:
		if is_instance_valid(n) and b.has(n) and (a[n][0] != b[n][0] or a[n][1] != b[n][1]):
			out.append(String(_room.get_path_to(n)))
	return out


func _visibles() -> Dictionary:
	var out: Dictionary = {}
	var paths: Node = _room.get_node("World/Paths")
	for node in _room.find_children("*", "Node4D", true, false):
		if not node.has_meta(&"_look_own") and not paths.is_ancestor_of(node):
			out[node] = (node as Node4D).visible
	return out


func _run() -> void:
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	var player := _room.get_node("Player") as Node4D
	player.set("input_enabled", false)
	_look = _room.get_node("Systems/Look")
	await _frames(30)
	# 1.
	_check(bool(_look.get("dev")) and bool(_look.get("_applied")), "1 opens in the dev look")
	var dev_state: Dictionary = _snapshot()
	var shapes_dev: int = _room.get_node("World").find_children("*", "CollisionShape4D", true, false).size()
	var vis_dev: Dictionary = _visibles()
	_look.call("set_dev", false)
	await _frames(3)
	var art_state: Dictionary = _snapshot()
	var vis_art: Dictionary = _visibles()
	var shapes_art: int = _room.get_node("World").find_children("*", "CollisionShape4D", true, false).size()
	# 2.
	var flipped: Array = []
	for n in vis_art:
		if is_instance_valid(n) and vis_dev.has(n) and vis_dev[n] != vis_art[n]:
			flipped.append(String(_room.get_path_to(n)))
	_check(flipped.is_empty(), "2 no node's visibility changed by the look (%d did: %s)" % [flipped.size(), ", ".join(PackedStringArray(flipped.slice(0, 8)))])
	_check(shapes_dev == shapes_art and shapes_art > 100, "2 colliders the same in both looks (%d, %d)" % [shapes_dev, shapes_art])
	var changed: int = _same(art_state, dev_state)
	print("   %d of %d meshes look different in DEV" % [changed, art_state.size()])
	_check(changed > 200, "2 the dev look reaches the landmarks (%d meshes)" % changed)
	# 3.
	_look.call("set_dev", true)
	await _frames(3)
	var blocks: Array = []
	for node in _room.find_children("DevBlockout_*", "MeshInstance4D", true, false):
		blocks.append(node)
	var parents: Array = blocks.map(func(b) -> String: return String((b as Node).get_parent().name))
	print("   blockouts on: %s" % ", ".join(PackedStringArray(parents)))
	for want in ["Lookout", "CaveHill", "Shed", "Oak", "RockPileSpot"]:
		_check(parents.has(want), "3 %s has its blockout" % want)
	_check(blocks.all(func(b) -> bool: return (b as Node).owner == null), "3 no blockout would be saved (no owner)")
	# 4.
	var grass: Node = _room.get_node("World/Grass")
	var ground := _room.get_node("World/Ground/GroundMesh") as MeshInstance4D
	_check(ground.material_override == grass.get("dev_floor") and grass.get("dev_floor") != null, "4 the ground shows the dev floor in DEV")
	_look.call("set_dev", false)
	await _frames(2)
	_check(grass.get("dev_floor") == null and ground.material_override != null and not (ground.mesh is BoxTetraMesh4D and ground.material_override == art_state.get(ground, [null, null])[1] and false),
		"4 the ground back to its paint in ART")
	_check(_same(art_state, _snapshot()) == 0, "4 ART after one switch: every mesh and material as it was")
	# 5.
	var worst: int = 0
	for k in 50:
		_look.call("set_dev", k % 2 == 0)
		await process_frame
	await _frames(2)
	_check(not bool(_look.get("dev")), "5 fifty switches end in ART")
	worst = _same(art_state, _snapshot())
	_check(worst == 0, "5 after fifty switches every mesh and material is back (%d off)" % worst)
	var blocks_left: int = _room.find_children("DevBlockout_*", "MeshInstance4D", true, false).size()
	await _frames(2)
	_check(_room.find_children("DevBlockout_*", "MeshInstance4D", true, false).size() == 0, "5 no blockout left in ART (%d were)" % blocks_left)
	# 6.
	_look.call("set_dev", true)
	await _frames(3)
	var crossing: Node = _room.get_node("Crossing")
	crossing.call("go_for_testing")
	await _frames(20)
	_check(bool(crossing.call("is_away")) and not bool(_look.get("_applied")), "6 in the cinema the art is held")
	crossing.call("come_back")
	await _frames(40)
	_check(not bool(crossing.call("is_away")) and bool(_look.get("_applied")), "6 back from the cinema, the dev look again")
	# 7.
	var hill := _room.get_node("World/Cave/CaveHill") as Node4D
	var inside: Vector4 = hill.global_position + hill.global_basis * (CaveHill.MOUTH + Vector4(0, 1.2, -6.5, 0))
	player.global_position = inside
	await _frames(20)
	_check(String(_look.get("_hold")) == "cave" and not bool(_look.get("_applied")), "7 in the cave's tunnel the art is held (%s)" % String(_look.get("_hold")))
	player.global_position = hill.global_position + hill.global_basis * (CaveHill.MOUTH + Vector4(0, 1.2, 8.0, 0))
	await _frames(20)
	_check(bool(_look.get("_applied")), "7 out of the tunnel, the dev look again")
	# 8. Against the art as it is now (the trips above rebuilt some of it, as play does).
	_look.call("set_dev", false)
	await _frames(2)
	var art_now: Dictionary = _snapshot()
	_look.call("set_dev", true)
	await _frames(2)
	# Read at once: the editor saves straight after this, and at play time the look lays itself
	# again on its next frame (the editor never runs its _process).
	_look.call("before_save")
	var off: Array = _differing(art_now, _snapshot())
	_check(off.is_empty(), "8 before a save every mesh and material is the art's (%d off: %s)" % [off.size(), ", ".join(PackedStringArray(off.slice(0, 6)))])
	_look.call("after_save")
	await _frames(2)
	_check(bool(_look.get("_applied")), "8 after the save the dev look is back")
	# 9.
	var started: int = Time.get_ticks_msec()
	grass.call("rebake_greens")
	await _frames(10)
	print("   green rebake in DEV: %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	var loose: Array = []
	for node in _room.get_node("World").find_children("*", "MeshInstance4D", true, false):
		var mi := node as MeshInstance4D
		if mi.has_meta(&"_look_own") or not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		if String(_look.call("_role", mi)) != "landmark":
			continue
		var r: Array = _look.call("_rule_of", mi)
		if r[0] is Dictionary or String(r[0]) == "art":
			continue
		if not (_look.get("_saved_mat") as Dictionary).has(mi):
			loose.append(String(mi.get_path()).get_slice("/World/", 1))
	_check(loose.is_empty(), "9 after a green rebake in DEV every landmark mesh is in the look (%d loose: %s)" % [loose.size(), ", ".join(PackedStringArray(loose.slice(0, 6)))])
	_look.call("set_dev", false)
	await _frames(3)
	print("LOOK TEST: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0)
