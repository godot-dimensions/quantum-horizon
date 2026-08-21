extends SceneTree

## Headless structural check for THE 4D ASCENT, Phase 1.
##
## Run with the editor CLOSED - two Godot processes on one `.godot` cache
## silently breaks @tool buttons in the running editor:
##
##   engine/godot/bin/godot.windows.editor.double.x86_64.console.exe --headless \
##       --path project --script res://ramon/ObstacleCourse/_verify_ascent.gd
##
## Headless has no renderer, so everything proved here is STRUCTURAL. It cannot
## tell you whether the tower looks good, only whether it is built and walkable
## in principle. The Phase 1 exit gate ("ordinary 3D traversal complete") needs a
## human on the keyboard; this checks the parts a human would waste time on.

## Scene to check, from user args after `--`. Defaults to the helix course:
##   ... --script res://ramon/ObstacleCourse/_verify_ascent.gd -- ascent_wall.tscn
const DEFAULT_SCENE := "res://ramon/ObstacleCourse/ascent.tscn"
const GENERATED_META := &"ascent_generated"

## Measured in `_audit_probe.gd` - jump apex at JUMP_VELOCITY 4.5, gravity 9.8.
const JUMP_APEX := 1.033

var _failures: int = 0
var _scene: Node = null


## Checks run on the first _process frame, NOT in _initialize(). Nodes added
## during _initialize() are not yet flagged as inside the tree, so _ready() has
## not fired and the builder has generated nothing - checking there reports a
## false failure on a course that is perfectly fine. Same trap, and same fix, as
## `_verify_hub.gd` documents.
func _initialize() -> void:
	print("=== VERIFY: 4D ASCENT (Phase 1 greybox) ===")
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	if not scene_path.begins_with("res://"):
		scene_path = "res://ramon/ObstacleCourse/" + scene_path
	print("checking: ", scene_path)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		_fail("scene failed to load: %s" % scene_path)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	if _scene == null:
		_finish()
		return true

	var course: Node4D = _scene.get_node_or_null(^"Course")
	if course == null:
		_fail("no Course node")
		_finish()
		return true

	_check_generation(course)
	_check_ownership(course, _scene)
	_check_step_rises(course)
	_check_checkpoints(course)
	_check_no_rotated_colliders(course)
	_check_stair_advance(course)
	_check_headroom(course)
	_check_no_interpenetration(course)
	_finish()
	return true


func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL  %s" % message)


func _pass(message: String) -> void:
	print("  ok    %s" % message)


## The spine, one deck per station and one recovery floor per station.
func _check_generation(course: Node4D) -> void:
	print("\n-- generation --")
	# Helix calls them stations, the wall course calls them bays.
	var authored: Variant = course.get("stations")
	if authored == null:
		authored = course.get("bays")
	var expected: int = (authored as Array).size() if authored is Array else 0
	var decks: int = 0
	var resets: int = 0
	var stairs: int = 0
	var spine: bool = false
	for child in course.get_children():
		var child_name: String = String(child.name)
		if child_name == "Spine":
			spine = true
		elif child_name.begins_with("Deck_") or child_name.begins_with("Bay_"):
			decks += 1
		elif child_name.begins_with("TierReset_"):
			resets += 1
		elif child_name.begins_with("Phase1Stair_"):
			stairs += 1
	if spine:
		_pass("spine built")
	else:
		_fail("no spine")
	if decks == expected:
		_pass("%d/%d decks built" % [decks, expected])
	else:
		_fail("%d decks built, expected %d" % [decks, expected])
	# One per tier, not per station. Per-station slabs were tried and stacked
	# into opaque ceilings that buried the tower - see the builder's reset_depth.
	if resets == 3:
		_pass("%d tier reset volumes (one per tier)" % resets)
	else:
		_fail("%d tier reset volumes, expected 3" % resets)
	# One stair per station except the first, which has nothing below it.
	if stairs == expected - 1:
		_pass("%d Phase 1 stair flights (scaffolding, due to be removed beat by beat)" % stairs)
	else:
		_fail("%d stair flights, expected %d" % [stairs, expected - 1])


