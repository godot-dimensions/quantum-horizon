extends SceneTree

## Drives the portal test chamber through its two defining behaviours and renders
## the result, because neither can be judged from counts.
##
##   Test 1, the walk-through: link the facing side-wall pads, walk a player into
##   one, and confirm they arrive at the other still moving away from the wall.
##   Getting the half turn wrong spits them back out the way they came, which a
##   pass/fail on "did a teleport happen" would not catch.
##
##   Test 2, the fall: link the floor pad to the ceiling pad above it and drop
##   the player in. The speed at each crossing must RISE. If it does not, momentum
##   is not surviving the transform and the thing is a door, not a portal.
##
## Runs with a real rendering device, not --headless, so the screenshots show
## what a player would see. Editor closed, same as every other tool here.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/Portal/_portal_shot.gd

const CHAMBER_PATH := "res://ramon/Portal/portal_test_2.tscn"
const ApertureScript := preload("res://ramon/Portal/scripts/portal_aperture.gd")
const WARMUP_FRAMES := 25
const WALK_FRAMES := 40
const FALL_FRAMES := 150
## Long enough to walk 2 m into the opening, arrive high on the far wall, and
## fall the 1.1 m onto the ledge.
const LEDGE_FRAMES := 90
## 1.4 s of closing at 60 Hz, with margin.
const CLOSE_FRAMES := 110

var _chamber: Node = null
var _builder: Node = null
var _link: Node = null
var _player: CharacterBody4D = null

var _stage: int = 0
## Stages are measured in PHYSICS frames, not render frames. Bounding them by
## render frames made the test flaky: the same code reported 6 crossings on one
## run and 1 on the next, purely because the number of physics steps inside 150
## rendered frames varies with frame pacing. Anything asserting on simulated
## motion has to count simulated time.
var _stage_start_physics: int = 0
var _frames: int = 0
var _fall_speeds: Array[float] = []
var _seen_crossings: int = 0
var _last_traced_physics: int = -1
var _closing_surface: Node4D = null
var _walking: bool = false
var _pinned_basis := Projection()
var _failed: bool = false


## Pins the walking heading. Belt and braces alongside the controller's own
## swallow-the-warp fix: a test that walks a player at a 2 m target must not be
## at the mercy of a stray motion event, and re-asserting the basis costs
## nothing. The player is being driven here, so nothing legitimate turns them.
func _hold_heading() -> void:
	if _walking and _pinned_basis != Projection():
		_player.global_basis = _pinned_basis


## Both openings finished growing, so it is safe to walk into one.
func _both_open() -> bool:
	if not _link.is_paired():
		return false
	return _link.blue.openness >= 1.0 and _link.yellow.openness >= 1.0


func _initialize() -> void:
	root.set_size(Vector2i(1600, 900))
	var packed: PackedScene = load(CHAMBER_PATH)
	if packed == null:
		printerr("PORTAL SHOT: could not load ", CHAMBER_PATH)
		quit(1)
		return
	_chamber = packed.instantiate()
	root.add_child(_chamber)
	set_current_scene(_chamber)
	# Everything else waits for the first _process frame: _ready has not fired
	# for anything added here, so the builder has no pads yet.


func _process(_delta: float) -> bool:
	match _stage:
		0:
			_resolve_nodes()
			_start_walk_test()
			_stage = 1
			_stage_start_physics = Engine.get_physics_frames()
		1:
			# Wait for both openings to finish growing before walking into one.
			# Pressing forward at placement time raced the 0.35 s animation: the
			# player sometimes arrived at a wall that was still solid, bounced
			# off and slid along it, and the test failed on one run and passed on
			# the next from identical code.
			if not _walking:
				if _both_open():
					_walking = true
					_stage_start_physics = Engine.get_physics_frames()
					Input.action_press(&"move_forward")
			elif _elapsed_physics() < WALK_FRAMES:
				_hold_heading()
				_trace()
			else:
				_finish_walk_test()
				_shoot("portal_walkthrough.png")
				_start_fall_test()
				_stage = 2
				_stage_start_physics = Engine.get_physics_frames()
		2:
			_sample_fall()
			if _elapsed_physics() >= FALL_FRAMES:
				_finish_fall_test()
				_start_ledge_test()
				_stage = 3
				_stage_start_physics = Engine.get_physics_frames()
		3:
			_hold_heading()
			_trace()
			if not _walking:
				if _both_open():
					_walking = true
					_stage_start_physics = Engine.get_physics_frames()
					Input.action_press(&"move_forward")
			elif _elapsed_physics() >= LEDGE_FRAMES:
				_finish_ledge_test()
				_shoot("portal_ledge.png")
				_stage = 4
				_stage_start_physics = Engine.get_physics_frames()
		4:
			# Long enough for the 1.4 s close animation to finish.
			if _elapsed_physics() >= CLOSE_FRAMES:
				if _closing_surface != null and _closing_surface.has_hole():
					_fail("the retired portal's opening never closed")
				else:
					print("old opening finished closing; wall whole again")
				_test_cut_shape()
				_stage = 5
				_frames = 0
		5:
			_frames += 1
			if _frames >= WARMUP_FRAMES:
				_shoot("portal_fall.png")
				print("")
				print("PORTAL SHOT: ", "FAILED" if _failed else "PASSED")
				quit(1 if _failed else 0)
				return true
	return false


