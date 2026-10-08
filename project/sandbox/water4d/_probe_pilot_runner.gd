extends SceneTree

## Does the plesiosaur stay where it is supposed to, and does it use all four axes?
##
##   godot --path project --rendering-method forward_plus --resolution 640x400 \
##       --script res://sandbox/water4d/_probe_pilot_runner.gd
##
## Wandering behaviour is the kind of thing that looks right for the thirty seconds you watch
## it and then walks through the floor at minute four. Ten minutes of it are simulated here in
## a couple of seconds, which is the only honest way to check a bound that is only approached
## occasionally - and the depth floor IS only approached occasionally, because the waypoints
## are random.
##
## USING ALL FOUR AXES IS ALSO CHECKED, not assumed. A pilot with a bug in one axis - a goal
## that never sets W, a climb limit that clamps to zero - still produces a creature that
## swims about convincingly, and the missing axis is invisible unless you go looking for it
## in the slice it never leaves.

const SCENE := "res://sandbox/water4d/plesiosaur.tscn"
const SIMULATED_SECONDS := 600.0
const STEP := 1.0 / 60.0

var _frames: int = 0
var _pilot: Node = null
var _body: Node4D = null
var _swimmer: Node = null
var _player: Node4D = null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var model: Node4D = (load(SCENE) as PackedScene).instantiate() as Node4D
		root.add_child(model)
		current_scene = model
		_swimmer = model.get_node_or_null(^"Swimmer")
		# A stand-in for the player, parked on the walkway where the real one starts, so the
		# attention logic has something to glance at.
		_player = Node4D.new()
		_player.name = "Player"
		root.add_child(_player)
		_player.position = Vector4(-17.0, 1.75, 0.0, 0.0)

		_pilot = Node4D.new()
		_pilot.name = "Pilot"
		_pilot.set_script(load("res://sandbox/water4d/plesiosaur_pilot.gd"))
		_pilot.set(&"body_path", NodePath(".."))
		_pilot.set(&"swimmer_path", NodePath("../Swimmer"))
		_pilot.set(&"player_path", NodePath("/root/Player"))
		_pilot.set(&"bounds", Vector3(46.0, 46.0, 8.0))
		_pilot.set(&"depth_range", Vector2(10.0, 32.0))
		model.add_child(_pilot)
		_body = model
		return false
	if _frames < 4:
		return false
	return _report()


func _report() -> bool:
	var ok := true
	var bounds: Vector3 = _pilot.get(&"bounds")
	var depths: Vector2 = _pilot.get(&"depth_range")
	var speed: float = _pilot.get(&"speed")
	var turn_rate: float = deg_to_rad(_pilot.get(&"turn_rate_degrees"))

	var low := Vector4(INF, INF, INF, INF)
	var high := Vector4(-INF, -INF, -INF, -INF)
	var fastest: float = 0.0
	var sharpest: float = 0.0
	var glances: int = 0
	var in_slice: int = 0
	var was_attending: bool = false
	var before: Vector4 = _body.position
	var heading_before: Vector4 = _pilot.get(&"_heading")

	var steps: int = int(SIMULATED_SECONDS / STEP)
	for _i in range(steps):
		_pilot.call(&"_physics_process", STEP)
		var at: Vector4 = _body.position
		low = Vector4(minf(low.x, at.x), minf(low.y, at.y), minf(low.z, at.z), minf(low.w, at.w))
		high = Vector4(maxf(high.x, at.x), maxf(high.y, at.y), maxf(high.z, at.z), maxf(high.w, at.w))
		fastest = maxf(fastest, before.distance_to(at) / STEP)
		var heading: Vector4 = _pilot.get(&"_heading")
		sharpest = maxf(sharpest, acos(clampf(heading_before.dot(heading), -1.0, 1.0)) / STEP)
		before = at
		heading_before = heading
		# ROUGHLY IN THE SLICE. The animal is about 2 m thick through W, so once |w| passes
		# about 1 m the player at w = 0 is seeing a thinner and thinner cut of it and past
		# 1.2 m or so nothing at all. This is the number that decides whether "swims through
		# all four axes" and "easy to spot" can both be true, and it is not visible in any
		# bound check.
		if absf(at.w) <= 1.2:
			in_slice += 1
		var attending: bool = _swimmer.get(&"_look_active")
		if attending and not was_attending:
			glances += 1
		was_attending = attending

	print("")
	print("  over %.0f simulated seconds:" % SIMULATED_SECONDS)
	print("    x    %7.1f .. %7.1f   (allowed +/- %.0f)" % [low.x, high.x, bounds.x])
	print("    z    %7.1f .. %7.1f   (allowed +/- %.0f)" % [low.z, high.z, bounds.y])
	print("    w    %7.1f .. %7.1f   (allowed +/- %.0f)" % [low.w, high.w, bounds.z])
	print("    y    %7.1f .. %7.1f   (allowed %.0f .. %.0f deep)"
			% [low.y, high.y, minf(depths.x, depths.y), maxf(depths.x, depths.y)])
	print("    fastest %.2f m/s (set to %.2f), sharpest turn %.1f deg/s (set to %.1f)"
			% [fastest, speed, rad_to_deg(sharpest), rad_to_deg(turn_rate)])
	print("    glances at the player: %d" % glances)
	print("    in the player's own slice (|w| <= 1.2): %.0f%% of the time"
			% (100.0 * float(in_slice) / float(steps)))
	print("")

	# A metre of tolerance on the walls: the clamp is applied after the step, so the recorded
	# position can sit exactly on a bound but never past it.
	if low.x < -bounds.x - 0.01 or high.x > bounds.x + 0.01:
		print("  FAIL - left the pool in X")
		ok = false
	if low.z < -bounds.y - 0.01 or high.z > bounds.y + 0.01:
		print("  FAIL - left the pool in Z")
		ok = false
	if low.w < -bounds.z - 0.01 or high.w > bounds.z + 0.01:
		print("  FAIL - left the pool in W")
		ok = false
	if high.y > -minf(depths.x, depths.y) + 0.01:
		print("  FAIL - surfaced: reached %.1f m deep, shallower than the %.0f m limit"
				% [-high.y, minf(depths.x, depths.y)])
		ok = false
	if low.y < -maxf(depths.x, depths.y) - 0.01:
		print("  FAIL - went below the deep limit, which is where the floor is")
		ok = false

	# Half the allowed range in each axis. A pilot that only ever uses a corner of the pool is
	# not wandering, and one that never changes W is not a 4D creature.
	if high.x - low.x < bounds.x:
		print("  FAIL - barely moved in X")
		ok = false
	if high.z - low.z < bounds.y:
		print("  FAIL - barely moved in Z")
		ok = false
	if high.w - low.w < bounds.z:
		print("  FAIL - barely moved in W; it is not using the fourth axis")
		ok = false
	if high.y - low.y < (maxf(depths.x, depths.y) - minf(depths.x, depths.y)) * 0.5:
		print("  FAIL - barely changed depth")
		ok = false

	if fastest > speed * 1.05:
		print("  FAIL - moved at %.2f m/s, faster than the %.2f it was given" % [fastest, speed])
		ok = false
	if sharpest > turn_rate * 1.05:
		print("  FAIL - turned at %.1f deg/s, sharper than the %.1f it was given"
				% [rad_to_deg(sharpest), rad_to_deg(turn_rate)])
		ok = false
	if glances < 5:
		print("  FAIL - only %d glances at the player in ten minutes" % glances)
		ok = false

	if ok:
		print("  PASS - stays in the pool, uses all four axes, keeps to its speed and turn rate.")
	quit(0 if ok else 1)
	return true
