extends SceneTree

## The dreamer in the far room (cave_dreamer_4d.gd, cave_dreamer_talk_4d.gd): it is there
## when the room is, F opens a conversation with it, its core is blue for a calm line and
## red for a warning, calm again once the conversation is over, and red if you crowd it.
## Also: the sheet across the way through W parts as you walk into it and closes behind you,
## and the cube stands centred on its plinth. Then its talk: threatened, it goes red and
## stays red through your step back into the line that asks whether that frightened you,
## and calms on it; and saying goodbye flashes you home, onto your back in front of the
## cave, up again, and thinking "...What was that?".
##
## Windowed, it saves res://smoke_test_output/dreamer_<n>.png: calm, warning, and one with
## the slice turned through W so its limbs cross the slice differently; and wake_<n>.png:
## lying, sitting up, standing.

const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")
const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
## The far room's middle, on its floor, and where you stand to look at it.
const ROOM := Vector4(0, 0, -36, 46)

var _room: Node
var _cave: Node4D
var _f := 0
var _step := 0
var _t := 0.0
var _failed := 0
var _windowed := false
var _tap := 0.0
var _seen_flinch := false
var _asking := -1.0
var _drops_before := 0
var _seen_tag := false
var _said_far := false


func _initialize() -> void:
	# Never takes the keyboard: typing elsewhere while this window is up must not reach
	# the pen (C opens the theatre, E and Q step through W).
	root.unfocusable = true
	_windowed = DisplayServer.get_name() != "headless"
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _player() -> CharacterBody4D:
	return _room.get_node("Player") as CharacterBody4D


func _hold(local: Vector4) -> void:
	_player().global_position = _cave.global_position + local
	_player().linear_velocity = Vector4.ZERO


func _face(local_target: Vector4) -> void:
	var rig := _player().get_node("CameraRig") as Node4D
	var d: Vector4 = _cave.global_position + local_target - _player().global_position
	rig.set("yaw", atan2(-d.x, -d.z))
	rig.set("pitch", deg_to_rad(22.0))
	rig.call("_apply")


func _save(n: int, what: String = "dreamer") -> void:
	if _windowed:
		root.get_texture().get_image().save_png("res://smoke_test_output/%s_%d.png" % [what, n])
		print("   saved %s_%d.png" % [what, n])


## Presses on through the conversation, a tap every quarter second, as a player would.
func _tap_on(d: float) -> void:
	_tap += d
	if _tap > 0.25:
		_tap = 0.0
		_far("Systems/DreamerTalk").call("_advance")


func _talk_key() -> String:
	return String(_far("Systems/DreamerTalk").get("_key"))


func _far(path: String) -> Node:
	var far: Node = _cave.find_child("FarRoom", true, false)
	return far.get_node_or_null(path) if far != null else null


func _sheet_open() -> bool:
	return bool(_cave.get_node("WaySheet").call("is_open"))