## Nothing generated may be owned by the scene, or it gets serialised into
## ascent.tscn and goes stale the moment a number changes.
func _check_ownership(course: Node4D, scene: Node) -> void:
	print("\n-- ownership --")
	var owned: int = 0
	var checked: int = 0
	var stack: Array[Node] = [course]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
			if child.has_meta(GENERATED_META):
				checked += 1
				if child.owner == scene:
					owned += 1
	if owned == 0:
		_pass("%d generated nodes, none owned by the scene" % checked)
	else:
		_fail("%d generated nodes are owned by the scene and would be serialised" % owned)


## Every step must be clearable. There is NO step-up logic in CharacterBody4D,
## so a rise at or above the jump apex is a soft-locked course.
func _check_step_rises(course: Node4D) -> void:
	print("\n-- step rises (no step-up logic exists; every rise is jumped) --")
	var worst: float = 0.0
	var flights: int = 0
	for child in course.get_children():
		if not String(child.name).begins_with("Phase1Stair_"):
			continue
		flights += 1
		var heights: Array[float] = []
		for step in child.get_children():
			heights.append((step as Node4D).position.y)
		heights.sort()
		for index in range(1, heights.size()):
			worst = maxf(worst, heights[index] - heights[index - 1])
	if flights == 0:
		_fail("no stair flights to measure")
		return
	print("    largest rise between consecutive steps: %.3f m (jump apex %.3f m)" % [worst, JUMP_APEX])
	if worst < JUMP_APEX:
		_pass("every step is clearable")
	else:
		_fail("a %.3f m rise cannot be jumped - course is soft-locked" % worst)


## Checkpoints must exist and must be w-broad, or a player in a shifted slice
## walks straight through the one thing meant to catch them.
func _check_checkpoints(course: Node4D) -> void:
	print("\n-- checkpoints --")
	var found: int = 0
	var thin: int = 0
	for child in course.get_children():
		# Only the checkpoint volumes - the tier reset planes are Area4Ds too.
		if not (child is Area4D) or not String(child.name).begins_with("Checkpoint_"):
			continue
		found += 1
		for grandchild in child.get_children():
			var collider := grandchild as CollisionShape4D
			if collider == null:
				continue
			var box := collider.shape as BoxShape4D
			if box != null and box.size.w < 8.0:
				thin += 1
	if found >= 3:
		_pass("%d checkpoint volumes (brief asks for three, one per tier)" % found)
	else:
		_fail("%d checkpoint volumes, brief asks for three" % found)
	if thin == 0:
		_pass("every checkpoint is w-broad enough to catch a slice-shifted player")
	else:
		_fail("%d checkpoint colliders are w-thin and can be missed by rotating" % thin)


## The audit measured a rotated BoxShape4D inflating its collider by x1.414 at
## 45 degrees zw, so a rotated collider never matches what is drawn. Nothing in
## this course may carry one.
func _check_no_rotated_colliders(course: Node4D) -> void:
	print("\n-- no rotated colliders (rotation inflates AABB up to x1.414) --")
	var rotated: int = 0
	var checked: int = 0
	var identity := Projection()
	var stack: Array[Node] = [course]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
			var body := child as CollisionObject4D
			if body == null:
				continue
			checked += 1
			# Projection has no is_equal_approx, so compare columns as Vector4s.
			var basis: Projection = body.global_basis
			var aligned: bool = (
					basis.x.is_equal_approx(identity.x)
					and basis.y.is_equal_approx(identity.y)
					and basis.z.is_equal_approx(identity.z)
					and basis.w.is_equal_approx(identity.w)
			)
			if not aligned:
				rotated += 1
				print("    rotated: %s" % body.name)
	if rotated == 0:
		_pass("%d collision objects, all axis-aligned" % checked)
	else:
		_fail("%d collision objects are rotated and will collide larger than they look" % rotated)


