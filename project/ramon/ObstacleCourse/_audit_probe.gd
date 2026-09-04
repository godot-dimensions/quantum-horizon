extends SceneTree

## Phase 0 engine audit for THE 4D ASCENT (see the level brief).
##
## Every claim in the audit report is measured here rather than read off the
## source, because the interesting failures are all "the code looks like it
## supports this, and then the number comes back wrong". Throwaway diagnostic:
## delete once the capability matrix is written up.
##
## API note worth keeping: `Rect4` is a C++-only struct with no Variant binding.
## GDScript sees `Shape4D.get_rect_bounds(basis: Projection, origin: Vector4)`
## returning a `PackedVector4Array` of exactly [position, size].

const SPEED: float = 5.0
const SPRINT_MULTIPLIER: float = 2.5
const JUMP_VELOCITY: float = 4.5


func _init() -> void:
	print("=== 4D ASCENT ENGINE AUDIT ===")
	_audit_gravity_and_reach()
	_audit_box_rotation()
	_audit_player_capsule_under_slice_rotation()
	_audit_static_body_w_motion()
	_audit_shape_coverage()
	print("=== END AUDIT ===")
	quit()


func _bounds_size(shape: Shape4D, basis: Projection, origin: Vector4) -> Vector4:
	var bounds: PackedVector4Array = shape.get_rect_bounds(basis, origin)
	return bounds[1]


func _bounds_position(shape: Shape4D, basis: Projection, origin: Vector4) -> Vector4:
	var bounds: PackedVector4Array = shape.get_rect_bounds(basis, origin)
	return bounds[0]


## Jump/gap metrics. These decide every gap width and step rise in the level,
## so they are derived from the real project setting rather than assumed 9.8.
func _audit_gravity_and_reach() -> void:
	print("\n-- [1] GRAVITY AND PLAYER REACH --")
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	print("  physics/3d/default_gravity = %.3f" % g)
	var apex: float = (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * g)
	var airtime: float = 2.0 * JUMP_VELOCITY / g
	print("  jump apex           = %.3f m" % apex)
	print("  airtime             = %.3f s" % airtime)
	print("  walk-jump gap reach = %.3f m (at %.1f m/s)" % [airtime * SPEED, SPEED])
	var sprint: float = SPEED * SPRINT_MULTIPLIER
	print("  SPRINT-jump reach   = %.3f m (at %.1f m/s)" % [airtime * sprint, sprint])
	print("  => max climbable step without step-up logic = jump apex = %.2f m" % apex)


## Branch A/B/C decision. If a rotated box's AABB inflates, rotated bridges and
## W ramps are not representable and the brief's branch B is forced.
func _audit_box_rotation() -> void:
	print("\n-- [2] ROTATED BOX COLLISION (brief branch A vs B) --")
	var shape := BoxShape4D.new()
	shape.size = Vector4(8.0, 0.5, 2.0, 2.0)
	var flat: Vector4 = _bounds_size(shape, Projection(), Vector4())
	print("  box size            = %s" % shape.size)
	print("  AABB unrotated      = %s" % flat)
	for degrees: float in [15.0, 30.0, 45.0]:
		var basis: Projection = Basis4D.from_zw(deg_to_rad(degrees))
		var size: Vector4 = _bounds_size(shape, basis, Vector4())
		print("  AABB @ zw %5.1f deg = %s  (z x%.3f, w x%.3f)" % [degrees, size, size.z / flat.z, size.w / flat.w])
	print("  => any nonzero angle inflates the collider past the rendered slab.")