func _elapsed_physics() -> int:
	return Engine.get_physics_frames() - _stage_start_physics


func _fail(message: String) -> void:
	printerr("FAIL: ", message)
	_failed = true


func _resolve_nodes() -> void:
	_builder = _chamber.get_node("ChamberWorld/ChamberBuilder")
	_link = _chamber.get_node("ChamberWorld/PortalLink")
	_player = _chamber.get_node("ChamberWorld/Player")
	print("portalable surfaces built: ", _builder.surfaces.size())


## Surfaces in build order: 0 left wall, 1 right wall, 2 far wall, 3 near wall,
## 4 white floor square, 5 white ceiling square.
func _surface(index: int) -> Node4D:
	return _builder.surfaces[index]


## Places a portal the way the gun does - at a point on a surface, not at a
## pre-chosen slot - so the tests exercise the fit, snap and hole-cutting path a
## player's shot would take.
func _place(index: int, world_point: Vector4, colour: StringName) -> void:
	if not _link.place(_surface(index), world_point, colour):
		_fail("could not place %s on %s: %s" % [colour, _surface(index).name, _link.last_event])


func _start_walk_test() -> void:
	print("")
	print("--- test 1: walk through a pair shot at two facing walls ---")
	_place(0, Vector4(-8.0, 1.0, 0.0, 0.0), &"blue")
	_place(1, Vector4(8.0, 1.0, 0.0, 0.0), &"yellow")
	print("linked: %s" % _link.is_paired())
	# The hole is NOT checked here on purpose: an opening now grows in over its
	# animation rather than appearing at full size, so at placement time there is
	# nothing cut yet. It is asserted once the walk has finished instead.
	# Walked in by pressing the real movement action, not by assigning velocity.
	# Assigning it does nothing on the ground: the controller sets horizontal
	# velocity from input every frame, so an injected 6 m/s decays to zero in two
	# frames and the player coasts to a halt short of the opening - which is
	# exactly what the first version of this test "measured".
	_player.global_position = Vector4(-6.0, 1.2, 0.0, 0.0)
	_player.global_basis = Basis4D.from_zx(PI * 0.5) # Forward (-z) now points along -x.
	_pinned_basis = _player.global_basis
	_player.linear_velocity = Vector4.ZERO
	_walking = false # Forward is pressed once the openings have finished growing.


func _finish_walk_test() -> void:
	Input.action_release(&"move_forward")
	if not _surface(0).has_hole() or not _surface(1).has_hole():
		_fail("a linked pair never finished cutting holes in both surfaces")
	print("crossings: %d" % _link.teleport_count)
	print("player now at %s" % _player.global_position)
	if _link.teleport_count < 1:
		_fail("player walked into an open portal and did not cross")
		return
	# Exited the right-hand pad, so they must be INSIDE the room (x below +8)
	# and still travelling away from that wall, not back into it.
	if _player.global_position.x > 7.9 or _player.global_position.x < 0.0:
		_fail("exit position %s is not just inside the far wall" % _player.global_position)
	if _player.linear_velocity.x > 0.0:
		_fail("exit velocity points back into the wall - the half turn is wrong")


func _start_fall_test() -> void:
	print("")
	print("--- test 2: the endless fall (floor pad linked to ceiling pad) ---")
	_place(4, Vector4(3.0, 0.0, 3.0, 0.0), &"blue")
	_place(5, Vector4(3.0, 6.0, 3.0, 0.0), &"yellow")
	_seen_crossings = _link.teleport_count
	_fall_speeds.clear()
	# Dropped straight down the shared footprint of the two white squares.
	_player.global_position = Vector4(3.0, 3.0, 3.0, 0.0)
	_player.linear_velocity = Vector4.ZERO


func _sample_fall() -> void:
	if _link.teleport_count > _seen_crossings:
		_seen_crossings = _link.teleport_count
		_fall_speeds.append(_link.last_teleport_speed)
	_trace()


func _trace() -> void:
	var elapsed: int = _elapsed_physics()
	if elapsed % 15 == 0 and elapsed != _last_traced_physics:
		_last_traced_physics = elapsed
		var blue_open: String = "none"
		if _link.blue != null and is_instance_valid(_link.blue):
			blue_open = "%.2f hole=%s" % [_link.blue.openness, _link.blue.surface.has_hole()]
		print("  physics frame %3d  pos %s  vel %.1f m/s  crossings %d  blue %s" % [
			elapsed, _player.global_position, _player.linear_velocity.length(),
			_link.teleport_count, blue_open])


