extends SceneTree

## The Arboretum, captured (plan steps 46, 75, 83, 95): the scene as a visitor sees it, through the
## player's own camera, in frames to look at. Windowed, unfocusable, the player's input off and the
## mouse free, so nothing of yours leaks in. Frames in smoke_test_output/arboretum/room/<set>/.
##
## Args after --: which sets ("room", "stories", "tour", "grove", "cards", "all"; default room).
##   room     the hall from the corridor, from the door, at each pedestal, the panels straight on,
##            the oak from below, and both palettes
##   stories  every part of every pedestal's story, a frame in the middle of each
##   tour     the guided tour, a frame a second
##   grove    the grove from its door, at its crossing, inside each plot, and walked ana
##   cards    each console's card open
##   volume   the volume view (V) at pedestal 02, at the oak and in the grove, each with the slice
##            view beside it
##   film     for movie mode (arb_run.sh movie): the guided tour start to finish, then a gust down
##            the hall from the door; no frames saved
## Prints the scene's open time and the frame time while it runs (vsync on: only a sanity check;
## _perf_runner.gd measures properly).

const OUT := "res://smoke_test_output/arboretum/room/"
const SCENE := "res://ramon/Arboretum/arboretum.tscn"

var _room: Node4D
var _sets: PackedStringArray
var _queue: Array = []
var _wait: int = 0
var _deadline: int = 0
var _t_open: int = 0
var _set: String = ""


func _initialize() -> void:
	root.unfocusable = true
	_sets = OS.get_cmdline_user_args()
	if _sets.is_empty():
		_sets = PackedStringArray(["room"])
	if "all" in _sets:
		_sets = PackedStringArray(["room", "stories", "cards", "tour", "grove"])
	_deadline = Time.get_ticks_msec() + 240000
	(func() -> void: _open()).call_deferred()


func _open() -> void:
	_t_open = Time.get_ticks_usec()
	var ps: PackedScene = load(SCENE)
	_room = ps.instantiate()
	root.add_child(_room)
	print("ROOM opened in %.0f ms" % ((Time.get_ticks_usec() - _t_open) / 1000.0))
	_wait = 40
	for s in _sets:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + s))
		match s:
			"room":
				_plan_room()
			"stories":
				_plan_stories()
			"cards":
				_plan_cards()
			"tour":
				_plan_tour()
			"grove":
				_plan_grove()
			"film":
				_plan_film()
			"volume":
				_plan_volume()


## A step: [frames to wait first, callable, shot name or ""].
func _step(wait: int, f: Callable, shot: String = "") -> void:
	_queue.append([wait, f, shot])


## A step that waits until `cond` is true (at most 30 s), then shoots.
func _until(cond: Callable, shot: String) -> void:
	_queue.append([1800, _nop(), shot, cond])


