extends SceneTree

## Slides I, II, IV and V (theatre/theatre_primer_4d.gd): do the exhibits do what their
## captions say, and does slide V answer your hands?
##
##   I    the sheet cuts the ghost ball into a disc and the cone into a triangle, the flat
##        view shows it, and the chicken jumps when something appears in its world
##   II   the 4D ball really crosses your slice (its w goes through zero), and the
##        corner-first turn really stands the tesseract's long diagonal along W
##   IV   all five shapes come up, in order, and each is turned through W while it is up
##   V    a right-button drag turns the shape, the wheel changes it, and turning the left
##        glove half way round through W makes it a right glove
##
## SEATED, because slide V only takes the controls from somebody in the chair - on your
## feet the same drag turns your own slice. The input is handed to the primer directly:
## the dummy display driver does not reliably carry a parsed event through to
## _unhandled_input (see _verify_after_show_runner), and what is under test is what the
## primer does with the event, not Godot's event routing.

## Constants are not readable through get(), so the script itself is asked.
const PRIMER := preload("res://ramon/chickenpen/theatre/theatre_primer_4d.gd")

var _root: Node
var _f := 0
var _fails: Array = []
var _show: Node
var _primer: Node
var _seat: Node
var _player: CharacterBody4D
var _sat := false
var _max_strips := 0
var _max_cone := 0
var _flat_seen := false
var _hopped := false
var _ball_min_w := INF
var _corner_ok := false
var _shadow_seen := false
var _zoo_order: Array = []
var _zoo_turned: Array = []
var _toy_tried := false
var _toy_turned := false
var _toy_swapped := false
var _glove_tried := false
var _glove_matched := false
var _last_act := -9


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-48s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		_show = _root.get_node("Show")
		_seat = _root.get_node("UI/Seat")
		_player = _root.get_node("Player") as CharacterBody4D
		_show.set("opening_seconds", 0.6)
		_show.set("act_seconds", 4.0)
		_show.set("hold_on_seat_seconds", 0.1)
		_show.set("after_sit_seconds", 0.2)
		_seat.set("sit_seconds", 0.3)
		return false
	if _f == 3:
		var stage: Node4D = _root.get_node("Stage") as Node4D
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.set_physics_process(false)
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18,
			lerpf(top.z, foot.z, 0.5), 0.0)
		return false
	if not _sat and bool(_seat.call("is_offering")):
		_sat = true
		_seat.call("sit")
	if _primer == null:
		_primer = _show.get_node_or_null("Primer")
		if _primer == null:
			if _f > 200:
				print("   FAIL the show has no primer")
				quit(1)
				return true
			return false

	var act: int = int(_show.call("current_act"))
	var phase: float = float(_show.get("_phase"))
	var span: float = float(_show.call("_length", maxi(act, 0)))
	var tau: float = phase / maxf(span, 0.01)
	var screen: Node = _root.get_node("UI/Screen")
	match act:
		0:
			var lit := 0
			for strip in (_primer.get("_ball_cut") as Array):
				if (strip as Node4D).visible:
					lit += 1
			_max_strips = maxi(_max_strips, lit)
			var cone := 0
			for strip in (_primer.get("_cone_cut") as Array):
				if (strip as Node4D).visible:
					cone += 1
			_max_cone = maxi(_max_cone, cone)
			if String(screen.call("mode")) == "flat":
				_flat_seen = true
			var bird: Node4D = _primer.get("_chicken") as Node4D
			if bird != null and bird.position.y > PRIMER.FLOOR_Y + 0.1:
				_hopped = true
		1:
			var ball: Node4D = _primer.get("_ball") as Node4D
			if ball != null and ball.visible:
				_ball_min_w = minf(_ball_min_w, absf(ball.position.w))
			var pivot: Node4D = _primer.get("_cube_pivot") as Node4D
			if pivot != null and pivot.visible and tau > 0.75:
				var d: Vector4 = pivot.basis * Vector4(0.5, 0.5, 0.5, 0.5)
				_corner_ok = _corner_ok or d.distance_to(Vector4(0.0, 0.0, 0.0, 1.0)) < 0.01
			if String(screen.call("mode")) == "shadow":
				_shadow_seen = true
		3:
			var zoo: Array = _primer.get("_zoo")
			for i in zoo.size():
				var pivot: Node4D = zoo[i]
				if pivot.visible and (_zoo_order.is_empty() or _zoo_order[-1] != i):
					_zoo_order.append(i)
				var turned: bool = pivot.basis.w.distance_to(Vector4(0.0, 0.0, 0.0, 1.0)) > 0.05
				if pivot.visible and turned and not _zoo_turned.has(i):
					_zoo_turned.append(i)
		4:
			var stage: String = String(_primer.get("_toy_stage"))
			if stage == "shapes" and not _toy_tried and tau > 0.1:
				_toy_tried = true
				var before: float = float(_primer.get("_toy_xw"))
				var index: int = int(_primer.get("_toy_index"))
				_drag(Vector2(-120.0, 40.0))
				_toy_turned = absf(float(_primer.get("_toy_xw")) - before) > 0.3
				var wheel := InputEventMouseButton.new()
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				_primer.call("_unhandled_input", wheel)
				_toy_swapped = int(_primer.get("_toy_index")) != index
			if stage == "gloves" and not _glove_tried:
				_glove_tried = true
				# Half a turn through W, in the direction a drag to the left turns it.
				var pixels: float = PI / float(_primer.get("turn_per_pixel"))
				for i in 20:
					_drag(Vector2(-pixels / 20.0, 0.0))
				_glove_matched = bool(_primer.call("glove_done"))
	if act == 5 and _last_act == 4:
		return _report()
	_last_act = act
	if _f > 40000:
		print("   FAIL never got through slide V (act %d)" % act)
		return _report()
	return false


## A right-button drag, the way the primer reads it: the action held, the motion relative.
func _drag(by: Vector2) -> void:
	Input.action_press(&"rotate_4d")
	var motion := InputEventMouseMotion.new()
	motion.relative = by
	_primer.call("_unhandled_input", motion)
	Input.action_release(&"rotate_4d")


func _report() -> bool:
	print("\n--- I. what you see is a slice ---")
	_check("the sheet cuts the ball into a disc", _max_strips > 12,
		"%d strips lit at the widest" % _max_strips)
	_check("and the cone into a triangle", _max_cone > 12, "%d strips lit" % _max_cone)
	_check("the flat view shows the chicken's world", _flat_seen, "the screen in flat mode")
	_check("and the chicken jumps when it appears", _hopped, "off its floor line")
	print("\n--- II. things arrive from nowhere ---")
	_check("the 4D ball crosses your slice", _ball_min_w < 0.08,
		"closest to w = 0: %.3f" % _ball_min_w)
	_check("corner first means the long diagonal along W", _corner_ok,
		"(1, 1, 1, 1) turned onto (0, 0, 0, 1)")
	_check("and its shadow is on the screen", _shadow_seen, "the screen in shadow mode")
	print("\n--- IV. shapes with no 3D twin ---")
	_check("all five come up, in order", _zoo_order == [0, 1, 2, 3, 4], "%s" % [_zoo_order])
	_check("and each is turned through W while it is up", _zoo_turned.size() == 5,
		"%d of 5" % _zoo_turned.size())
	print("\n--- V. now you turn it ---")
	_check("a right-button drag turns it", _toy_tried and _toy_turned, "the x-w angle moved")
	_check("and the wheel changes the shape", _toy_swapped, "next one along")
	_check("half a turn through W makes a left glove a right one", _glove_tried and _glove_matched,
		"matched and snapped")
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