func _process(d: float) -> bool:
	_f += 1
	if _f == 10:
		_room.get_node("CaveCrossing").call("go")
	if _f == 14:
		for c in _room.get_children():
			if c.name == "Cave":
				_cave = c
		if _windowed:
			for c in ["UI/SlicePlane", "UI/Controls", "UI/Quests", "UI/InfoCard", "UI/Inventory", "UI/CameraPicker"]:
				var n := _room.get_node_or_null(c) as CanvasItem
				if n != null:
					n.visible = false
	if _f < 20:
		return false
	_t += d
	match _step:
		0:
			# The cube, centred on its plinth: the middle of its mesh, from the cave.
			var cube: Node4D = _cave.get_node("Monolith")
			var lo := Vector4(INF, INF, INF, INF)
			var hi := -lo
			for c in cube.get_children():
				if c is MeshInstance4D and c.mesh != null and c.mesh.has_method("get_vertex_positions"):
					for v: Vector4 in c.mesh.call("get_vertex_positions"):
						var g: Vector4 = c.global_basis * v + c.global_position - _cave.global_position
						lo = Vector4(minf(lo.x, g.x), minf(lo.y, g.y), minf(lo.z, g.z), minf(lo.w, g.w))
						hi = Vector4(maxf(hi.x, g.x), maxf(hi.y, g.y), maxf(hi.z, g.z), maxf(hi.w, g.w))
			var mid: Vector4 = (lo + hi) * 0.5
			_check("the cube is centred on the plinth", absf(mid.x) < 0.05 and absf(mid.z - CaveRock.CHAMBER.z) < 0.05 and absf(mid.w) < 0.05,
				"middle %s" % mid)
			_check("and stands on it", absf(lo.y - CaveRock.PLINTH_TOP) < 0.03, "bottom %.3f" % lo.y)
			_step = 1; _t = 0.0
		1:
			# Up to the sheet in the chamber, then into it.
			_hold(Vector4(0, 0.05, -36, 6.0))
			if _t > 0.6:
				_check("the sheet stands while you are in the chamber", not _sheet_open())
				_step = 2; _t = 0.0
		2:
			_hold(Vector4(0, 0.05, -36, 9.5))
			if _t > 0.8:
				_check("and parts once you step into it", _sheet_open())
				_step = 30; _t = 0.0
		30:
			# Coming in along W, as you do: fourteen metres short of it, the slice turned a
			# quarter through W so the way ahead is +w. F has to work from here, and its prompt
			# be on screen - and the room says so as you come into it.
			_hold(ROOM + Vector4(0, 0.05, 0, -14.0))
			var rig := _player().get_node("CameraRig") as Node4D
			rig.set("yaw", 0.0)
			rig.set("pitch", deg_to_rad(8.0))
			rig.set("_slice_zw", -PI * 0.5 if _t < 1.5 else PI * 0.5)
			rig.call("_apply")
			var driver: Node = _far("Systems/DreamerDriver")
			var tag := _far("UI/DreamerTag") as CanvasItem
			if driver != null and bool(driver.call("_can_talk")) and tag.visible:
				_seen_tag = true
			if _t > 3.0 and driver != null:
				_check("F works from fourteen metres along W", bool(driver.call("_can_talk")))
				_check("and its prompt is on screen coming in along W", _seen_tag)
				var thought: Node = _room.get_node("UI/ThoughtBox")
				_check("coming into the room: wow, and I sense something", _cave.has_meta(&"cave_far_first_look_said")
					and (String(thought.get("_full")) == "Wow... and I sense something." or _said_far), String(thought.get("_full")))
				rig.set("_slice_zw", 0.0)
				rig.call("_apply")
				_step = 3; _t = 0.0
			elif String(_room.get_node("UI/ThoughtBox").get("_full")) == "Wow... and I sense something.":
				_said_far = true
		3:
			# In the far room, level with the dreamer, a few metres in front of it.
			_hold(ROOM + Vector4(0, 0.05, 9.0, 0))
			_face(ROOM + Vector4(0, 10.0, 0, 0))
			if _far("Dreamer") != null and _t > 1.2:
				var dreamer: Node = _far("Dreamer")
				_check("the dreamer is there with the room", dreamer != null)
				_check("calm when you arrive", not bool(dreamer.call("is_warning")))
				var press := InputEventAction.new()
				press.action = &"catch_target"
				press.pressed = true
				Input.parse_input_event(press)
				_step = 4; _t = 0.0
		4:
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			if _t > 1.5:
				var talk: Node = _far("Systems/DreamerTalk")
				_check("F opens a conversation with it", talk != null and bool(talk.call("is_running")))
				_check("and it is calm to begin with", not bool(_far("Dreamer").call("is_warning")))
				_save(0)
				# To its warning, as if chosen.
				talk.call("stop")
				talk.call("begin", "topic_wake")
				_step = 5; _t = 0.0
		5:
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			if _t > 1.2:
				_check("a warning turns the core red", bool(_far("Dreamer").call("is_warning")))
				_save(1)
				_far("Systems/DreamerTalk").call("stop")
				_step = 6; _t = 0.0
		6:
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			if _t > 1.5:
				_check("and it calms when the talk is over", not bool(_far("Dreamer").call("is_warning")))
				var rig := _player().get_node("CameraRig") as Node4D
				rig.set("_slice_xw", deg_to_rad(35.0))
				rig.call("_apply")
				_step = 7; _t = 0.0
		7:
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			if _t > 0.8:
				_save(2)
				var rig := _player().get_node("CameraRig") as Node4D
				rig.set("_slice_xw", 0.0)
				rig.call("_apply")
				_step = 8; _t = 0.0
		8:
			# Right up against it.
			_hold(ROOM + Vector4(0, 0.05, 2.0, 0))
			if _t > 1.2:
				_check("crowding it turns it red", bool(_far("Dreamer").call("is_warning")))
				_step = 9; _t = 0.0
		9:
			_hold(Vector4(0, 0.05, -36, 20))
			if _t > 1.0:
				_step = 10; _t = 0.0
		10:
			_hold(Vector4(0, 0.05, -36, 4.0))
			if _t > 1.5:
				_check("the sheet closes behind you back in the chamber", not _sheet_open())
				_step = 11; _t = 0.0
		11:
			# Back to it, and ask whether it could end all this.
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			_face(ROOM + Vector4(0, 10.0, 0, 0))
			if _t > 1.0:
				_far("Systems/DreamerTalk").call("begin", "topic_end")
				_step = 12; _t = 0.0
		12:
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			if _t > 1.2:
				_check("the threat turns it red", bool(_far("Dreamer").call("is_warning")), _talk_key())
				_step = 13; _t = 0.0
		13:
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			_tap_on(d)
			if _talk_key() == "end_flinch":
				_seen_flinch = true
				if _t > 0.6:
					_check("and stays red while you step back", bool(_far("Dreamer").call("is_warning")))
					_save(3)
					_step = 14; _t = 0.0
			elif _t > 8.0:
				_check("the threat goes on to your step back", false, "at %s" % _talk_key())
				_step = 14; _t = 0.0
		14:
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			var talk: Node = _far("Systems/DreamerTalk")
			var box: Node = _far("UI/DreamerBox")
			if _talk_key() == "end_after" and int(talk.get("_at")) == 0 and bool(box.call("is_typing")):
				if _asking < 0.0:
					_asking = _t
					_check("still red as it asks whether that frightened you", bool(_far("Dreamer").call("is_warning")))
			elif _talk_key() != "end_after" or not bool(box.call("is_typing")):
				_tap_on(d)
			if _talk_key() == "end_after" and int(talk.get("_at")) >= 1:
				if _t > 0.8:
					_check("and calm once it has asked", not bool(_far("Dreamer").call("is_warning")))
					talk.call("stop")
					_step = 15; _t = 0.0
			elif _t > 12.0:
				_check("it goes on to ask whether that frightened you", false, "at %s" % _talk_key())
				talk.call("stop")
				_step = 15; _t = 0.0
		15:
			# Goodbye: a flash, and home.
			_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
			if _t > 0.8:
				_drops_before = int(_room.get_node("UI/Inventory").call("count_of", "found_azoth"))
				_far("Systems/DreamerTalk").call("begin", "bye")
				_step = 16; _t = 0.0
		16:
			if _far("Systems/DreamerTalk") != null and bool(_far("Systems/DreamerTalk").call("is_running")):
				_hold(ROOM + Vector4(0, 0.05, 7.0, 0))
				_tap_on(d)
			var wake: Node = _room.get_node("Systems/DreamWake")
			if bool(wake.call("is_waking")):
				_check("saying goodbye starts the waking", true)
				_step = 17; _t = 0.0
			elif _t > 8.0:
				_check("saying goodbye starts the waking", false)
				_step = 17; _t = 0.0
		17:
			if _t > 1.3 and _t - d <= 1.3:
				var crossing: Node = _room.get_node("CaveCrossing")
				_check("and you are home", not bool(crossing.call("is_away")))
				var at: Vector4 = _player().global_position
				var hill: Node4D = CaveHill.node_in(_room)
				var spot: Vector4 = CaveHill.to_world(hill, CaveHill.MOUTH + Vector4(0, 0.05, 4.5, 0))
				_check("in front of the cave", Vector2(at.x - spot.x, at.z - spot.z).length() < 0.6 and absf(at.w - spot.w) < 0.05, "at %s" % at)
				var up: Vector4 = (_player().get_node("Avatar") as Node4D).basis.y
				# Head toward the way out: +z from the mouth in the hill's frame, which turns with the cave.
				var out: Vector4 = hill.global_basis * Vector4(0, 0, 1, 0) if hill != null else Vector4(0, 0, 1, 0)
				_check("lying on your back", up.y < 0.3 and up.dot(out) > 0.7, "avatar up %s" % up)
				_save(0, "wake")
			if _t > 2.6 and _t - d <= 2.6:
				_save(1, "wake")
			if _t > 4.0:
				var up: Vector4 = (_player().get_node("Avatar") as Node4D).basis.y
				_check("and up again", up.y > 0.99, "avatar up %s" % up)
				_check("walking again", _player().is_physics_processing())
				var thought: Node = _room.get_node("UI/ThoughtBox")
				_check("wondering what that was", thought.visible and String(thought.get("_full")) == "...What was that?", String(thought.get("_full")))
				var drops: int = int(_room.get_node("UI/Inventory").call("count_of", "found_azoth"))
				_check("with a drop of azoth in your belt", drops == _drops_before + 1, "%d -> %d" % [_drops_before, drops])
				_save(2, "wake")
				print("DREAMER: %s" % ("ALL PASS" if _failed == 0 else "%d FAILED" % _failed))
				quit()
				return true
	if _f > 6000:
		print("DREAMER: TIMED OUT at step %d" % _step)
		quit()
		return true
	return false
