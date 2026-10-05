extends Node

## THE WOLF (Ramon, 3 Oct: "whats a pen without a wolf ... make it appear only sometimes, and make
## it run into the pen, and jump out of it again. he will catch a chicken in his mouth jump out of
## pen an eventually run out of slice. the chicken wont be eaten, it just means you have to catch
## him again somewhere ... he won't arrive often"; then "i want it to be a cutscene", "with
## letterbox, then switch to main characters face with his responce line", "a far shot if you're
## far ... then a closer shot of what happens, medium close, and then the face with line", and the
## line: "did i just see a 4d wolf grab a 4d chicken?").
##
## RARE. A chance every [member every] seconds, taken [member chance] of the time, the first not
## before [member first_after]. Only when the farm is up, you are free (your input on: not
## talking, in a cutscene, at the tower, flying, carrying), and at least one chicken is home and
## not all of them, so it never undoes the ending. The debug card's 8 sends it now.
##
## WHERE YOU ARE STAYS PUT. Your input is held and the HUD hidden for the length of it, behind a
## letterbox; the camera is its own. First from where you stand, looking where the wolf is (far if
## you are far, near if near), as it comes over the fence; then close by the pen, from the side,
## for the grab and the leap back out; then wide as it runs off and out of the slice through W;
## then your face, turned the way it went, and the line. Then everything is handed back.
##
## THE CHICKEN IS NOT EATEN. Carried off in the wolf's mouth, it is set down loose where the wolf
## left the slice, out in the field a little ana, and counts as not home again: the locator finds
## it like any other.

signal raid_finished

enum Phase { IDLE, APPROACH, LEAP_IN, TO_CHICKEN, GRAB, TO_FENCE, LEAP_OUT, RUN_OFF, FACE }

@export var wolf_path: NodePath = NodePath("../../World/Wolf")
@export var manager_path: NodePath = NodePath("../../Chickens")
@export var fence_path: NodePath = NodePath("../../Pen/Fence")
@export var player_path: NodePath = NodePath("../../Player")
@export var farm_camera_path: NodePath = NodePath("../../Player/CameraRig/Pitch/Camera4D")
@export var cinematics_path: NodePath = NodePath("../../Cinematics")
@export var grass_path: NodePath = NodePath("../../World/Grass")

@export_group("How often")
@export_range(10.0, 1800.0, 5.0, "suffix:s") var first_after: float = 240.0
@export_range(10.0, 1800.0, 5.0, "suffix:s") var every: float = 300.0
@export_range(0.0, 1.0, 0.01) var chance: float = 0.35

@export_group("The wolf")
@export_range(1.0, 15.0, 0.1, "suffix:m/s") var run_speed: float = 6.5
## How far out it starts its run at the pen, and runs on past it before it is gone.
@export_range(5.0, 40.0, 0.5, "suffix:m") var run_in: float = 16.0
@export_range(4.0, 30.0, 0.5, "suffix:m") var run_off: float = 12.0
@export_range(0.3, 2.0, 0.05, "suffix:s") var leap_seconds: float = 0.7
## How high its feet clear the fence at the top of a leap.
@export_range(0.0, 1.0, 0.05, "suffix:m") var leap_clearance: float = 0.3
@export_range(0.2, 2.0, 0.05, "suffix:s") var grab_seconds: float = 0.8
## How far ana it runs, through the last stretch, so it leaves your slice; and so where the
## chicken is set down.
@export_range(0.3, 4.0, 0.1, "suffix:m") var exit_w: float = 1.4

@export_group("The cutscene")
## No dashes in it (player-facing): it is the player's own line.
@export_multiline var line: String = "Did I just see a 4D wolf grab a 4D chicken?"
@export_range(1.0, 6.0, 0.1, "suffix:s") var face_seconds: float = 3.4
@export_range(1.5, 3.0, 0.01) var letterbox_aspect: float = 2.39

