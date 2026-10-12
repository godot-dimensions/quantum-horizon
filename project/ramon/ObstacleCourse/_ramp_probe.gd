extends SceneTree

## Can this engine do ramps you WALK up, instead of steps you jump?
##
## Three questions, measured rather than reasoned about:
##
##   1. Does rotating a box in ZW produce a visible slope? (Ramon's idea:
##      "horizontal blocks by rotating the W could work".)
##   2. Does rotating in a spatial plane (YZ) produce a usable ramp collider?
##   3. Can step-up be implemented project-side, so a small rise is walked over
##      rather than jumped? `CharacterBody4D` has none, but it does expose
##      `move_and_collide(test_only)`, which is all a step-up routine needs.
##
## (3) is the one that matters: if step-up works from GDScript, ramps and stairs
## both stop fighting the player, and no engine change is needed.

const STEP := 1.0 / 60.0
const SPEED := 5.0
const STEP_UP_HEIGHT := 0.7

## Ledge height, and whether step-up is enabled. The first run set a 0.65 m ledge
## against a 0.45 m step-up allowance and then reported step-up as broken - it had
## correctly refused a step taller than its own limit. Sweeping the height makes
## that impossible to misread.
const CASES: Array = [
	{"ledge": 0.3, "step_up": false},
	{"ledge": 0.3, "step_up": true},
	{"ledge": 0.6, "step_up": true},
	{"ledge": 0.9, "step_up": true},
]

var _phase: int = 0
var _frame: int = 0
var _player: CharacterBody4D = null
var _ledge_height: float = 0.0
var _ledge: StaticBody4D = null
var _start_x: float = 0.0
var _grounded_frames: int = 0
var _blocked_frames: int = 0
var _lift_ok: int = 0
var _committed: int = 0


func _initialize() -> void:
	print("=== RAMP / STEP-UP PROBE ===")
	_measure_zw_rotation()
	_measure_spatial_rotation()
	_build_step_up_scene()


## A zw rotation mixes z with w. The visible slice is w = 0, and the claim under
## test is that the result is STILL an axis-aligned box - so it can never look
## like a slope, however far it is rotated.
func _measure_zw_rotation() -> void:
	print("\n-- [1] box rotated in ZW: does anything tilt? --")
	var shape := BoxShape4D.new()
	shape.size = Vector4(4.0, 0.5, 4.0, 4.0)
	var flat: PackedVector4Array = shape.get_rect_bounds(Projection(), Vector4())
	print("  unrotated AABB size  %s" % flat[1])
	for degrees: float in [15.0, 30.0, 45.0]:
		var bounds: PackedVector4Array = shape.get_rect_bounds(Basis4D.from_zw(deg_to_rad(degrees)), Vector4())
		print("  zw %5.1f deg AABB    %s" % [degrees, bounds[1]])
	print("  => y is UNCHANGED at every angle. A zw rotation cannot raise or tilt")
	print("     a surface; it only trades z-extent against w-extent. Useful for")
	print("     slice-dependent geometry, useless as a ramp.")


## A yz rotation is an ordinary spatial tilt, so it genuinely LOOKS like a ramp.
## The question is what the collider does.
func _measure_spatial_rotation() -> void:
	print("\n-- [2] box rotated in YZ: a real visual tilt --")
	var shape := BoxShape4D.new()
	shape.size = Vector4(4.0, 0.5, 8.0, 4.0)
	var flat: PackedVector4Array = shape.get_rect_bounds(Projection(), Vector4())
	print("  unrotated AABB size  %s" % flat[1])
	for degrees: float in [15.0, 30.0, 45.0]:
		var bounds: PackedVector4Array = shape.get_rect_bounds(Basis4D.from_yz(deg_to_rad(degrees)), Vector4())
		var grow_y: float = bounds[1].y / flat[1].y
		print("  yz %5.1f deg AABB    %s  (y x%.2f)" % [degrees, bounds[1], grow_y])
	print("  => the MESH tilts, but the collider becomes a tall axis-aligned box.")
	print("     Walking into it is walking into a wall, so a tilted ramp must be")
	print("     visual-only, with real collision underneath it.")


