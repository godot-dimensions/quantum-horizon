@tool
extends Node4D

## A black cat, built and rigged the way the chicken and the brachiosaurus are.
##
## ONE HIDE, WITH BRANCHES. The whole animal is a single loft rig: a spine chain from nose
## to rump, with the legs and the tail hanging off it as branch balls. That is how
## animation_test's strider is authored and it is the structure strider_walker.gd expects -
## it collects a leg as a descending chain of three balls hanging off the body, solves it
## with closed-form two-bone IK, and skins the surface to follow. A first attempt here used
## four separate leg rigs swung rigidly from the hip, which animates for free but is not
## the pipeline: it cannot share a surface with the body, the shoulder is a seam rather
## than a taper, and none of the existing walkers can drive it.
##
## BOTH SIDES AUTHORED, NO MIRRORING. A branch ball can generate its own twin, but while
## mirroring is on the two sides ARE the same limb and cannot hold different phases - every
## gait collapses into a pronk, which is what strider_walker's header warns about. The
## answer there is detach_mirror(); the answer here is simply to build the left and the
## right as real balls in the first place, because this is generated rather than sculpted
## and there is no authoring convenience to preserve.
##
## THE HEAD FURNITURE IS NOT PART OF THE HIDE. Ears and eyes are boxes on this node rather
## than children of the head ball, because loft balls hide themselves at runtime and take
## their children with them - the trap that made the chicken's feet vanish. They do not
## follow the head, which is fine while the walker only drives legs.

