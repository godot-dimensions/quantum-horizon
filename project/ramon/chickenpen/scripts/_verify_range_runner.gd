extends SceneTree

## To the shooting gallery and back, and nothing in the pen lost on the way.
##
## The range master has to be talkable from the booth; saying yes has to park the pen and
## open res://ramon/ShootingGalleryRamon/shooting_gallery_ramon.tscn as the current scene,
## tick the checklist, and relabel the gallery's return prompt; its key has to bring back
## THE SAME pen, with what was in the belt still in it. And the gallery opened on its own,
## the way the menu opens it, must still say it goes back to the menu. Headless.

const QUESTS := preload("res://ramon/chickenpen/scripts/pen_quests_4d.gd")
const GALLERY := "res://ramon/ShootingGalleryRamon/shooting_gallery_ramon.tscn"

var _room: Node
var _room_id := 0
var _f := 0
var _fails := 0
var _step := 0
var _wait := 0
var _solo: Node


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room
	_room_id = _room.get_instance_id()


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-52s %s" % ["PASS" if ok else "FAIL", what, detail])


func _label_of(gallery: Node) -> String:
	var button: Node = gallery.get_node_or_null("ReturnButton")
	return String(button.call("get_label_text")) if button != null else "(no button)"


## Counted in drawn frames - see _verify_cave_runner.gd for why.
func _process(_d: float) -> bool:
	_f += 1
	if _f < 15:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			_room.get_node("UI/Inventory").call("add_item", "found_watch")
			var head: Node4D = _room.get_node("World/RangeMasterHead")
			var player := _room.get_node("Player") as CharacterBody4D
			player.global_position = Vector4(head.global_position.x + 1.6, 0.05, head.global_position.z, 0.0)
			player.linear_velocity = Vector4.ZERO
			_step = 1
			_wait = 4
		1:
			var driver: Node = _room.get_node("Systems/RangeMasterDriver")
			_check("the range master can be talked to at the booth", bool(driver.call("_can_talk")))
			# Saying yes, then the conversation closing.
			driver.call("_on_effect", "go_range")
			driver.call("_ended")
			_step = 2
			_wait = 6
		2:
			var now: Node = current_scene
			_check("yes opens the shooting gallery", now != null and now.scene_file_path == GALLERY, now.scene_file_path if now != null else "none")
			_check("the pen is parked, not freed", is_instance_valid(instance_from_id(_room_id)) and not _room.is_inside_tree())
			_check("the checklist's range line ticks", QUESTS._visited.has("range"))
			_check("the gallery's way back says the pen", _label_of(now).contains("CHICKEN PEN"), "\"%s\"" % _label_of(now))
			var ev := InputEventKey.new()
			ev.keycode = KEY_H
			ev.pressed = true
			now.get_node("WayHome").call("_input", ev)
			_step = 3
			_wait = 6
		3:
			_check("its key brings back the same pen", current_scene == _room and _room.is_inside_tree())
			_check("with the belt as it was", bool(_room.get_node("UI/Inventory").call("has_item", "found_watch")))
			_check("and the pen's camera in charge", bool(_room.get_node("Player/CameraRig/Pitch/Camera4D").get("current")))
			var farm_bed: AudioStreamPlayer = _room.get_node("Systems/Sfx").get_node_or_null("Ambience")
			_check("and the farm's sound back on", farm_bed == null or farm_bed.playing)
			_check("and the way home taken down", not root.has_meta("chickenpen_way_home"))
			var gone := true
			for child in root.get_children():
				if child.scene_file_path == GALLERY:
					gone = false
			_check("and the gallery gone", gone)
			# The gallery on its own, as the menu opens it.
			_solo = load(GALLERY).instantiate()
			root.add_child(_solo)
			_step = 4
			_wait = 4
		4:
			_check("opened on its own it still goes back to the menu", _label_of(_solo).contains("MENU") and not _label_of(_solo).contains("PEN"), "\"%s\"" % _label_of(_solo))
			print("\n%d FAIL(s)" % _fails)
			quit(1 if _fails > 0 else 0)
			return true
	return false
