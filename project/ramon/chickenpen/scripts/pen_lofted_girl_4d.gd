@tool
extends Node4D

## A second girl, lofted rather than built from blocks, and walked by the same rig.
##
## WHY A SECOND ONE RATHER THAN REPLACING NESSA. The block girl works and is driven by the
## player's own controller, so she inherits every walk fix for free. This is the other
## experiment: the creature pipeline - a loft hide, branch limbs, strider_walker - pointed
## at a HUMAN instead of an animal. Having both in the same field is the only way to see
## which one a person actually reads as a character, which is the question worth answering
## before a whole cast is committed to either.
##
## A BIPED THROUGH A QUADRUPED WALKER. strider_walker offsets each leg's phase by its index
## across the number of legs it found, so with two it puts them exactly half a cycle apart -
## which is what a walk is. Nothing in it assumes four; the horse and the sauropod just
## happen to have four.
##
## ARMS ARE BRANCHES THAT DO NOT DESCEND, which is the whole reason the descent test
## exists: they hang off the chest exactly as the legs hang off the hips, and they are
## excluded from the gait because they point along the body rather than down it. They
## still get lofted into the surface, so she has arms without the walker trying to step
## on them.

const RIG := preload("res://ramon/Model/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/Model/scripts/loft_ball_4d.gd")
const WALKER := preload("res://ramon/Model/scripts/strider_walker.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

## Head to heel. Three quarters of the player, like her block-built twin.
@export_range(0.3, 4.0, 0.05) var height: float = 1.30: set = _set_height
@export var cloth: Color = Color(0.84, 0.34, 0.36): set = _set_cloth
@export var skin: Color = Color(0.95, 0.80, 0.68): set = _set_skin
@export var hair: Color = Color(0.78, 0.22, 0.12): set = _set_hair

@export_group("Walking")
@export var walks: bool = true
@export_range(0.05, 4.0, 0.05) var stride_length: float = 0.46
@export_range(0.02, 2.0, 0.02) var step_height: float = 0.10
@export_range(0.0, 0.3, 0.005) var body_bob: float = 0.03
@export_range(0.5, 20.0, 0.5) var roam_radius: float = 5.0
@export_range(5.0, 90.0, 1.0) var turn_rate_degrees: float = 32.0

var _walker: Node4D
var _home := Vector4.ZERO
var _heading: float = 0.0
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _set_height(v: float) -> void: height = v; _later()
func _set_cloth(v: Color) -> void: cloth = v; _later()
func _set_skin(v: Color) -> void: skin = v; _later()
func _set_hair(v: Color) -> void: hair = v; _later()


func _ready() -> void:
	_rng.seed = 31337
	_home = position
	_heading = _rng.randf_range(0.0, TAU)
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var u: float = height

	var hide := MeshInstance4D.new()
	hide.name = "Hide"
	hide.set_script(RIG)
	var coat := TetraMaterial4D.new()
	coat.albedo_color = cloth
	hide.material_override = coat
	add_child(hide)
	hide.set("profile_sides", 8)
	hide.set("profile_rings", 3)
	hide.set("live_rebuild", false)
	_own(hide)

	# Spine, crown down to hips, flat under the rig - the collector only looks one level
	# down, so a nested chain would hide every limb from it.
	var crown := _ball(hide, "Crown", Vector4(0.0, 0.98 * u, 0.0, 0.0), 0.088 * u)
	var head := _ball(hide, "Head", Vector4(0.0, 0.90 * u, 0.0, 0.0), 0.095 * u)
	var neck := _ball(hide, "Neck", Vector4(0.0, 0.80 * u, 0.0, 0.0), 0.048 * u)
	var chest := _ball(hide, "Chest", Vector4(0.0, 0.70 * u, 0.0, 0.0), 0.105 * u)
	var waist := _ball(hide, "Waist", Vector4(0.0, 0.58 * u, 0.0, 0.0), 0.082 * u)
	var hips := _ball(hide, "Hips", Vector4(0.0, 0.48 * u, 0.0, 0.0), 0.095 * u)

	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		# Legs: hip, knee, foot. These descend, so the walker takes them.
		var hip := _ball(hips, "LegHip" + tag,
			Vector4(side * 0.062 * u, -0.02 * u, 0.0, 0.0), 0.052 * u, true)
		var knee := _ball(hip, "LegKnee" + tag,
			Vector4(side * 0.004 * u, -0.22 * u, 0.0, 0.0), 0.042 * u)
		_ball(knee, "LegFoot" + tag, Vector4(0.0, -0.22 * u, 0.03 * u, 0.0), 0.045 * u)

		# Arms: shoulder, elbow, hand. These hang almost straight down too, so they are
		# kept out of the gait by NAME rather than by slope - see leg_name_prefixes below.
		var shoulder := _ball(chest, "ArmTop" + tag,
			Vector4(side * 0.105 * u, 0.02 * u, 0.0, 0.0), 0.040 * u, true)
		var elbow := _ball(shoulder, "ArmMid" + tag,
			Vector4(side * 0.018 * u, -0.15 * u, 0.0, 0.0), 0.032 * u)
		_ball(elbow, "ArmEnd" + tag, Vector4(0.0, -0.14 * u, 0.01 * u, 0.0), 0.030 * u)

	if hide.has_method("build"):
		hide.call("build", false)

	# Face and hair as blocks, for the same reason the cat's ears are: a loft cannot make
	# a flat plane or a point, and these do not need to deform.
	_block("Face", Vector4(0.0, 0.90 * u, 0.075 * u, 0.0),
		Vector3(0.11 * u, 0.10 * u, 0.03 * u), skin)
	_block("Hair", Vector4(0.0, 0.95 * u, -0.045 * u, 0.0),
		Vector3(0.17 * u, 0.15 * u, 0.09 * u), hair)
	_block("Tail1", Vector4(0.0, 0.86 * u, -0.10 * u, 0.0),
		Vector3(0.08 * u, 0.15 * u, 0.06 * u), hair)
	_block("Tail2", Vector4(0.0, 0.74 * u, -0.12 * u, 0.0),
		Vector3(0.06 * u, 0.12 * u, 0.05 * u), hair)

	var walker := Node4D.new()
	walker.name = "Walker"
	walker.set_script(WALKER)
	walker.set("rig_path", NodePath("../Hide"))
	# LEGS ONLY, BY NAME. Her arms hang as straight down as her legs do, so the slope test
	# cannot tell them apart - it is there to exclude a neck, not an arm. Naming the two
	# chains that are legs is exactly what this export is for.
	walker.set("leg_name_prefixes", PackedStringArray(["LegHip"]))
	walker.set("stride_length", stride_length)
	walker.set("step_height", step_height)
	walker.set("body_bob", body_bob)
	walker.set("travel", true)
	add_child(walker)
	_own(walker)
	_walker = walker


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


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not walks or _walker == null:
		return
	_clock += delta
	var offset: Vector4 = position - _home
	if Vector2(offset.x, offset.z).length() > roam_radius:
		_heading = rotate_toward(_heading, atan2(-offset.x, -offset.z),
			deg_to_rad(turn_rate_degrees) * delta * 2.0)
	else:
		_heading += sin(_clock * 0.5) * deg_to_rad(turn_rate_degrees) * delta * 0.5
	basis = Basis4D.from_zx(_heading)