## A staircase has to go somewhere, not just up.
##
## With no step-up logic every rise is jumped, so each step needs a tread you can
## land on that is NOT under the next step. If a flight advances less than one
## step footprint per step, consecutive treads overlap in plan and the upper slab
## hangs over the lower one - at the worst measured case, 0.17 m of advance
## against a 2.0 m footprint, which puts the next step's underside 0.3 m above
## your feet exactly where you have to stand. That is unclimbable, and in play it
## reads as the character controller sticking rather than as a level bug.
func _check_stair_advance(course: Node4D) -> void:
	print("\n-- stair advance (treads must not overlap in plan) --")
	var worst_name: String = ""
	var worst: float = INF
	var footprint: float = 0.0
	var flights: int = 0

	for child in course.get_children():
		if not String(child.name).begins_with("Phase1Stair_"):
			continue
		flights += 1
		var steps: Array[Node4D] = []
		for step in child.get_children():
			steps.append(step as Node4D)
		if steps.size() < 2:
			continue
		# Footprint is the step box's own x size, read back off the collider.
		for grandchild in steps[0].get_children():
			var collider := grandchild as CollisionShape4D
			if collider == null:
				continue
			var box := collider.shape as BoxShape4D
			if box != null:
				footprint = box.size.x
		for index in range(1, steps.size()):
			var a: Vector4 = steps[index - 1].position
			var b: Vector4 = steps[index].position
			var advance: float = Vector2(b.x - a.x, b.z - a.z).length()
			if advance < worst:
				worst = advance
				worst_name = String(child.name)

	if flights == 0 or worst == INF:
		_pass("no multi-step flights to measure")
		return
	print("    tightest advance: %.2f m in %s (step footprint %.2f m)" % [worst, worst_name, footprint])
	if worst >= footprint - 0.01:
		_pass("every flight advances at least one footprint per step")
	else:
		_fail("%s advances only %.2f m per step against a %.2f m footprint - treads overlap and the climb is blocked" % [worst_name, worst, footprint])