func _finish_fall_test() -> void:
	print("crossings during the fall: %d" % _fall_speeds.size())
	for i in range(_fall_speeds.size()):
		print("  crossing %d at %.1f m/s" % [i + 1, _fall_speeds[i]])
	if _fall_speeds.size() < 2:
		_fail("expected repeated crossings in a floor-to-ceiling loop, got %d" % _fall_speeds.size())
		return
	# The point of the whole exercise: each pass through must be faster than the
	# last, because the fall between them is still accelerating.
	if _fall_speeds[_fall_speeds.size() - 1] <= _fall_speeds[0]:
		_fail("speed did not rise across the loop (%.1f -> %.1f m/s): momentum is being lost" % [
			_fall_speeds[0], _fall_speeds[_fall_speeds.size() - 1]])
	else:
		print("speed rose %.1f -> %.1f m/s across the loop - momentum survives the crossing" % [
			_fall_speeds[0], _fall_speeds[_fall_speeds.size() - 1]])


## Test 3, the level's actual premise: the ledge is 3 m up and the player jumps
## 1.03 m, so the only way onto it is to arrive through the opening above it.
## If this fails the chamber has a goal nobody can reach, which no amount of
## correct portal maths would make up for.
func _start_ledge_test() -> void:
	print("")
	print("--- test 3: reach the ledge, which cannot be jumped to ---")
	_place(3, Vector4(0.0, 1.0, 10.0, 0.0), &"blue") # Near wall, behind the spawn.
	_place(2, Vector4(0.0, 3.9, -10.0, 0.0), &"yellow") # Far wall, above the ledge.
	_builder.goal_reached = false
	_player.global_position = Vector4(0.0, 1.2, 8.0, 0.0)
	_player.global_basis = Basis4D.from_zx(PI) # Forward now points along +z.
	_pinned_basis = _player.global_basis
	_player.linear_velocity = Vector4.ZERO
	_walking = false


func _finish_ledge_test() -> void:
	Input.action_release(&"move_forward")
	print("player ended at %s" % _player.global_position)
	print("ledge reached: %s" % _builder.goal_reached)
	if not _builder.goal_reached:
		_fail("walked into the near opening and never arrived on the ledge")
	_test_replacement()


## Test 4: shooting a colour that is already placed must deactivate the old one
## at once - its hole becomes wall again immediately, while the oval animates
## shut. This is Portal's stated behaviour and the thing that makes a portal gun
## feel like a gun rather than a placement menu.
func _test_replacement() -> void:
	print("")
	print("--- test 4: shooting blue again closes the old blue ---")
	var first: Node4D = _link.blue
	_closing_surface = first.surface
	_place(1, Vector4(8.0, 1.0, -4.0, 0.0), &"blue")

	# Deactivated immediately - it stops counting as a portal the instant the new
	# one is fired - but its geometry collapses over the close animation, which
	# is what "closes slowly" means. Both halves are asserted: the flag now, the
	# wall being whole again once the animation has had time to run.
	if not is_instance_valid(first) or not first.is_closing:
		_fail("the previous blue portal was not retired")
	else:
		print("old blue deactivated at once, now collapsing (openness %.2f)" % first.openness)
	if _link.blue == null or _link.blue.surface != _surface(1):
		_fail("the new blue portal did not take its place")
	else:
		print("new blue placed on %s, growing in (openness %.2f)" % [
			_surface(1).name, _link.blue.openness])


## Test 5: the cut has to stay a disc at every size the animation passes
## through, not just at full size.
##
## Regression test for a real bug: the strips carry a minimum chord so a
## floor-tangent opening has no impassable sliver across its base, and that
## minimum used to be a fixed 0.4 m. For the first third of the open/close
## animation the hole's own radius is smaller than that, so every strip
## collapsed to a negative span and was skipped - leaving the disc's full SQUARE
## bounding box open, shrinking underneath a round collar. It read on screen as
## flickering, inverted-looking geometry. Four pieces means all the strips went.
func _test_cut_shape() -> void:
	print("")
	print("--- test 5: the cut stays circular at every animation size ---")
	var surface: Node4D = _surface(0)
	var solid: StaticBody4D = surface.get_node("Solid")
	for fraction in [0.15, 0.3, 0.6, 1.0]:
		var radius: float = ApertureScript.hole_radius() * fraction
		var started_usec: int = Time.get_ticks_usec()
		surface.open_hole(Vector2.ZERO, radius, &"blue")
		var rebuild_msec: float = float(Time.get_ticks_usec() - started_usec) / 1000.0
		var pieces: int = solid.get_child_count()
		print("  radius %.2f m -> %d wall pieces, re-cut in %.1f ms" % [radius, pieces, rebuild_msec])
		if pieces <= 4:
			_fail("at radius %.2f m every strip collapsed: the opening is a square, not a disc" % radius)
	surface.close_hole()


func _shoot(out_name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("PORTAL SHOT: no viewport image - running with --headless?")
		return
	var absolute := ProjectSettings.globalize_path("res://ramon/Portal/" + out_name)
	if image.save_png(absolute) != OK:
		printerr("PORTAL SHOT: save failed for ", absolute)
		return
	print("wrote ", absolute)