var phase: Phase = Phase.IDLE
var _wolf: Node4D
var _walker: Node
var _manager: Node
var _fence: Node4D
var _player: Node4D
var _rng := RandomNumberGenerator.new()
var _next_chance: float = 0.0
var _t: float = 0.0
var _phase_t: float = 0.0
var _heading: float = 0.0
var _chicken: Node = null
var _route: Dictionary = {}
var _cam: Camera4D
var _saved: Dictionary = {}
var _layer: CanvasLayer
var _bars: Array[ColorRect] = []
var _subtitle: Label
var _bars_in: float = 0.0
var _shot_from := Vector4.ZERO
var _look := Vector4.ZERO


func _ready() -> void:
	_rng.randomize()
	_next_chance = first_after
	_wolf = get_node_or_null(wolf_path) as Node4D
	_manager = get_node_or_null(manager_path)
	_fence = get_node_or_null(fence_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	if _wolf != null:
		_wolf.visible = false
		_walker = _wolf.get_node_or_null("Walker")
		# Bound once at load (it cuts the hide on its first physics frame), then held still
		# until a raid: walking unseen for minutes would be work for nothing.
		_hold_walker.call_deferred()


func _hold_walker() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _walker != null and phase == Phase.IDLE:
		_walker.set_process(false)
		_walker.set_physics_process(false)


## Sends the wolf now, if it can come at all. True if it set off.
func start_raid() -> bool:
	if phase != Phase.IDLE or not _can_come():
		return false
	_chicken = _pick_chicken()
	if _chicken == null:
		return false
	_plan_route()
	_borrow()
	_wolf.visible = true
	_wolf.global_position = _route["start"]
	_heading = _route["heading_in"]
	_set_pose(0.0)
	_running(true)
	var grass: Node = get_node_or_null(grass_path)
	if grass != null and grass.has_method("add_walker"):
		grass.call("add_walker", _wolf)
	_enter(Phase.APPROACH)
	return true


func is_running() -> bool:
	return phase != Phase.IDLE


# --- When it comes -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.IDLE:
		_t += delta
		if _t >= _next_chance:
			_next_chance = _t + every
			if _rng.randf() < chance:
				start_raid()
		return
	_phase_t += delta
	_bars_in = minf(_bars_in + delta / 0.45, 1.0)
	_lay_out()
	_hide_hud()
	match phase:
		Phase.APPROACH:
			if _run_to(_route["fence_out_in"], delta):
				_enter(Phase.LEAP_IN)
		Phase.LEAP_IN:
			if _leap(_route["fence_out_in"], _route["fence_in_in"]):
				_enter(Phase.TO_CHICKEN)
		Phase.TO_CHICKEN:
			if _run_to(_route["grab_at"], delta):
				_enter(Phase.GRAB)
		Phase.GRAB:
			_grab()
			if _phase_t >= grab_seconds:
				_enter(Phase.TO_FENCE)
		Phase.TO_FENCE:
			if _run_to(_route["fence_in_out"], delta):
				_enter(Phase.LEAP_OUT)
		Phase.LEAP_OUT:
			if _leap(_route["fence_in_out"], _route["fence_out_out"]):
				_enter(Phase.RUN_OFF)
		Phase.RUN_OFF:
			# Through W as it goes: the slice cuts it thinner and thinner, and then it is gone.
			var done: bool = _run_to(_route["end"], delta)
			var gone: float = clampf(_phase_t / (run_off / run_speed), 0.0, 1.0)
			_wolf.global_position.w = smoothstep(0.25, 1.0, gone) * exit_w
			if done or _phase_t > run_off / run_speed + 0.6:
				_set_chicken_down()
				_enter(Phase.FACE)
		Phase.FACE:
			if _phase_t >= face_seconds:
				_finish()
				return
	_carry_chicken()
	_frame()


func _can_come() -> bool:
	if _wolf == null or _manager == null or _fence == null or _player == null:
		return false
	var world := _wolf.get_parent() as Node4D
	if world == null or not world.is_visible_in_tree():
		return false
	if _player.get("input_enabled") == false or not _player.is_visible_in_tree():
		return false
	var catcher: Node = _player.get_node_or_null("Catcher")
	if catcher != null and catcher.get("carried") != null:
		return false
	var films: Node = get_node_or_null(cinematics_path)
	if films != null and films.has_method("is_playing") and bool(films.call("is_playing")):
		return false
	var home: int = int(_manager.call("returned_count"))
	var all: int = (_manager.get("agents") as Array).size()
	return home > 0 and home < all


## A chicken at home and on the pen's floor - not in the henhouse or on its roof.
func _pick_chicken() -> Node:
	var best: Node = null
	var best_d: float = INF
	var middle: Vector4 = _fence.global_position
	for agent in _manager.get("agents"):
		if not bool(agent.get("returned")) or bool(agent.call("using_coop")):
			continue
		var bird := agent.get_parent() as Node4D
		var d: float = Vector2(bird.global_position.x - middle.x, bird.global_position.z - middle.z).length()
		if d < best_d:
			best_d = d
			best = agent
	return best


# --- The route ----------------------------------------------------------------------------------

## In over the side of the pen away from you (so it comes towards you over it), out over a side
## across your view (so it runs off across the frame), lined up with the chicken.
func _plan_route() -> void:
	var middle: Vector4 = _fence.global_position
	middle.y = 0.0
	middle.w = 0.0
	var half := Vector2(float(_fence.get("extend_x_positive")), float(_fence.get("extend_z_positive")))
	var bird: Vector4 = (_chicken.get_parent() as Node4D).global_position
	var to_you := Vector2(_player.global_position.x - middle.x, _player.global_position.z - middle.z)
	var in_x: bool = absf(to_you.x) > absf(to_you.y)
	# The side it comes in over: the far one. The side it leaves by: across, and away from you,
	# so it leaps away from the camera on your side and you turn to look where it went.
	var n_in := Vector2(-signf(to_you.x) if in_x else 0.0, 0.0 if in_x else -signf(to_you.y))
	if n_in == Vector2.ZERO:
		n_in = Vector2(0.0, -1.0)
	# Something standing where it would start (6 Oct: in the pen's new layout the cave hill is
	# 16 m south of the pen, so from the north it would have come out of the hill): in over a
	# side across your view instead, the first one that is clear.
	if not _run_clear(middle, half, n_in, run_in):
		for side in [Vector2(n_in.y, n_in.x), -Vector2(n_in.y, n_in.x)]:
			if _run_clear(middle, half, side, run_in):
				n_in = side
				break
	var across := Vector2(n_in.y, n_in.x)
	if across.dot(to_you) > 0.0:
		across = -across
	if not _run_clear(middle, half, across, run_off) and _run_clear(middle, half, -across, run_off):
		across = -across
	var n_out: Vector2 = across.normalized()
	var at_bird := Vector2(bird.x - middle.x, bird.z - middle.z)
	# The cameras that watch each leap, worked out first so each crossing can be put where they
	# can see it: your own view for the leap in, the one beside the pen for the leap out.
	var farm := get_node_or_null(farm_camera_path) as Node4D
	var your_view: Vector4 = farm.global_position if farm != null else _player.global_position
	var shot_b: Vector4 = _beside_pen(bird, n_in)
	var side_in: Vector2 = _crossing(n_in, half, at_bird, middle, your_view)
	var side_out: Vector2 = _crossing(n_out, half, at_bird, middle, shot_b)
	var fence_out_in: Vector4 = _flat(middle, n_in, half, side_in, 1.7)
	var fence_in_in: Vector4 = _flat(middle, n_in, half, side_in, -1.3)
	var fence_in_out: Vector4 = _flat(middle, n_out, half, side_out, -1.3)
	var fence_out_out: Vector4 = _flat(middle, n_out, half, side_out, 1.7)
	# It stops with its mouth at the bird: a body length short of it, facing it.
	var toward: Vector4 = bird - fence_in_in
	toward.y = 0.0
	toward.w = 0.0
	var grab_at: Vector4 = bird - toward.normalized() * 0.78
	grab_at.y = 0.0
	grab_at.w = 0.0
	_route = {
		"start": fence_out_in + Vector4(n_in.x, 0.0, n_in.y, 0.0) * run_in,
		"fence_out_in": fence_out_in, "fence_in_in": fence_in_in, "grab_at": grab_at,
		"fence_in_out": fence_in_out, "fence_out_out": fence_out_out,
		"end": fence_out_out + Vector4(n_out.x, 0.0, n_out.y, 0.0) * run_off,
		"heading_in": atan2(-n_in.x, -n_in.y), "n_in": n_in, "n_out": n_out, "bird": bird, "shot_b": shot_b,
	}


## Whether the ground off side [param n] of the pen is open for [param run] metres: rays straight
## down at its start, middle and end find nothing standing taller than the grass.
func _run_clear(middle: Vector4, half: Vector2, n: Vector2, run: float) -> bool:
	var edge: float = (half.x if absf(n.x) > 0.5 else half.y) + 1.7
	for k in [0.15, 0.5, 1.0]:
		var at: Vector2 = Vector2(middle.x, middle.z) + n * (edge + run * float(k))
		var params := RaycastParameters4D.new()
		params.global_ray_origin = Vector4(at.x, 30.0, at.y, middle.w)
		params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
		params.max_distance = 31.0
		var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
		# Buildings and hills, not a chicken or you passing under the ray.
		if not hit.is_empty() and hit.get("body") is StaticBody4D and hit.has("global_point") and (hit["global_point"] as Vector4).y > 0.6:
			return false
	return true


## Where along a side it crosses: as near level with the chicken as it can be while the camera
## at [param seen_from] can see it over the fence - not behind the henhouse, which hid both leaps
## at first. A metre clear of the corners.
func _crossing(n: Vector2, half: Vector2, at_bird: Vector2, middle: Vector4, seen_from: Vector4) -> Vector2:
	var along := Vector2(absf(n.y), absf(n.x))
	var reach: float = (half.x if along.x > 0.5 else half.y) - 1.0
	var want: float = clampf(at_bird.dot(along), -reach, reach)
	var coop := get_node_or_null("../../Pen/Coop") as Node4D
	var best: float = want
	var least: float = INF
	for i in 9:
		var t: float = lerpf(-reach, reach, float(i) / 8.0)
		var cost: float = absf(t - want)
		if coop != null:
			var p: Vector4 = _flat(middle, n, half, along * t, 0.0)
			var c := Vector2(coop.global_position.x, coop.global_position.z)
			if _segment_gap(Vector2(seen_from.x, seen_from.z), Vector2(p.x, p.z), c) < 1.9:
				cost += 100.0
		if cost < least:
			least = cost
			best = t
	return along * best


## How near the line from [param a] to [param b] passes to [param c].
func _segment_gap(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t).distance_to(c)


## The camera beside the pen for the grab and the leap out: level with the chicken, on your side,
## at a crouch.
func _beside_pen(bird: Vector4, n_in: Vector2) -> Vector4:
	var side := Vector2(-n_in.y, n_in.x)
	var you := Vector2(_player.global_position.x - bird.x, _player.global_position.z - bird.z)
	if side.dot(you) < 0.0:
		side = -side
	return Vector4(bird.x + side.x * 3.8 - n_in.x * 0.8, 1.15, bird.z + side.y * 3.8 - n_in.y * 0.8, 0.0)


## A point [param out] metres past the side with normal [param n] (negative: inside it).
func _flat(middle: Vector4, n: Vector2, half: Vector2, along: Vector2, out: float) -> Vector4:
	var edge: float = half.x if absf(n.x) > 0.5 else half.y
	var p: Vector2 = n * (edge + out) + along
	return Vector4(middle.x + p.x, 0.0, middle.z + p.y, 0.0)


# --- Moving it ----------------------------------------------------------------------------------

func _enter(next: Phase) -> void:
	phase = next
	_phase_t = 0.0
	match next:
		Phase.LEAP_IN, Phase.LEAP_OUT, Phase.GRAB:
			_running(false)
		Phase.APPROACH, Phase.TO_CHICKEN, Phase.TO_FENCE, Phase.RUN_OFF:
			_running(true)
		Phase.FACE:
			_running(false)
			_wolf.visible = false
	_shot_from = Vector4.ZERO


## The legs on at a run, or held (in the air, and while it grabs).
func _running(on: bool) -> void:
	if _walker == null:
		return
	_walker.set("belt_speed", run_speed)
	_walker.set("stride_length", 0.6)
	_walker.set("step_height", 0.16)
	_walker.set("body_bob", 0.05)
	_walker.set_process(on)
	_walker.set_physics_process(on)


## Runs straight at [param to], turning towards it; true once there.
func _run_to(to: Vector4, delta: float) -> bool:
	var here: Vector4 = _wolf.global_position
	var gap := Vector2(to.x - here.x, to.z - here.z)
	var step: float = run_speed * delta
	if gap.length() <= step:
		_wolf.global_position = Vector4(to.x, 0.0, to.z, here.w)
		return true
	_heading = rotate_toward(_heading, atan2(gap.x, gap.y), delta * 9.0)
	var forward := Vector2(sin(_heading), cos(_heading))
	_wolf.global_position = Vector4(here.x + forward.x * step, 0.0, here.z + forward.y * step, here.w)
	_set_pose(0.0)
	return false


## Over the fence, in an arc: nose up as it goes, down as it lands. True once down.
func _leap(from: Vector4, to: Vector4) -> bool:
	var k: float = clampf(_phase_t / leap_seconds, 0.0, 1.0)
	var height: float = float(_fence.get("height")) + leap_clearance
	var flat: Vector4 = from.lerp(to, k)
	_heading = atan2(to.x - from.x, to.z - from.z)
	_wolf.global_position = Vector4(flat.x, sin(k * PI) * height, flat.z, _wolf.global_position.w)
	_set_pose(lerpf(0.4, -0.35, k))
	return k >= 1.0


## The grab: a lunge, the head down to the bird, and back up with it.
func _grab() -> void:
	var k: float = clampf(_phase_t / grab_seconds, 0.0, 1.0)
	_set_pose(-0.32 * sin(k * PI))
	if k > 0.45 and _chicken != null and _chicken.get("state") != 4:
		# Out of the pen's books and into the wolf's mouth.
		_chicken.set("returned", false)
		_chicken.call("on_caught")
		_manager.emit_signal("progress_changed", int(_manager.call("returned_count")), (_manager.get("agents") as Array).size())


## Facing along its heading, pitched by [param pitch] (radians, nose up positive).
func _set_pose(pitch: float) -> void:
	_wolf.global_basis = Basis4D.from_zx(_heading) * Basis4D.from_yz(-pitch)


## While carried, the bird hangs across the wolf's jaws.
func _carry_chicken() -> void:
	if _chicken == null or int(_chicken.get("state")) != 4:
		return
	var bird := _chicken.get_parent() as Node4D
	# Across the jaws and on its side, its middle in the wolf's mouth: the bird's origin is at
	# its feet, so it is set back from the jaw by half its height along its own (turned) up.
	var mouth: Vector4 = _wolf.global_position + _wolf.global_basis * Vector4(0.0, 0.72, 0.74, 0.0)
	var s: float = float(_manager.get("chicken_scale"))
	var turn: Projection = _wolf.global_basis * Basis4D.from_zx(PI * 0.5) * Basis4D.from_xy(PI * 0.5)
	bird.global_basis = turn * Projection(
		Vector4(s, 0, 0, 0), Vector4(0, s, 0, 0), Vector4(0, 0, s, 0), Vector4(0, 0, 0, s))
	bird.global_position = mouth - turn * Vector4(0.0, 0.22, 0.0, 0.0)


## Set down loose where the wolf left the slice, a little ana: home is wherever that is.
func _set_chicken_down() -> void:
	if _chicken == null:
		return
	var bird := _chicken.get_parent() as Node4D
	var at: Vector4 = _wolf.global_position
	at.y = float(_manager.get("ground_y"))
	at.w = exit_w
	var s: float = float(_manager.get("chicken_scale"))
	bird.global_basis = Basis4D.from_zx(_rng.randf_range(0.0, TAU)) * Projection(
		Vector4(s, 0, 0, 0), Vector4(0, s, 0, 0), Vector4(0, 0, s, 0), Vector4(0, 0, 0, s))
	bird.global_position = at
	_chicken.set("home_position", bird.position)
	_chicken.call("on_released")
	_chicken.call("on_landed", false)
	_manager.emit_signal("progress_changed", int(_manager.call("returned_count")), (_manager.get("agents") as Array).size())


# --- The cutscene -------------------------------------------------------------------------------

func _borrow() -> void:
	var hud: Dictionary = {}
	for child in get_node("../../UI").get_children():
		if child is CanvasItem:
			hud[child] = (child as CanvasItem).visible
	var farm := get_node_or_null(farm_camera_path) as Camera4D
	_saved = {"hud": hud, "input": _player.get("input_enabled"), "farm": farm,
		"view_at": farm.global_position if farm != null else _player.global_position + Vector4(0.0, 1.6, 0.0, 0.0)}
	_player.set("input_enabled", false)
	_cam = Camera4D.new()
	_cam.name = "WolfCamera"
	_cam.set("rendering_engine_name", "Cross-section")
	get_node("../..").add_child(_cam)
	if farm != null:
		_cam.global_position = farm.global_position
		_cam.global_basis = farm.global_basis
		_cam.set("field_of_view_4d", farm.get("field_of_view_4d"))
	_cam.make_current()
	_build_bars()


func _finish() -> void:
	var grass: Node = get_node_or_null(grass_path)
	if grass != null and grass.has_method("remove_walker"):
		grass.call("remove_walker", _wolf)
	_wolf.visible = false
	_wolf.global_position = Vector4(_wolf.global_position.x, 0.0, _wolf.global_position.z, 0.0)
	_running(false)
	var hud: Dictionary = _saved.get("hud", {})
	for item in hud:
		if is_instance_valid(item):
			(item as CanvasItem).visible = hud[item]
	_player.set("input_enabled", _saved.get("input", true))
	if _player.has_method("stop_facing"):
		_player.call("stop_facing")
	var farm: Camera4D = _saved.get("farm")
	if farm != null:
		farm.make_current()
	if is_instance_valid(_cam):
		_cam.queue_free()
	if is_instance_valid(_layer):
		_layer.queue_free()
	_bars.clear()
	_chicken = null
	phase = Phase.IDLE
	_t = 0.0
	_next_chance = every
	raid_finished.emit()


func _hide_hud() -> void:
	for child in get_node("../../UI").get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false


func _build_bars() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	for k in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bar)
		_bars.append(bar)
	_subtitle = Label.new()
	_subtitle.text = ""
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 26)
	_subtitle.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_layer.add_child(_subtitle)
	_bars_in = 0.0
	_lay_out()