func _go(x: float, z: float, yaw_deg: float, w: float = 0.0) -> Callable:
	return func() -> void:
		_room.call("go_to", Vector4(x, 0.05, z, w), deg_to_rad(yaw_deg))
		var p: Node = _room.get("player")
		if p != null:
			p.set("input_enabled", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _gust() -> void:
	var w: Node = _room.call("wind")
	if w != null:
		w.set("gust_every", 0.0)
		w.call("gust")


func _nop() -> Callable:
	return func() -> void: pass


func _plan_room() -> void:
	var s := "room/"
	_step(10, _go(0, 21.5, 0), s + "01_corridor")
	_step(30, _go(0, 14.0, 0), s + "02_inside_door")
	_step(30, _go(-2.0, 10.6, 50), s + "03_at_01")
	_step(30, _go(2.4, 3.6, -50), s + "04_at_02")
	_step(30, _go(-2.0, -3.6, 50), s + "05_at_03")
	_step(30, _go(0.0, -5.2, 0), s + "06_at_oak")
	_step(30, _go(-1.5, 2.0, 30), s + "07_intro_panel")
	_step(30, _go(1.5, 2.0, -30), s + "08_research_panel")
	_step(30, _go(0.0, -9.6, 0), s + "09_oak_below")
	_step(10, func() -> void: _room.call("toggle_palette"), "")
	_step(30, _go(0, 14.0, 0), s + "10_inside_door_black")
	_step(30, _go(0.0, -5.2, 0), s + "11_at_oak_black")
	_step(10, func() -> void: _room.call("toggle_palette"), "")
	# A gust down the hall, a frame every half second.
	_step(20, _go(0, 13.0, 0), "")
	_step(1, _gust, "")
	for k in 6:
		_step(30, _nop(), s + "12_gust_%d" % k)
	# Last, as it is the riskiest: the volume view (the Combined renderer) at the oak.
	_step(20, _go(0.0, -4.0, 0), "")
	_step(30, func() -> void: _room.call("set_volume_view", true), s + "13_volume_view")
	_step(30, func() -> void: _room.call("set_volume_view", false), s + "14_slice_view_again")


func _station(i: int) -> Node:
	return _room.get_node_or_null("Station%02d" % (i + 1))


func _plan_stories() -> void:
	var spots := [[-2.0, 10.6, 50], [2.4, 3.6, -50], [-2.0, -3.6, 50], [0.0, -5.2, 0]]
	for i in 4:
		var st: int = i
		_step(10, _go(spots[i][0], spots[i][1], spots[i][2]), "")
		_step(1, func() -> void: _station(st).call("replay"), "")
		# Every part: wait to its middle, shoot.
		var seqs: Array = _station(i).call("sequences") if _station(i) != null else []
		# Each part shot a little past its middle, by the story's own clock (not frames: a slow
		# frame would put every later shot early).
		for k in seqs.size():
			var part: int = k
			var at: float = float(seqs[k]["length"]) * 0.55
			_until(func() -> bool:
				var s: Node = _station(st)
				return int(s.get("seq_index")) > part or (int(s.get("seq_index")) == part and float(s.get("seq_t")) >= at),
				"stories/%02d_%d_%s" % [i + 1, k + 1, String(seqs[k]["key"])])
		_step(1, func() -> void: _station(st).call("_finish"), "")


func _plan_cards() -> void:
	var spots := [[-9.8, 13.0, 20], [9.8, 6.0, -20], [-9.8, -1.0, 20], [6.8, -6.8, 12]]
	for i in 4:
		_step(10, _go(spots[i][0], spots[i][1], spots[i][2]), "")
		_step(20, func() -> void: _room.call("toggle_card"), "")
		_step(30, _nop(), "cards/%02d_card" % (i + 1))
		_step(5, func() -> void: _room.call("toggle_card"), "")


func _plan_tour() -> void:
	_step(10, _go(5.2, 12.6, 0), "")
	_step(20, func() -> void: _room.call("watch"), "")
	for k in 40:
		_step(60, _nop(), "tour/%02d" % k)


func _plan_volume() -> void:
	var spots := [["02", 2.4, 3.6, -50.0], ["oak", 0.0, -5.2, 0.0], ["grove", 3.0, -49.5, -90.0]]
	for s in spots:
		_step(10, _go(float(s[1]), float(s[2]), float(s[3])), "")
		_step(60, func() -> void: _room.call("set_volume_view", false), "volume/%s_slice" % s[0])
		_step(30, func() -> void: _room.call("set_volume_view", true), "volume/%s_volume" % s[0])
	_step(10, func() -> void: _room.call("set_volume_view", false), "")


func _plan_film() -> void:
	_step(10, _go(5.2, 12.6, 0), "")
	_step(30, func() -> void: _room.call("watch"), "")
	_until(func() -> bool: return (_room.get("_cine") as Dictionary).is_empty(), "")
	_step(30, _go(0, 13.0, 0), "")
	_step(1, _gust, "")
	_step(150, _nop(), "")


func _plan_grove() -> void:
	_step(10, _go(0.0, -18.0, 0), "")
	# Wait for it to load on approach.
	_step(120, _go(0.0, -24.5, 0), "grove/01_from_door")
	_step(40, _go(0.0, -33.0, 0), "grove/02_aisle")
	_step(40, _go(-3.0, -38.0, 140), "grove/03_crossing_signs")
	# Each plot from the cross aisle at its edge, looking into it (yaw 0 faces -z, 180 faces +z), the
	# camera clear of the signs at the crossing.
	_step(40, _go(-10.0, -38.5, 180), "grove/04_voxel_plot")
	_step(40, _go(10.0, -38.5, 180), "grove/05_dc_plot")
	# The back plots from the 4 m aisle between them, so the camera stands in the aisle too.
	_step(40, _go(-3.0, -49.5, 90), "grove/06_loft_plot")
	_step(40, _go(3.0, -49.5, -90), "grove/07_oak_plot")
	# A walk through W at the oaks: the outlying trees grow in and the near ones thin out.
	for k in 4:
		_step(30, _go(3.0, -49.5, -90, 0.3 * float(k + 1)), "grove/07_oak_plot_w%d" % (k + 1))
	_step(40, _go(-4.0, -42.5, 130, 0.0), "grove/08_ana_from_w0")
	_step(40, _go(-4.0, -42.5, 130, 2.2), "grove/09_ana_at_w2.2")


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("ROOM TIMEOUT")
		quit(2)
		return true
	if _wait > 0:
		_wait -= 1
		return false
	if _queue.is_empty():
		print("ROOM done")
		quit()
		return true
	# A step does its thing first, then waits its frames (for the view to settle), then shoots.
	var s: Array = _queue[0]
	if s.size() < 5:
		if s.size() < 4:
			s.append(Callable())
		s.append(true)
		(s[1] as Callable).call()
		return false
	if int(s[0]) > 0:
		s[0] = int(s[0]) - 1
		var cond: Callable = s[3]
		if not cond.is_valid() or not bool(cond.call()):
			return false
	_queue.pop_front()
	if not String(s[2]).is_empty():
		_shoot(String(s[2]))
	return false


func _shoot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("ROOM shot ", name)
