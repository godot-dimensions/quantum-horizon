extends SceneTree

## The Lookout's loose ends, one at a time:
##
##   what=white      the white starling: from the cab, the long lens on bird 2731, focused on
##                   its W - is it drawn white, and does the photo land on its page?
##   what=marsh      the marsh on foot: step out to w +8 and it is there; walk up to the heron
##                   and it lifts off
##   what=showcase   the creature showcase (Model/rigged_creature_ramon.tscn) loads with the
##                   owl and the heron built, and frames of both
##
## Windowed, small, unfocused; saves res://smoke_test_output/extras_<what>_<n>_<view>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_extras_runner.gd -- what=white

const TEST_BOOK := "user://lookout_journal_extras_test.cfg"

var _what: String = "white"
var _room: Node
var _lookout: Node
var _t: float = 0.0
var _step: int = 0
var _failed: int = 0
var _n: int = 0
var _wait: float = 0.0
var _cam: Camera4D


func _initialize() -> void:
	root.unfocusable = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("what="):
			_what = arg.substr(5)
	_clean()
	var path: String = "res://ramon/Model/rigged_creature_ramon.tscn" if _what == "showcase" else "res://ramon/chickenpen/playable_world.tscn"
	_room = load(path).instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node_or_null("Systems/Lookout")
	if _lookout != null:
		_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-62s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(view: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/extras_%s_%d_%s.png" % [_what, _n, view])
	_n += 1


func _next(after: float = 0.0) -> void:
	_step += 1
	_wait = after
	_t = 0.0


func _look(cam: Camera4D, eye: Vector4, at: Vector4) -> void:
	cam.global_position = eye
	var d: Vector4 = at - eye
	cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))


func _process(d: float) -> bool:
	_t += d
	if _t < _wait:
		return false
	var done: bool = false
	match _what:
		"white":
			done = _white()
		"marsh":
			done = _marsh()
		"showcase":
			done = _showcase()
	if done:
		_clean()
		print("EXTRAS RUNNER (%s): %s (%d failed)" % [_what, "PASS" if _failed == 0 else "FAIL", _failed])
	return done


var _white_seen: Dictionary = {}


func _white() -> bool:
	var station: Node = _lookout.get("station") if _lookout else null
	match _step:
		0:
			if _t < 3.0:
				return false
			for f in ["approached", "met_wren", "first_climb", "first_photo", "owl_found", "owl_hint"]:
				_lookout.get("journal").call("set_flag", f, true)
			var flock: Node4D = _room.get_node("World/Flock")
			_check("the flock has its white bird", int(flock.get("white_bird")) == int(_lookout.get("white_starling")), str(flock.get("white_bird")))
			var player := _room.get_node("Player") as Node4D
			player.global_position = (_lookout.get("tower") as Node4D).call("ladder_foot") + Vector4(0, 0.05, 0.3, 0)
			_next(0.6)
		1:
			station.call("climb")
			_next(float(station.get("climb_seconds")) + 0.8)
		2:
			_aim_white(station)
			station.set("zoom_goal", 12.0)
			_next(1.2)
		3:
			_aim_white(station)
			_next(0.05)
		4:
			_aim_white(station)
			_save("white_aimed")
			station.call("take_photo")
			_next(0.6)
		5:
			var recent: Array = _lookout.get("journal").get("recent")
			var last: Dictionary = recent.back() if not recent.is_empty() else {}
			print("      photo: ", last)
			_check("the photo found the white starling", String(last.get("page", "")) == "white_starling" or bool(_lookout.get("journal").call("found", "white_starling")),
				str(_white_seen))
			_save("white_after")
			return true
	return false


func _aim_white(station: Node) -> void:
	var flock: Node4D = _room.get_node("World/Flock")
	var i: int = int(flock.get("white_bird"))
	var positions: PackedVector4Array = flock.call("positions")
	if i < 0 or i >= positions.size():
		return
	var p: Vector4 = flock.global_basis * positions[i] + flock.global_position
	var eye: Vector4 = station.call("home_eye")
	station.call("look_along", p - eye)
	station.set("focus", clampf(p.w - eye.w, -3.0, 3.0))
	station.set("focus_goal", clampf(p.w - eye.w, -3.0, 3.0))
	if int(station.get("mode")) == 5:
		station.call("_place_held_camera")
	else:
		station.call("_place_camera", eye)
	_white_seen = {"bird": str(p), "distance": "%.1f" % (p - eye).length()}


