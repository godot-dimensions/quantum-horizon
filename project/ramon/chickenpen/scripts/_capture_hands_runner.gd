extends SceneTree

## Slide VI's lofted hands, photographed: as the house sees them, then the left hand turned
## in 3D (it must stay a left hand), then turned through W a step at a time until it is a
## right one. Also prints what each hand costs: tetrahedra, the loft's own time, and the
## loft's soundness checks (folds, slivers, holes), which the cinema skips at run time.
##
## Windowed (--headless has no rendering device). Writes
## res://smoke_test_output/theatre_hands/hands_<nn>_<what>.png.

const Hand := preload("res://ramon/chickenpen/theatre/theatre_hand_4d.gd")
const Loft := preload("res://ramon/chickenpen/scripts/loft_builder_4d.gd")
const OUT := "res://smoke_test_output/theatre_hands"

var _root: Node
var _show: Node
var _seat: Node
var _player: CharacterBody4D
var _primer: Node
var _f := 0
var _t := 0.0
var _step := "start"
var _shots: Array = []
var _n := 0
var _wait := 0


func _initialize() -> void:
	root.unfocusable = true
	_report_cost()
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


## What a hand costs, and whether its loft is sound: built here on the main thread, once with
## the checks on, so the numbers are the loft's own.
func _report_cost() -> void:
	for right in [false, true]:
		var t0: int = Time.get_ticks_usec()
		var hand: ArrayTetraMesh4D = Hand.build(right)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		print("%s hand: %d tetrahedra, %d colours along its sections, lofted in %.0f ms" % [
			"right" if right else "left", hand.get_simplex_cell_vertex_indices().size() / 4,
			(hand.get_meta("loft_ramp", PackedColorArray()) as PackedColorArray).size(), ms])
	# The checks, chain by chain, on the left hand: they print only when something is wrong.
	print("loft checks (silent means sound):")
	var side: float = 1.0
	print("  palm")
	Loft.build(Hand._palm_sections(side), Hand.PALM_RINGS, Hand.PALM_SIDES, true, true, true, Hand.SMOOTHING, true)
	for finger in Hand.FINGERS:
		print("  %s" % finger["name"])
		Loft.build(Hand._finger_sections(finger, side), Hand.FINGER_RINGS, Hand.FINGER_SIDES, true, true, true,
			Hand.SMOOTHING, true)
	print("  thumb, with the ball of the thumb")
	Loft.build(Hand._thumb_sections(side), Hand.FINGER_RINGS, Hand.FINGER_SIDES, true, true, true, Hand.SMOOTHING, true)
	print("  cuff")
	Loft.build(Hand._chain(Hand.CUFF, side, Hand.CUFF_COLOUR), Hand.PALM_RINGS, Hand.PALM_SIDES, true, true, true,
		Hand.SMOOTHING, true)


func _process(delta: float) -> bool:
	_f += 1
	_t += delta
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _f == 1:
		_show = _root.get_node("Show")
		_seat = _root.get_node("UI/Seat")
		_player = _root.get_node("Player") as CharacterBody4D
		_primer = _show.get_node("Primer")
		_show.set("opening_seconds", 2.0)
		_show.set("hold_on_seat_seconds", 0.3)
		_show.set("after_sit_seconds", 0.3)
		# Long enough that the talk never turns the hand for us mid-shoot.
		_show.set("act_seconds", 400.0)
		_seat.set("sit_seconds", 0.3)
		return false
	if _f == 3:
		var stage: Node4D = _root.get_node("Stage") as Node4D
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.set_physics_process(false)
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18, lerpf(top.z, foot.z, 0.5), 0.0)
		return false
	if _t > 90.0:
		print("HANDS FAIL: stuck at %s after 90 s" % _step)
		quit(1)
		return true
	match _step:
		"start":
			if bool(_seat.call("is_offering")):
				_seat.call("sit")
				_step = "sat"
		"sat":
			if int(_show.call("current_act")) >= 0:
				_show.call("_enter", 5)
				# The slide's own dolly, run in three seconds instead of the act's length, so
				# the pictures are framed as the house sees the hands at the end of the move.
				_root.get_node("ShotCamera").call("shoot", "gloves", 3.0)
				_step = "settle"
				_t = 0.0
		"settle":
			# The shot camera eases in over a few seconds; wait for it to arrive.
			if _t > 6.0:
				_plan()
				_step = "shoot"
		"shoot":
			if _wait > 0:
				_wait -= 1
				return false
			if _n > 0:
				var path: String = "%s/hands_%02d_%s.png" % [OUT, _n - 1, _shots[_n - 1][0]]
				root.get_texture().get_image().save_png(path)
				print("saved %s" % path.get_file())
			if _n >= _shots.size():
				print("%d pictures" % _n)
				quit()
				return true
			_primer.set("_hand_turn", _shots[_n][1])
			_n += 1
			_wait = 3
	return false


## The turns to photograph, each [name, the left hand's basis]. In 3D: about the vertical
## and tipped back; through W: in the plane of the picture's sideways and W.
func _plan() -> void:
	var axes: Array = _primer.call("_view_axes")
	var right: Vector4 = axes[0]
	var toward: Vector4 = axes[1]
	var up: Vector4 = axes[2]
	var w := Vector4(0.0, 0.0, 0.0, 1.0)
	var id := Projection.IDENTITY
	var p := _primer
	_shots = [
		["as_seen", id],
		["3d_quarter_turn", p.call("_turned", id, toward, right, PI * 0.5)],
		["3d_back", p.call("_turned", id, toward, right, PI)],
		["3d_three_quarter", p.call("_turned", id, toward, right, PI * 0.25)],
		["3d_tipped", p.call("_turned", p.call("_turned", id, toward, right, PI * 0.25), toward, -up, 0.6)],
		["w_30", p.call("_turned", id, right, w, -PI / 6.0)],
		["w_60", p.call("_turned", id, right, w, -PI / 3.0)],
		["w_90", p.call("_turned", id, right, w, -PI * 0.5)],
		["w_135", p.call("_turned", id, right, w, -PI * 0.75)],
		["w_180_right", p.call("_turned", id, right, w, -PI)],
		["w_180_then_3d", p.call("_turned", p.call("_turned", id, right, w, -PI), toward, right, 0.5)],
	]