## A surface you cannot stand on is not a surface.
##
## The player capsule is 1.75 m tall, so every walkable top face needs that much
## clear space above it. Interpenetration checks miss this entirely: a step
## tucked under a deck's overhang does not intersect anything, it just has a
## ceiling 0.5 m up. Reported in play as "I can not use the second grey block to
## climb, it is like it is nested under it" - which is exactly what it was.
func _check_headroom(course: Node4D) -> void:
	print("
-- headroom (player is 1.75 m tall) --")
	const NEEDED := 1.75
	const SLACK := 0.05

	var boxes: Array = []
	var stack: Array[Node] = [course]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
			var body := child as StaticBody4D
			if body == null:
				continue
			for grandchild in body.get_children():
				var collider := grandchild as CollisionShape4D
				if collider == null:
					continue
				var box := collider.shape as BoxShape4D
				if box == null:
					continue
				var centre: Vector4 = body.global_position
				var parent: Node = body.get_parent()
				var label: String = String(body.name)
				if parent != null and parent != course:
					label = "%s/%s" % [parent.name, label]
				boxes.append({
					"name": label,
					"min": centre - box.size * 0.5,
					"max": centre + box.size * 0.5,
				})

	var blocked: int = 0
	var worst: float = NEEDED
	var worst_desc: String = ""
	for surface: Dictionary in boxes:
		# Only the parts a player would actually stand on.
		if not (String(surface["name"]).contains("Step_") or String(surface["name"]).begins_with("Bay_") or String(surface["name"]).begins_with("Deck_")):
			continue
		var top: float = surface["max"].y
		for ceiling: Dictionary in boxes:
			if ceiling["name"] == surface["name"]:
				continue
			# Must overlap in plan and in w to be overhead at all.
			if ceiling["min"].x >= surface["max"].x - SLACK or ceiling["max"].x <= surface["min"].x + SLACK:
				continue
			if ceiling["min"].z >= surface["max"].z - SLACK or ceiling["max"].z <= surface["min"].z + SLACK:
				continue
			if ceiling["min"].w >= surface["max"].w - SLACK or ceiling["max"].w <= surface["min"].w + SLACK:
				continue
			var gap: float = ceiling["min"].y - top
			if gap < -SLACK or gap >= NEEDED:
				continue # Below the surface, or high enough to walk under.
			# How much of the surface does the thing overhead actually cover? A
			# step resting on a wide deck blocks a small patch you can simply walk
			# around; a deck overhanging a narrow step blocks all of it. Only the
			# second kind stops the route, so only the second kind is a failure.
			var overlap_x: float = minf(ceiling["max"].x, surface["max"].x) - maxf(ceiling["min"].x, surface["min"].x)
			var overlap_z: float = minf(ceiling["max"].z, surface["max"].z) - maxf(ceiling["min"].z, surface["min"].z)
			var surface_area: float = (surface["max"].x - surface["min"].x) * (surface["max"].z - surface["min"].z)
			if surface_area <= 0.0:
				continue
			var covered: float = (overlap_x * overlap_z) / surface_area
			if covered < 0.5:
				continue
			blocked += 1
			if gap < worst:
				worst = gap
				worst_desc = "%s under %s" % [surface["name"], ceiling["name"]]
			if blocked <= 10:
				print("    %s: %.0f%% covered by %s, only %.2f m clear" % [surface["name"], covered * 100.0, ceiling["name"], gap])

	if blocked == 0:
		_pass("every walkable surface has 1.75 m of clear space above it")
	else:
		_fail("%d walkable surfaces are unstandable (worst: %s at %.2f m)" % [blocked, worst_desc, worst])


## Two solid boxes occupying the same space render as fighting white patches that
## punch through everything around them - the flat cross-section shader has no
## depth bias to hide it, so an overlap that would be an invisible z-fight in an
## ordinary 3D engine is a glaring artifact here.
##
## This shipped twice before being caught by eye: a ground slab exactly
## co-volumetric with a bay authored at height 0, and a recovery slab whose y was
## computed with the wrong sign so it rode up into the deck above it. Both are
## trivially detectable from the tree, which is why this check exists.
##
## Touching face-to-face is fine and expected - a deck sitting on a step shares a
## plane. Only genuine interpenetration on ALL FOUR axes counts.
func _check_no_interpenetration(course: Node4D) -> void:
	print("\n-- no interpenetrating solids (coincident boxes render as white artifacts) --")
	const TOLERANCE := 0.01

	var boxes: Array = []
	var stack: Array[Node] = [course]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
			var body := child as StaticBody4D
			if body == null:
				continue
			for grandchild in body.get_children():
				var collider := grandchild as CollisionShape4D
				if collider == null:
					continue
				var box := collider.shape as BoxShape4D
				if box == null:
					continue
				var centre: Vector4 = body.global_position
				# Qualified by parent, because every stair flight names its steps
				# Step_01.. and a bare name cannot say which flight clashed.
				var parent: Node = body.get_parent()
				var label: String = String(body.name)
				if parent != null and parent != course:
					label = "%s/%s" % [parent.name, label]
				boxes.append({"name": label, "min": centre - box.size * 0.5, "max": centre + box.size * 0.5})

	var clashes: int = 0
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			var lo: Vector4 = Vector4(
					maxf(a["min"].x, b["min"].x), maxf(a["min"].y, b["min"].y),
					maxf(a["min"].z, b["min"].z), maxf(a["min"].w, b["min"].w))
			var hi: Vector4 = Vector4(
					minf(a["max"].x, b["max"].x), minf(a["max"].y, b["max"].y),
					minf(a["max"].z, b["max"].z), minf(a["max"].w, b["max"].w))
			var overlap := hi - lo
			if overlap.x > TOLERANCE and overlap.y > TOLERANCE and overlap.z > TOLERANCE and overlap.w > TOLERANCE:
				clashes += 1
				if clashes <= 8:
					print("    %s <-> %s overlap %.2f x %.2f x %.2f m" % [a["name"], b["name"], overlap.x, overlap.y, overlap.z])

	if clashes == 0:
		_pass("%d solid boxes, none interpenetrating" % boxes.size())
	else:
		_fail("%d interpenetrating pairs among %d boxes - these render as white artifacts" % [clashes, boxes.size()])


func _finish() -> void:
	if _failures == 0:
		print("\n=== PASS ===")
	else:
		print("\n=== %d FAILURE(S) ===" % _failures)
	quit(0 if _failures == 0 else 1)
