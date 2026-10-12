extends SceneTree

## BOTANY LAB (fork of scripts/_proof_runner.gd, 9 Oct): the same checks on botany_lab.tscn, without the
## grove (its own scene now), plus the Botany Lab's own as they are built (section 7's plan).
##
## Plan steps 44, 89 and 98: the Arboretum's checks, headless. Opens the scene and proves, in lines
## that say PASS or FAIL:
##   - every pedestal holds its tree, its wood mesh has tetrahedra, its record has numbers, its story
##     has parts, and its card has every field
##   - the baked trees match what the bake recorded (tetrahedra)
##   - both route graphs pass PathCreator's own checks and rule 10's acceptance (notes() empty)
##   - the wall panels' text fits (no overflow reported)
##   - the grove loads every shape and places its trees
## Exit 0 when every check passes, 1 otherwise.

const SCENE := "res://ramon/Arboretum/botany_lab.tscn"
const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")

var _room: Node4D
var _f: int = 0
var _fails: int = 0
var _deadline: int = 0


func _initialize() -> void:
	_deadline = Time.get_ticks_msec() + 120000
	(func() -> void:
		_room = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_room)).call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _process(_d: float) -> bool:
	_f += 1
	if Time.get_ticks_msec() > _deadline:
		print("PROOF TIMEOUT")
		quit(2)
		return true
	if _f == 90:
		_stations()
		_paths()
		_panels()
		_botany()
		print("PROOF %s: %d failed" % ["PASS" if _fails == 0 else "FAIL", _fails])
		quit(0 if _fails == 0 else 1)
		return true
	return false


func _stations() -> void:
	var keys := ["voxel", "dc", "loft", "oak"]
	for i in 4:
		var s: Node = _room.get_node_or_null("Station%02d" % (i + 1))
		_check(s != null, "station %d exists" % (i + 1))
		if s == null:
			continue
		var ex: Node = s.get("exhibit")
		_check(ex != null and String(ex.get("method")) == keys[i], "station %d holds the %s tree" % [i + 1, keys[i]])
		if ex == null:
			continue
		var layers: Dictionary = ex.get("layers")
		var wood: MeshInstance4D = layers.get("wood")
		var tets: int = (wood.mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4 if wood != null and wood.mesh != null else 0
		_check(tets > 1000, "station %d wood: %d tetrahedra" % [i + 1, tets])
		var rec: Dictionary = ex.get("record")
		_check(int(rec.get("tets", 0)) > 0, "station %d record: %s" % [i + 1, str(rec)])
		if int(rec.get("tets", 0)) > 0 and String(ex.get("live_note")).is_empty():
			_check(int(rec["tets"]) == tets, "station %d baked mesh matches the bake's count (%d)" % [i + 1, int(rec["tets"])])
		var parts: Array = ex.call("chapters")
		_check(parts.size() >= 4, "station %d story: %d parts" % [i + 1, parts.size()])
		var card: Dictionary = ex.call("card")
		for k in ["code", "title", "method", "shows", "limits", "rows", "tier"]:
			if not card.has(k):
				_check(false, "station %d card has %s" % [i + 1, k])
		var nums: Dictionary = ex.call("numbers")
		for p in parts:
			# The callouts and the part's own line (the presenter fills both).
			var texts: Array = [String((p as Dictionary).get("line", ""))]
			for c in (p as Dictionary).get("callouts", []):
				texts.append(String(c[1]))
			for tx in texts:
				var text: String = String(tx)
				var at: int = text.find("{")
				while at >= 0:
					var close: int = text.find("}", at)
					var key: String = text.substr(at + 1, close - at - 1)
					if not nums.has(key):
						_check(false, "station %d token {%s} is filled" % [i + 1, key])
					at = text.find("{", close)
		if i == 3:
			var lv: Node = ex.get("leaves")
			_check(lv != null and int(lv.get("count")) > 1000, "the oak has leaves: %d" % (int(lv.get("count")) if lv != null else 0))


func _paths() -> void:
	for nm in ["Hall"]:
		var net: Node = _room.get_node_or_null("Paths/" + nm)
		_check(net != null and net.get("graph") != null, "path network %s has its graph" % nm)
		if net == null:
			continue
		var notes: PackedStringArray = net.call("notes")
		_check(notes.is_empty(), "paths %s: rule 10 and the graph's own checks %s" % [nm, "pass" if notes.is_empty() else "say: " + " / ".join(notes)])


func _panels() -> void:
	for nm in ["IntroPanel", "ResearchBoard"]:
		var p: Node = _room.get_node_or_null(nm)
		_check(p != null, "%s exists" % nm)
		if p == null:
			continue
		var page: Node = p.get("page")
		if page != null and page.has_method("overflowed"):
			var over: Array = page.call("overflowed")
			_check(over.is_empty(), "%s text fits%s" % [nm, "" if over.is_empty() else ": " + str(over)])


## The Botany Lab's own checks (section 7), added as each part is built.
func _botany() -> void:
	var ent: Node = _room.get_node_or_null("Entrance")
	_check(ent != null and float((ent.get("size") as Vector3).y) >= 7.0, "the corridor's ceiling is raised: %.1f m" % (float((ent.get("size") as Vector3).y) if ent != null else 0.0))
	var le: Node = _room.get("light_editor")
	_check(le != null and (le.get("lights") as Array).size() >= 5, "the dev HUD's lights' editor lists %d lights" % ((le.get("lights") as Array).size() if le != null else 0))