const RIG := preload("res://ramon/Model/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/Model/scripts/loft_ball_4d.gd")
const WALKER := preload("res://ramon/Model/scripts/strider_walker.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

## Nose to rump, in world units. A cat beside a 1.7-unit person.
@export_range(0.2, 4.0, 0.05) var length: float = 0.95: set = _set_length
@export var fur: Color = Color(0.07, 0.07, 0.09): set = _set_fur
@export var eye: Color = Color(0.85, 0.92, 0.35): set = _set_eye

@export_group("Walking")
@export var walks: bool = true
## Cadence, handed to strider_walker as its belt_speed. NOT a distance: the creature's
## actual pace comes out of stride times cadence, and travel is then measured off the
## planted feet. At the walker's default of 1.6 this animal crawled - measured at under a
## tenth of a unit per second, which is a body length every ten seconds.
@export_range(0.5, 20.0, 0.1) var pace: float = 6.0
@export_range(0.05, 4.0, 0.05) var stride_length: float = 0.42
@export_range(0.02, 2.0, 0.02) var step_height: float = 0.11
@export_range(0.0, 0.3, 0.005) var body_bob: float = 0.02
## How far it strays from where it was put, and how sharply it can turn.
@export_range(0.5, 20.0, 0.5) var roam_radius: float = 5.0
@export_range(5.0, 90.0, 1.0) var turn_rate_degrees: float = 30.0
@export_range(0.5, 12.0, 0.1) var pause_min: float = 1.5
@export_range(0.5, 20.0, 0.1) var pause_max: float = 5.0

var _walker: Node4D
var _home := Vector4.ZERO
var _heading: float = 0.0
var _clock: float = 0.0
var _pause: float = 0.0
var _rng := RandomNumberGenerator.new()


func _set_length(v: float) -> void: length = v; _later()
func _set_fur(v: Color) -> void: fur = v; _later()
func _set_eye(v: Color) -> void: eye = v; _later()


func _ready() -> void:
	_rng.seed = 5150
	_home = position
	_heading = _rng.randf_range(0.0, TAU)
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var u: float = length

	var hide := MeshInstance4D.new()
	hide.name = "Hide"
	hide.set_script(RIG)
	var coat := TetraMaterial4D.new()
	coat.albedo_color = fur
	hide.material_override = coat
	add_child(hide)
	hide.set("profile_sides", 8)
	hide.set("profile_rings", 3)
	# Off before any ball goes in, or each one re-lofts the whole animal as it is added.
	hide.set("live_rebuild", false)
	_own(hide)

	# Spine, nose to rump, as DIRECT children of the rig in order. Not nested one inside
	# the next: strider_walker looks exactly one level down for a limb - body balls under
	# the rig, hips under those - so a nested spine hides every leg from it and it reports
	# finding none. The horse is authored the same flat way.
	var head := _ball(hide, "Head", Vector4(0.0, 0.40 * u, 0.50 * u, 0.0), 0.075 * u)
	var neck := _ball(hide, "Neck", Vector4(0.0, 0.40 * u, 0.37 * u, 0.0), 0.095 * u)
	var chest := _ball(hide, "Chest", Vector4(0.0, 0.40 * u, 0.22 * u, 0.0), 0.125 * u)
	var mid := _ball(hide, "Mid", Vector4(0.0, 0.40 * u, 0.02 * u, 0.0), 0.130 * u)
	var rump := _ball(hide, "Rump", Vector4(0.0, 0.39 * u, -0.18 * u, 0.0), 0.110 * u)

	# Legs, as branches. Named so strider_walker can be told exactly which chains are legs
	# rather than having to guess from which ones descend - the guess is what made the
	# brachiosaurus try to walk on its tail.
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		var shoulder := _ball(chest, "FrontHip" + tag,
			Vector4(side * 0.070 * u, -0.02 * u, 0.02 * u, 0.0), 0.050 * u, true)
		# Long enough to reach the ground AND have slack for a stride - at 0.14 + 0.14
		# against a shoulder 0.38 up, the leg fell short of the floor and the IK clamped
		# flat out, which is why the paw barely swung however fast the cat went.
		var fknee := _ball(shoulder, "FrontKnee" + tag,
			Vector4(side * 0.004 * u, -0.22 * u, -0.01 * u, 0.0), 0.038 * u)
		_ball(fknee, "FrontFoot" + tag, Vector4(0.0, -0.22 * u, 0.03 * u, 0.0), 0.042 * u)

		var hip := _ball(rump, "HindHip" + tag,
			Vector4(side * 0.075 * u, -0.01 * u, 0.0, 0.0), 0.055 * u, true)
		var hknee := _ball(hip, "HindKnee" + tag,
			Vector4(side * 0.004 * u, -0.22 * u, -0.02 * u, 0.0), 0.040 * u)
		_ball(hknee, "HindFoot" + tag, Vector4(0.0, -0.22 * u, 0.04 * u, 0.0), 0.042 * u)

	# The tail, also a branch, rising away from the rump so it never reads as a fifth leg.
	var tail := _ball(rump, "TailBase", Vector4(0.0, 0.05 * u, -0.13 * u, 0.0), 0.035 * u, true)
	var tail_mid := _ball(tail, "TailMid", Vector4(0.0, 0.07 * u, -0.12 * u, 0.0), 0.026 * u)
	_ball(tail_mid, "TailTip", Vector4(0.0, 0.09 * u, -0.09 * u, 0.0), 0.018 * u)

	if hide.has_method("build"):
		hide.call("build", false)

	# Ears and eyes: a loft cannot make a point, and a cat without ears is an otter.
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		_block("Ear" + tag, Vector4(side * 0.050 * u, 0.48 * u, 0.48 * u, 0.0),
			Vector3(0.045 * u, 0.085 * u, 0.035 * u), fur)
		_block("Eye" + tag, Vector4(side * 0.042 * u, 0.42 * u, 0.555 * u, 0.0),
			Vector3(0.026 * u, 0.020 * u, 0.02 * u), eye)

	# And the rig that walks it: the same script that walks the horse and the sauropod.
	var walker := Node4D.new()
	walker.name = "Walker"
	walker.set_script(WALKER)
	# EVERY PROPERTY BEFORE add_child. A node's _ready fires the moment it enters the tree,
	# and this one resolves rig_path there - setting it afterwards left the walker having
	# already given up, reporting that rig_path did not point at a loft rig.
	walker.set("rig_path", NodePath("../Hide"))
	walker.set("leg_name_prefixes", PackedStringArray(["FrontHip", "HindHip"]))
	walker.set("stride_length", stride_length)
	walker.set("step_height", step_height)
	walker.set("body_bob", body_bob)
	# It carries the animal forward off its own planted feet, so this node only has to
	# decide which way is forward.
	walker.set("belt_speed", pace)
	walker.set("travel", true)
	add_child(walker)
	_own(walker)
	_walker = walker


## One ball in the chain, hung off whatever came before it.
func _ball(parent: Node, part: String, at: Vector4, radius: float,
		branch: bool = false) -> Node4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.set_script(BALL)
	parent.add_child(node)
	node.position = at
	node.set("radius", radius)
	if branch:
		node.set("starts_branch", true)
		# None, not Mirror: see the header. Both sides are built for real so they can hold
		# opposite phases.
		node.set("symmetry_type", 0)
	_own(node)
	return node


func _block(part: String, at: Vector4, box: Vector3, colour: Color) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(box.x, box.y, box.z, box.x)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	add_child(node)
	node.position = at
	_own(node)


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


## Which way is forward. The walker does the walking; this only steers and stops.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not walks or _walker == null:
		return
	_clock += delta
	if _pause > 0.0:
		_pause -= delta
		_walker.set("travel", false)
		return
	_walker.set("travel", true)
	var offset: Vector4 = position - _home
	if Vector2(offset.x, offset.z).length() > roam_radius:
		_heading = rotate_toward(_heading, atan2(-offset.x, -offset.z),
			deg_to_rad(turn_rate_degrees) * delta * 2.0)
	else:
		_heading += sin(_clock * 0.6) * deg_to_rad(turn_rate_degrees) * delta * 0.5
	basis = Basis4D.from_zx(_heading)
	# Cats stop. Often.
	if _rng.randf() < delta * 0.1:
		_pause = _rng.randf_range(pause_min, pause_max)
