extends SceneTree

## The places on the slice dial (pen_slice_plane_4d.gd, "slice_dial_outline"): the Lookout, the
## marsh, the owl and the cave each give an outline; the marsh's and the owl's at their own w;
## move the Lookout's site and its outline (and the marsh's and the owl's, which hang off it)
## moves with it on the next ask. Then the player stood by the tower, the cave and the marsh,
## and the HUD saved at each: res://smoke_test_output/dial_places_<where>.png.
## Prints PASS or FAIL per check; gives up after 90 s.
##
##   godot... --path project --windowed --resolution 1920x1080 --position 0,0
##       --script res://ramon/chickenpen/scripts/_verify_dial_places_runner.gd

const WANT := {"Watchstone": 0.0, "marsh": 8.0, "owl": 1.5, "cave": 0.0}

var _room: Node
var _player: Node4D
var _t: float = 0.0
var _step: int = -1
var _wait: float = 0.0
var _fails: int = 0
var _spots: Array = []


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.set("journal_path", "user://lookout_journal_dial_places_test.cfg")
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-50s %s" % ["PASS" if ok else "FAIL", what, detail])


func _outlines() -> Dictionary:
	var out: Dictionary = {}
	for node in get_nodes_in_group(&"slice_dial_outline"):
		var d: Dictionary = node.call("dial_outline")
		out[String(d.get("label", ""))] = d
	return out


func _middle(d: Dictionary) -> Vector4:
	var points: PackedVector4Array = d["points"]
	var sum := Vector4.ZERO
	for p in points:
		sum += p
	return sum / float(points.size())


func _process(dt: float) -> bool:
	_t += dt
	if _t > 90.0:
		print("DIAL PLACES FAIL: timed out at step %d" % _step)
		return true
	_wait -= dt
	if _wait > 0.0:
		return false
	match _step:
		-1:
			var grass: Node = _room.get_node_or_null("World/Grass")
			if (grass != null and not bool(grass.get("mask_ready"))) or _t < 6.0:
				return false
			var found: Dictionary = _outlines()
			for label in WANT:
				_check("%s gives an outline" % label, found.has(label))
				if found.has(label):
					var w: float = _middle(found[label]).w
					_check("  at w %+.1f" % float(WANT[label]), absf(w - float(WANT[label])) < 0.6, "w %+.2f" % w)
			# Move the Lookout's site 10 m along x: the tower, marsh and owl were placed off it, the
			# tower is under it, so the tower's outline moves at once.
			var before: Vector4 = _middle(found["Watchstone"])
			var site := _room.get_node("World/LookoutSite") as Node4D
			site.position += Vector4(10.0, 0.0, 0.0, 0.0)
			var after: Vector4 = _middle(_outlines()["Watchstone"])
			_check("moving the site moves the Lookout's outline", absf(after.x - before.x - 10.0) < 0.01, "%+.2f m" % (after.x - before.x))
			site.position -= Vector4(10.0, 0.0, 0.0, 0.0)
			# Met Wren already, so walking up to the tower plays no cutscene (which hides the HUD).
			var lookout: Node = _room.get_node_or_null("Systems/Lookout")
			if lookout != null:
				for f in ["approached", "met_wren"]:
					lookout.get("journal").call("set_flag", f, true)
			_player = _room.get_node("Player") as Node4D
			var tower: Vector4 = (_room.get_node("World/LookoutSite/Lookout") as Node4D).global_position
			var marsh: Vector4 = (_room.get_node("World/AnaMarsh") as Node4D).global_position
			_spots = [["pen", Vector4(4.0, 0.05, -2.0, 0.0)], ["tower", tower + Vector4(9.0, 0.05, 9.0, 0.0)],
				["cave", Vector4(16.5, 0.05, -20.0, 0.0)], ["marsh_w0", Vector4(marsh.x + 9.0, 0.05, marsh.z + 6.0, 0.0)],
				["marsh_w8", Vector4(marsh.x + 9.0, 0.05, marsh.z + 6.0, marsh.w)]]
			_step = 0
			_player.global_position = _spots[0][1]
			_wait = 1.5
		_:
			if _step < _spots.size():
				root.get_texture().get_image().save_png("res://smoke_test_output/dial_places_%s.png" % _spots[_step][0])
				_step += 1
				if _step < _spots.size():
					_player.global_position = _spots[_step][1]
					_wait = 1.5
					return false
			print("DIAL PLACES %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
			if FileAccess.file_exists("user://lookout_journal_dial_places_test.cfg"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_dial_places_test.cfg"))
			return true
	return false