func _marsh() -> bool:
	var player := _room.get_node("Player") as Node4D
	var heron: Node4D = _lookout.get("heron") if _lookout else null
	match _step:
		0:
			if _t < 3.0:
				return false
			_lookout.get("journal").call("set_flag", "approached", true)
			var marsh: Node4D = _lookout.get("marsh")
			# On the far side of the pond from the heron, at the marsh's W, looking across.
			player.global_position = marsh.global_position + Vector4(-9.0, 0.05, 2.0, 0.0)
			player.set("linear_velocity", Vector4.ZERO)
			_next(1.0)
		1:
			_check("standing out at w +8, inside the bounds", absf(player.global_position.w - 8.0) < 0.3, str(player.global_position))
			var rig: Node = _room.get_node("Player/CameraRig")
			var to: Vector4 = heron.global_position - player.global_position
			rig.set("yaw", atan2(-to.x, -to.z))
			rig.set("pitch", -0.25)
			rig.call("_apply")
			_next(0.8)
		2:
			_save("marsh_on_foot")
			_check("the heron is still fishing with you that far off", int(heron.get("state")) < 5, str(heron.get("state")))
			# Then straight up to it.
			player.global_position = heron.global_position + Vector4(-4.0, 0.05, 1.0, 0.0)
			player.set("linear_velocity", Vector4.ZERO)
			_next(0.5)
		3:
			_check("walk up to the heron and it lifts off", int(heron.get("state")) >= 5, str(heron.get("state")))
			_next(0.8)
		4:
			_save("heron_flushed")
			_next(5.5)
		5:
			_check("and lands again, on the far bank", int(heron.get("state")) < 5 and heron.global_position.y < 0.5, str(heron.global_position))
			_save("heron_landed")
			# Back at the farm's slice the marsh is not there.
			player.global_position = Vector4(-26.0, 0.05, -14.0, 0.0)
			player.set("linear_velocity", Vector4.ZERO)
			var rig: Node = _room.get_node("Player/CameraRig")
			rig.set("yaw", 0.0)
			rig.set("pitch", -0.2)
			rig.call("_apply")
			_next(0.8)
		6:
			_save("marsh_gone_at_w0")
			return true
	return false


func _showcase() -> bool:
	match _step:
		0:
			if _t < 3.0:
				return false
			var owl := _room.get_node_or_null("Owl") as Node4D
			var heron := _room.get_node_or_null("Heron") as Node4D
			_check("the showcase has the owl, built", owl != null and owl.get_child_count() > 10)
			_check("and the heron, built", heron != null and heron.get_node_or_null("Body") != null and heron.get_node("Body").get_child_count() > 5)
			var chip := _room.get_node_or_null("Chipmunk") as Node4D
			_check("and the chipmunk, built and idle", chip != null and chip.get_node_or_null("Body") != null and bool(chip.get("idle_only")))
			_cam = Camera4D.new()
			_cam.set("rendering_engine_name", "Cross-section")
			_cam.set("field_of_view_4d", 0.9)
			_room.add_child(_cam)
			_cam.make_current()
			_look(_cam, owl.global_position + Vector4(1.0, 0.4, 2.2, 0.0), owl.global_position + Vector4(0, 0.3, 0, 0))
			_next(0.8)
		1:
			_save("owl")
			var heron := _room.get_node("Heron") as Node4D
			_look(_cam, heron.global_position + Vector4(2.6, 1.0, 2.4, 0.0), heron.global_position + Vector4(0, 0.7, 0, 0))
			_next(0.8)
		2:
			_save("heron")
			var owl := _room.get_node("Owl") as Node4D
			_look(_cam, owl.global_position + Vector4(5.5, 2.5, 8.0, 0.0), owl.global_position + Vector4(0, 0.2, -2.0, 0))
			_next(0.8)
		3:
			_save("together")
			var chip := _room.get_node("Chipmunk") as Node4D
			_look(_cam, chip.global_position + Vector4(0.9, 0.35, 1.1, 0.0), chip.global_position + Vector4(0, 0.12, 0, 0))
			_next(0.8)
		4:
			_save("chipmunk")
			var owl := _room.get_node("Owl") as Node4D
			# Side on, for the head and the face on it.
			_look(_cam, owl.global_position + Vector4(1.6, 0.75, 0.0, 0.0), owl.global_position + Vector4(0, 0.72, 0, 0))
			_next(0.8)
		5:
			_save("owl_side")
			return true
	return false


func _clean() -> void:
	var book: String = ProjectSettings.globalize_path(TEST_BOOK)
	if FileAccess.file_exists(TEST_BOOK):
		DirAccess.remove_absolute(book)
	var photos: String = ProjectSettings.globalize_path("user://lookout_journal_extras_test_photos")
	if DirAccess.dir_exists_absolute(photos):
		for f in DirAccess.get_files_at(photos):
			DirAccess.remove_absolute(photos + "/" + f)
		DirAccess.remove_absolute(photos)