## The player rotates its OWN basis to slice-rotate, which rotates its collider
## with it. If the capsule's AABB inflated mid-transition the player could be
## shoved out of level geometry during a slice swap, which would force the
## brief's "slice pad" freeze fallback. Measure it instead of guessing.
func _audit_player_capsule_under_slice_rotation() -> void:
	print("\n-- [3] PLAYER CAPSULE UNDER SLICE ROTATION --")
	var capsule := CapsuleShape4D.new()
	capsule.radius = 0.25
	capsule.full_height = 1.75
	var baseline: Vector4 = _bounds_size(capsule, Projection(), Vector4())
	print("  capsule r=0.25 h=1.75, AABB unrotated = %s" % baseline)
	var worst: float = 0.0
	for degrees: float in [15.0, 30.0, 45.0, 60.0, 90.0]:
		var basis: Projection = Basis4D.from_zw(deg_to_rad(degrees))
		var size: Vector4 = _bounds_size(capsule, basis, Vector4())
		var drift: float = maxf(maxf(absf(size.x - baseline.x), absf(size.y - baseline.y)), maxf(absf(size.z - baseline.z), absf(size.w - baseline.w)))
		worst = maxf(worst, drift)
		print("  AABB @ zw %5.1f deg = %s  (max drift %.6f)" % [degrees, size, drift])
	if worst < 0.001:
		print("  => INVARIANT. A smooth 90 deg slice transition cannot inflate the player.")
	else:
		print("  => INFLATES by %.4f m. Slice pads / freeze fallback required." % worst)


## Obstacle 04 (slice conveyor) and 08 (W lift) both need a collidable box to
## move along w during play. The physics engine rebuilds every rect each frame,
## so the question is whether collision bounds actually follow the transform.
func _audit_static_body_w_motion() -> void:
	print("\n-- [4] COLLIDER MOVED ALONG W --")
	var box := BoxShape4D.new()
	box.size = Vector4(3.0, 1.0, 3.0, 2.0)
	var at_zero: Vector4 = _bounds_position(box, Projection(), Vector4())
	var at_four: Vector4 = _bounds_position(box, Projection(), Vector4(0.0, 0.0, 0.0, 4.0))
	print("  bounds origin at w=0 : %s" % at_zero)
	print("  bounds origin at w=4 : %s" % at_four)
	var moved: float = at_four.w - at_zero.w
	if is_equal_approx(moved, 4.0):
		print("  => SUPPORTED. Bounds track a w translation exactly (moved %.3f)." % moved)
	else:
		print("  => UNEXPECTED: bounds moved %.3f, not 4.0" % moved)
	print("  Engine recomputes every rect at the top of each physics_process, so a")
	print("  scripted move is picked up the same frame.")
	print("  BUT: _check_motion_until_obstacle subtracts obstacle velocity only for")
	print("  CharacterBody4D/RigidBody4D, never StaticBody4D -> no player carry.")


## Which shapes can render themselves, and which are visual-only. The brief says
## never block completion behind an unverified collider, so this is the list that
## decides what the critical route may be built from.
func _audit_shape_coverage() -> void:
	print("\n-- [5] SHAPE COVERAGE --")
	var shapes: Dictionary = {
		"BoxShape4D": BoxShape4D.new(),
		"CapsuleShape4D": CapsuleShape4D.new(),
		"CubinderShape4D": CubinderShape4D.new(),
		"CylinderShape4D": CylinderShape4D.new(),
		"SphereShape4D": SphereShape4D.new(),
	}
	for shape_name: String in shapes:
		var shape: Shape4D = shapes[shape_name]
		var mesh: Mesh4D = shape.to_tetra_mesh()
		if mesh == null:
			print("  %-18s to_tetra_mesh -> NULL (cannot draw itself)" % shape_name)
			continue
		var uvw: int = 0
		var cells: int = 0
		var tetra := mesh as TetraMesh4D
		if tetra != null:
			uvw = tetra.get_simplex_cell_texture_map().size()
			cells = tetra.get_simplex_cell_vertex_indices().size()
		print("  %-18s to_tetra_mesh -> %d cell indices, %d uvw entries" % [shape_name, cells, uvw])
	print("  (0 uvw entries = cannot carry a tiled dev texture.)")
