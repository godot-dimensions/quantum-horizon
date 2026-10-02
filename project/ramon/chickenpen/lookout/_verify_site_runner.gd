extends SceneTree

## The site moves as one: LookoutSite put somewhere else and turned a quarter before the scene
## starts, and everything is checked to have gone with it - the tower, Wren, the owl's tree and
## the owl, the balloon's mooring, the marsh and the kata wood (still at w +8 and -8), and the
## balloon's ride still reaching the marsh. Saves res://smoke_test_output/site_<n>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_site_runner.gd

const MOVE := Vector4(14.0, 0.0, 10.0, 0.0)
const TURN := PI * 0.5

var _room: Node
var _lookout: Node
var _t: float = 0.0
var _step: int = 0
var _failed: int = 0
var _site: Node4D
var _was: Dictionary = {}


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", "user://lookout_journal_site_test.cfg")
	_site = _room.get_node("World/LookoutSite")
	# Where things were, relative to the site, before the move.
	var origin: Vector4 = _site.position
	for path in ["Lookout", "Wren", "MooringSpot", "MarshSpot", "WoodSpot"]:
		_was[path] = (_site.get_node(path) as Node4D).position
	_site.position = origin + MOVE
	_site.basis = Basis4D.from_zx(TURN)
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-62s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _process(d: float) -> bool:
	_t += d
	match _step:
		0:
			if _t < 3.0:
				return false
			var site: Vector4 = _site.global_position
			var turn: Projection = _site.global_basis
			var tower: Node4D = _lookout.get("tower")
			_check("the tower went with the site", tower.global_position.distance_to(site) < 0.01, str(tower.global_position))
			var wren: Node4D = _lookout.get("wren")
			_check("Wren went with it, turned with it", wren.global_position.distance_to(site + turn * (_was["Wren"] as Vector4)) < 0.01, str(wren.global_position))
			var perch: Vector4 = tower.call("ana_perch")
			_check("the owl's tree and the owl are at the tower's north side", (_lookout.get("owl") as Node4D).global_position.distance_to(perch) < 0.1)
			var balloon: Node4D = _lookout.get("balloon")
			_check("the balloon's mooring is the site's", (balloon.get("_moor") as Vector4).distance_to(site + turn * (_was["MooringSpot"] as Vector4)) < 0.01)
			var marsh: Node4D = _lookout.get("marsh")
			var wood: Node4D = _lookout.get("wood")
			_check("the marsh is the site's, out at w +8", marsh.global_position.distance_to(site + turn * (_was["MarshSpot"] as Vector4)) < 0.01 and absf(marsh.global_position.w - 8.0) < 0.01)
			_check("the kata wood is the site's, out at w -8", wood.global_position.distance_to(site + turn * (_was["WoodSpot"] as Vector4)) < 0.01 and absf(wood.global_position.w + 8.0) < 0.01)
			# The ride, turned with the site, still goes over the marsh at its far point.
			balloon.call("set_ready", true, true)
			_lookout.get("journal").call("set_flag", "approached", true)
			_lookout.get("journal").call("set_flag", "met_wren", true)
			balloon.call("board")
			balloon.set("ride_speed", 0.0001)
			balloon.set("ride_time", 122.0)
			_step = 1
			_t = 0.0
		1:
			if _t < 0.5:
				return false
			var balloon: Node4D = _lookout.get("balloon")
			var marsh: Node4D = _lookout.get("marsh")
			var gap: Vector4 = balloon.global_position - marsh.global_position
			_check("the turned ride still reaches the marsh", Vector2(gap.x, gap.z).length() < 9.0 and absf(gap.w) < 0.5, "%.1f m off, w %+.1f" % [Vector2(gap.x, gap.z).length(), gap.w])
			root.get_texture().get_image().save_png("res://smoke_test_output/site_0_over_the_marsh.png")
			print("SITE RUNNER: %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
			if FileAccess.file_exists("user://lookout_journal_site_test.cfg"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_site_test.cfg"))
			return true
	return false
