extends SceneTree

## The black cat on its rocks, and on the ground (Ramon, 3 Oct: "the black cat jumps on the box
## but then it starts walking in the air"). It starts sat on the pile; made to hop down it lands
## on the floor and walks on it; sent back it jumps up and sits on the seat stone; down again,
## on the floor again. Prints the heights and PASS or FAIL per check; saves the cat at each
## stage, res://smoke_test_output/cat_ground_<n>.png. Gives up after 80 s.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/scripts/_verify_cat_ground_runner.gd

const SIT := 3
const WANDER := 0
const TO_CRATE := 1

var _room: Node
var _cat: Node4D
var _pile: Node4D
var _cam: Camera4D
var _t: float = 0.0
var _step: int = -1
var _wait: float = 0.0
var _fails: int = 0
var _lowest: float = 1e9
var _highest: float = -1e9


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", what, detail])


func _shot(n: int) -> void:
	# A camera of its own, beside the cat, so the frame shows its feet against the rocks.
	_cam.global_position = _cat.global_position + Vector4(2.2, 1.0, 2.2, 0.0)
	_cam.look_at(_cat.global_position + Vector4(0.0, 0.3, 0.0, 0.0))
	_cam.make_current()
	root.get_texture().get_image().save_png("res://smoke_test_output/cat_ground_%d.png" % n)


func _process(d: float) -> bool:
	_t += d
	if _t > 80.0:
		print("CAT GROUND FAIL: timed out at step %d" % _step)
		return true
	_wait -= d
	if _cat != null and (_step == 1 or _step == 4):
		_lowest = minf(_lowest, _cat.position.y)
		_highest = maxf(_highest, _cat.position.y)
	if _wait > 0.0:
		return false
	if _step == -1:
		if _t < 4.0:
			return false
		_cat = _room.get_node("World/Cat") as Node4D
		_pile = _room.get_node("World/RockPile") as Node4D
	var seat: float = _pile.position.y + float(_pile.get("top"))
	var mood: int = int(_cat.get("_mood"))
	match _step:
		-1:
			_cam = Camera4D.new()
			_cam.set("rendering_engine_name", "Cross-section")
			_room.add_child(_cam)
			for c in _room.get_node("UI").get_children():
				if c is CanvasItem:
					(c as CanvasItem).visible = false
			_check("it starts sat on the rocks", mood == SIT and absf(_cat.position.y - (seat + 0.04)) < 0.06,
				"y %.2f, the seat's top %.2f" % [_cat.position.y, seat])
			_shot(0)
			# Down it gets.
			_cat.set("_mood_left", 0.0)
			_step = 1
			_wait = 3.5
		1:
			_check("it hops down onto the floor", absf(_cat.position.y) < 0.03, "y %.3f" % _cat.position.y)
			_check("and walks on it", mood == WANDER and _highest < seat + 0.6, "mood %d" % mood)
			_shot(1)
			_lowest = 1e9
			_highest = -1e9
			_step = 2
			_wait = 4.0
		2:
			_check("still on the floor four seconds on", absf(_cat.position.y) < 0.03, "y %.3f" % _cat.position.y)
			# Back to the rocks: from a metre and a half off, walking.
			_cat.set("_mood", TO_CRATE)
			_step = 3
		3:
			if mood == SIT:
				_check("it jumps up and sits on the seat stone", absf(_cat.position.y - (seat + 0.04)) < 0.06,
					"y %.2f" % _cat.position.y)
				var flat := Vector2(_cat.position.x - _pile.position.x, _cat.position.z - _pile.position.z)
				_check("on the seat, not beside it", flat.length() < 0.3, "%.2f m from the middle" % flat.length())
				_shot(2)
				_cat.set("_mood_left", 0.0)
				_step = 4
				_wait = 3.5
			elif _t > 60.0:
				_check("it jumps up and sits on the seat stone", false, "mood %d, y %.2f" % [mood, _cat.position.y])
				_step = 4
		4:
			_check("and down onto the floor again", absf(_cat.position.y) < 0.03, "y %.3f" % _cat.position.y)
			_shot(3)
			print("CAT GROUND %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
			return true
	return false