## The bars slide in from the edges; the line sits in the lower one.
func _lay_out() -> void:
	if _bars.size() < 2:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var picture_h: float = minf(screen.y, screen.x / letterbox_aspect)
	var bar: float = floorf((screen.y - picture_h) * 0.5) * smoothstep(0.0, 1.0, _bars_in)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(screen.x, bar)
	_bars[1].position = Vector2(0.0, screen.y - bar)
	_bars[1].size = Vector2(screen.x, bar)
	_subtitle.position = Vector2(0.0, screen.y - bar)
	_subtitle.size = Vector2(screen.x, bar)
	var fade: float = clampf(minf((_phase_t - 0.3) / 0.4, (face_seconds - _phase_t) / 0.4), 0.0, 1.0)
	_subtitle.text = line
	_subtitle.modulate.a = fade if phase == Phase.FACE else 0.0


## The lens. For the shots that watch the wolf from a way off - your view as it comes, and it
## running off - long enough to keep it about a fifth of the frame high; for the leap out, racking
## in a little as it heads away from the camera beside the pen. Never wider than your own. It cuts
## with the camera and eases within a shot.
func _lens(from: Vector4, wolf_at: Vector4) -> void:
	var own: float = float((_saved["farm"] as Camera4D).get("field_of_view_4d")) if _saved.get("farm") != null else 1.35
	var d: float = maxf(from.distance_to(wolf_at), 0.1)
	var want: float = own
	match phase:
		Phase.APPROACH, Phase.LEAP_IN, Phase.RUN_OFF:
			want = clampf(2.0 * atan(2.6 / d), 0.18, own)
		Phase.TO_FENCE, Phase.LEAP_OUT:
			want = clampf(2.0 * atan(2.0 / d), 0.3, own)
	var cut: bool = _phase_t < 0.05 and phase in [Phase.APPROACH, Phase.TO_CHICKEN, Phase.RUN_OFF, Phase.FACE]
	var now: float = float(_cam.get("field_of_view_4d"))
	_cam.set("field_of_view_4d", want if cut else lerpf(now, want, minf(get_process_delta_time() * 3.0, 1.0)))


