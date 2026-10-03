extends SceneTree

## Portraits of the Lookout's creatures, for judging the models by eye: front, three
## quarters, side, back, and each behaviour mid-way. In the pen (for its light and sky), on
## an empty patch of field, at w 0, with a camera of its own.
##
## Windowed, small, unfocused; saves res://smoke_test_output/creature_<what>_<n>_<view>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_capture_creature_runner.gd -- creature=owl

const SCRIPTS := {
	"owl": "res://ramon/chickenpen/lookout/owl_4d.gd",
	"heron": "res://ramon/chickenpen/lookout/heron_4d.gd",
	"balloon": "res://ramon/chickenpen/lookout/balloon_4d.gd",
	"chipmunk": "res://ramon/chickenpen/lookout/chipmunk_4d.gd",
}
## [name, yaw of the camera round the creature, height, distance, behaviour to show, seconds into it]
const VIEWS := {
	"owl": [["front", 0.0, 0.35, 1.5, "", 0.0], ["three_quarter", 0.7, 0.4, 1.5, "", 0.0], ["side", 1.57, 0.35, 1.5, "", 0.0],
		["back", 3.14, 0.4, 1.6, "", 0.0], ["look", 0.0, 0.35, 1.3, "look", 1.5], ["turn_w_mid", 0.0, 0.4, 1.3, "turn_w", 1.3],
		["turn_w_full", 0.0, 0.4, 1.3, "turn_w", 1.7], ["stretch", 0.4, 0.35, 1.8, "stretch", 1.4], ["hoot", 0.3, 0.35, 1.4, "hoot", 0.4],
		["far", 0.0, 1.2, 6.0, "", 0.0]],
	# The heron's views run on from one another (the last six are one flight), so their
	# seconds add up: a capture lands view[5] + 0.25 s after its view starts.
	"heron": [["front", 0.0, 0.9, 3.2, "", 0.0], ["three_quarter", 0.7, 1.0, 3.2, "", 0.0], ["side", 1.57, 0.9, 3.4, "", 0.0],
		["back", 3.14, 1.0, 3.2, "", 0.0], ["one_leg", 1.2, 0.9, 3.2, "one_leg", 1.5],
		["stalk_swing", 1.57, 0.8, 3.4, "stalk", 0.15], ["stalk_pause", 1.57, 0.8, 3.4, "", 0.3],
		["strike_coiled", 1.57, 0.7, 3.0, "strike", 0.2], ["strike_stab", 1.57, 0.7, 3.0, "", 0.0], ["strike_after", 1.2, 0.8, 3.0, "", 0.95],
		["take_off_crouch", 0.9, 1.2, 4.5, "take_off", 0.0], ["take_off_jump", 0.9, 1.4, 5.0, "", 0.35], ["flying", 1.57, 2.5, 7.0, "", 1.0],
		["landing_glide", 1.57, 1.5, 7.0, "", 1.0], ["landing_brake", 1.57, 1.2, 7.0, "", 0.3], ["landed", 1.57, 1.0, 7.0, "", 0.6]],
	"chipmunk": [["front", 0.0, 0.16, 0.75, "sit", 0.3], ["three_quarter", 0.7, 0.2, 0.8, "sit", 0.3], ["side", 1.57, 0.14, 0.8, "sit", 0.3],
		["back", 3.14, 0.22, 0.8, "sit", 0.3], ["stuff", 0.5, 0.16, 0.7, "stuff", 2.6], ["forage", 1.57, 0.12, 0.9, "", 1.2], ["far", 0.3, 0.8, 3.5, "", 0.2]],
	"balloon": [["front", 0.0, 6.0, 22.0, "", 0.0], ["three_quarter", 0.7, 9.0, 20.0, "", 0.0], ["below", 0.3, -2.0, 14.0, "", 0.0],
		["basket", 0.5, 1.2, 4.5, "", 0.0], ["burning", 0.2, 3.0, 9.0, "burn", 0.6]],
}

var _room: Node
var _creature: Node4D
var _cam: Camera4D
var _which: String = "owl"
var _i: int = 0
var _t: float = 0.0
var _phase: int = 0
## Open field west of the pen, clear of the cave hill (which is where (14, -44) turned out to be).
var _spot := Vector4(-32.0, 0.0, -8.0, 0.0)


func _initialize() -> void:
	root.unfocusable = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("creature="):
			_which = arg.substr(9)
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	match _phase:
		0:
			if _t < 2.5:
				return false
			(_room.get_node("UI") as Node).process_mode = Node.PROCESS_MODE_DISABLED
			for child in _room.get_node("UI").get_children():
				if child is CanvasItem:
					(child as CanvasItem).visible = false
			(_room.get_node("Player") as Node4D).visible = false
			_creature = Node4D.new()
			_creature.name = "Portrait"
			_creature.set_script(load(SCRIPTS[_which]))
			if _which == "balloon":
				_spot.y = 0.0
			_creature.position = _spot
			_room.get_node("World").add_child(_creature)
			if _which == "balloon":
				_creature.call("set_ready", true, true)
			_cam = Camera4D.new()
			_cam.set("rendering_engine_name", "Cross-section")
			_cam.set("field_of_view_4d", 0.8)
			_room.add_child(_cam)
			_cam.make_current()
			_phase = 1
			_start_view()
		1:
			var view: Array = VIEWS[_which][_i]
			# Follow a creature that moves (the heron's take-off).
			if _creature.has_method("centre"):
				var c: Vector4 = _creature.call("centre")
				var dv: Vector4 = c - _cam.global_position
				_cam.global_basis = Basis4D.from_zx(atan2(-dv.x, -dv.z)) * Basis4D.from_yz(atan2(dv.y, Vector2(dv.x, dv.z).length()))
			if _t >= maxf(float(view[5]), 0.05) + 0.25:
				root.get_texture().get_image().save_png("res://smoke_test_output/creature_%s_%d_%s.png" % [_which, _i, String(view[0])])
				_i += 1
				if _i >= (VIEWS[_which] as Array).size():
					print("CREATURE PORTRAITS: %d of %s" % [_i, _which])
					return true
				_start_view()
	return false


func _start_view() -> void:
	var view: Array = VIEWS[_which][_i]
	var yaw: float = float(view[1])
	var at: Vector4 = _spot + Vector4(sin(yaw) * float(view[3]), float(view[2]), cos(yaw) * float(view[3]), 0.0)
	var look: Vector4 = _spot + Vector4(0.0, _look_height(), 0.0, 0.0)
	_cam.global_position = at
	var dv: Vector4 = look - at
	_cam.global_basis = Basis4D.from_zx(atan2(-dv.x, -dv.z)) * Basis4D.from_yz(atan2(dv.y, Vector2(dv.x, dv.z).length()))
	if String(view[4]) != "" and _creature.has_method("perform"):
		_creature.call("perform", String(view[4]))
	_t = 0.0


func _look_height() -> float:
	match _which:
		"owl":
			return 0.32
		"heron":
			return 0.75
		"chipmunk":
			return 0.1
		"balloon":
			return 7.0
	return 0.5