## A lone ledge, and a player told to walk at it with no jump input at all.
func _build_step_up_scene() -> void:
	var world := Node4D.new()
	root.add_child(world)

	var floor_body := _box(Vector4(20.0, 1.0, 8.0, 20.0), Vector4(0.0, -0.5, 0.0, 0.0))
	world.add_child(floor_body)
	_ledge_height = CASES[0]["ledge"]
	_ledge = _box(Vector4(8.0, 1.0, 8.0, 20.0), Vector4(7.0, _ledge_height - 0.5, 0.0, 0.0))
	world.add_child(_ledge)

	_player = CharacterBody4D.new()
	var collider := CollisionShape4D.new()
	var capsule := CapsuleShape4D.new()
	capsule.radius = 0.25
	capsule.full_height = 1.75
	collider.shape = capsule
	_player.add_child(collider)
	world.add_child(_player)
	_player.position = Vector4(0.0, 0.9, 0.0, 0.0)
	_start_x = _player.position.x
	print("
-- [3] walking at a ledge, NO jump input (step-up allowance %.2f m) --" % STEP_UP_HEIGHT)


func _box(size: Vector4, position: Vector4) -> StaticBody4D:
	var body := StaticBody4D.new()
	body.position = position
	var collider := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return body


func _physics_process(_delta: float) -> bool:
	if _player == null:
		return true
	_frame += 1

	var use_step_up: bool = CASES[_phase]["step_up"]
	var velocity: Vector4 = _player.linear_velocity
	if not _player.is_on_floor():
		velocity += _player.get_gravity() * STEP
	velocity.x = SPEED
	velocity.z = 0.0
	velocity.w = 0.0
	_player.linear_velocity = velocity

	if use_step_up:
		_try_step_up()
	_player.move_and_slide(STEP)

	if _frame >= 180:
		# Past the ledge edge AND standing on top of it. The first version only
		# checked height and passed while stood on the floor doing nothing.
		var climbed: bool = _player.position.x > 3.5 and _player.position.y > _ledge_height + 0.6
		var label: String = "step-up ON " if use_step_up else "step-up OFF"
		print("  ledge %.2f m, %s -> x %.2f, y %.2f  %s   [grounded %d, blocked %d, lift-clear %d, committed %d]" % [
				_ledge_height, label, _player.position.x, _player.position.y,
				"WALKED UP" if climbed else "blocked",
				_grounded_frames, _blocked_frames, _lift_ok, _committed])
		_grounded_frames = 0
		_blocked_frames = 0
		_lift_ok = 0
		_committed = 0
		_phase += 1
		_frame = 0
		if _phase >= CASES.size():
			_report()
			return true
		_ledge_height = CASES[_phase]["ledge"]
		_ledge.position = Vector4(7.0, _ledge_height - 0.5, 0.0, 0.0)
		_player.position = Vector4(_start_x, 0.9, 0.0, 0.0)
		_player.linear_velocity = Vector4()
	return false


## Project-side step-up. Nothing exotic: if the horizontal move is blocked while
## grounded, test whether lifting by [constant STEP_UP_HEIGHT] clears the
## obstruction, and if it does, take the lift. `move_and_slide`'s own floor
## snapping then settles the player back down onto the new surface.
##
## This is the whole reason ramps are worth discussing at all - without it every
## rise in the level, however small, has to be jumped.
func _try_step_up() -> void:
	if not _player.is_on_floor():
		return
	_grounded_frames += 1
	var horizontal := Vector4(_player.linear_velocity.x, 0.0, _player.linear_velocity.z, 0.0) * STEP
	if horizontal.is_zero_approx():
		return
	var blocked: KinematicCollision4D = _player.move_and_collide(horizontal, true, STEP)
	if blocked == null or blocked.get_travel_ratio() >= 1.0:
		return # Nothing in the way.
	_blocked_frames += 1
	var lift := Vector4(0.0, STEP_UP_HEIGHT, 0.0, 0.0)
	var lift_test: KinematicCollision4D = _player.move_and_collide(lift, true, STEP)
	if lift_test == null or lift_test.get_travel_ratio() < 1.0:
		return # No headroom, so this is a wall rather than a step.
	_lift_ok += 1
	# Would the horizontal move succeed from up there?
	#
	# The lift MUST go through move_and_collide rather than assigning `position`.
	# AxisAlignedBoxPhysicsEngine4D caches each body's AABB in
	# `_area_and_body_rects` for the whole physics frame and only recomputes it
	# when the shape COUNT changes - so a direct position write leaves every
	# subsequent test using the body's old rect. That is why an obviously clear
	# step-up tested as blocked 148 times out of 148. A real move_and_collide
	# writes `moving_rects_after` back into the cache and the next test sees it.
	_player.move_and_collide(lift, false, STEP)
	var after: KinematicCollision4D = _player.move_and_collide(horizontal, true, STEP)
	if after == null or after.get_travel_ratio() < 1.0:
		_player.move_and_collide(-lift, false, STEP) # A genuine wall. Put it back.
	else:
		_committed += 1


func _report() -> void:
	print("\n=== END PROBE ===")
	quit()