## Where the camera is, shot by shot.
func _frame() -> void:
	var up := Vector4(0, 1, 0, 0)
	var wolf_at: Vector4 = _wolf.global_position + Vector4(0.0, 0.5, 0.0, 0.0)
	wolf_at.w = 0.0
	var look: Vector4 = wolf_at
	var from: Vector4
	match phase:
		Phase.APPROACH, Phase.LEAP_IN:
			# From where you stand: your own view, turning to find the wolf. Far off (more than
			# 45 m), from a little way out on your side of the pen instead.
			from = _saved["view_at"]
			var pen: Vector4 = _fence.global_position
			var off := Vector2(from.x - pen.x, from.z - pen.z)
			if off.length() > 45.0:
				off = off.normalized() * 24.0
				from = Vector4(pen.x + off.x, 3.0, pen.z + off.y, 0.0)
		Phase.TO_CHICKEN, Phase.GRAB, Phase.TO_FENCE, Phase.LEAP_OUT:
			# Close by the pen, from the side you are on, at a crouch (_beside_pen).
			from = _route["shot_b"]
		Phase.RUN_OFF:
			# From inside the pen, behind it, as it runs off and out of the slice; the lens
			# closing in as it goes, so you see it thin out through W rather than shrink.
			if _shot_from == Vector4.ZERO:
				var out: Vector4 = _route["fence_in_out"]
				var n_out: Vector2 = _route["n_out"]
				_shot_from = Vector4(out.x - n_out.x * 2.0, 1.3, out.z - n_out.y * 2.0, 0.0)
			from = _shot_from
		Phase.FACE:
			# Your face, turned the way it went.
			var head := get_node_or_null("../../Player/Avatar/Tunic/Head") as Node4D
			var end: Vector4 = _route["end"]
			if _player.has_method("face_towards"):
				_player.call("face_towards", end)
			var at: Vector4 = head.global_position if head != null else _player.global_position + up * 1.5
			var way := Vector2(end.x - at.x, end.z - at.z)
			way = way.normalized() if way.length() > 0.1 else Vector2(0.0, 1.0)
			from = at + Vector4(way.x, 0.0, way.y, 0.0) * 0.95 + up * 0.04
			from.w = at.w
			look = at
	_lens(from, wolf_at)
	if _look == Vector4.ZERO or phase == Phase.FACE:
		_look = look
	else:
		_look = _look.lerp(look, minf(get_process_delta_time() * 6.0, 1.0))
	_cam.global_basis = Projection.IDENTITY
	_cam.global_position = from
	_cam.look_at(_look)
