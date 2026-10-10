@tool
extends Node4D

## THE BALLOON'S GROUND CREW (discovery, 9 Oct 2026; follow_up/pen_discovery_plan.md, easter egg 2). Where the
## balloon was moored, now that it hovers off in W (lookout/balloon_4d.gd parked): Ramon, "just a firespot. and an
## npc sitting there. simple and short dialogue, where the balloon is in W above or under him". She sits on a log by a
## small fire beside the balloon's stake, its rope climbing out of the ground and stopping in the air; she tells you
## the balloon is right above her, along W (discovery/balloon_crew_script.gd, discovery/pen_balloon_crew_talk_4d.gd).
##
## THE SAME AVATAR AS EVERYBODY ELSE (scripts/block_avatar_4d.gd), seated as Trym sits at his desk (the same hip and
## knee angles), dressed for the balloon: a leather flying jacket, a red scarf, an aviator's cap with goggles. Every
## box hangs on the avatar's own parts, so the dev look leaves her as she is (block_avatar is a character to it).
## The fire as the camp's: a ring of stones, crossed logs, flames that flicker, and its own light.
##
## Faces +z (the avatar's front), the fire in front of her. Move or turn this node to move her and the fire together.
## NO class_name (engine_gotchas.md).

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")

@export var jacket: Color = Color(0.42, 0.28, 0.18)
@export var scarf: Color = Color(0.66, 0.17, 0.14)
@export var trousers: Color = Color(0.26, 0.23, 0.21)
@export var skin: Color = Color(0.78, 0.60, 0.47)
@export var flame: Color = Color(1.0, 0.55, 0.12)
@export var flame_core: Color = Color(1.0, 0.86, 0.35)
@export var fire_colour: Color = Color(1.0, 0.58, 0.28)
@export_range(1.0, 15.0, 0.5, "suffix:m") var fire_reach: float = 6.0
@export_range(0.0, 6.0, 0.05) var fire_energy: float = 1.4
## THE SECOND TAMSIN (Ramon, 10 Oct: "Place a second instance of the same NPC beside the balloon, visible when the
## player aligns with the balloon's W-slice. It doesn't matter that the same character appears in two places. This
## is a 4D world, after all."): standing by the basket, no log, no fire.
@export var seated: bool = true:
	set(v):
		seated = v
		if is_node_ready():
			rebuild()
@export var with_fire: bool = true:
	set(v):
		with_fire = v
		if is_node_ready():
			rebuild()

## Where the fire is, in front of her.
const FIRE := Vector4(0.0, 0.0, 1.45, 0.0)
## Seated as Trym is (scripts/pen_trym_4d.gd THIGH_SIT, SHIN_SIT, SIT_DROP) on a log as high as his stool.
const THIGH_SIT := -1.40
const SHIN_SIT := 1.40
const SIT_DROP := 0.25
const SEAT_H := 0.42

var _flames: Array[Node4D] = []
var _light: OmniLight4D
var _t: float = 0.0


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"_crew_part"):
			remove_child(child)
			child.free()
	_flames.clear()
	_light = null
	if seated:
		_seat()
	_figure()
	if with_fire:
		_fire()
	_solid()
	# The twin by the basket stands at the balloon's W: out of the projection (a character is some thirty meshes, and the
	# projection counts each twice against the instance limit).
	if not seated:
		for mi in find_children("*", "MeshInstance4D", true, false):
			mi.set("allow_projection", false)


## You walk round her, not through her (Ramon, 10 Oct: "I'm also able to walk straight through him"): one box for her
## (and her log), as deep in W as she is; the fire stays walkable, so the end of the path by it is never blocked.
func _solid() -> void:
	var body := StaticBody4D.new()
	body.name = "Solid"
	_part(body)
	var holder := CollisionShape4D.new()
	var shape := BoxShape4D.new()
	shape.size = Vector4(1.3, 1.4, 0.75, 0.6) if seated else Vector4(0.6, 1.8, 0.5, 0.5)
	holder.shape = shape
	holder.position = Vector4(0.0, shape.size.y * 0.5, -0.02 if seated else 0.0, 0.0)
	body.add_child(holder)


func _part(node: Node, parent: Node = null) -> void:
	node.set_meta(&"_crew_part", true)
	(parent if parent != null else self).add_child(node)


func _box(parent: Node, part: String, at: Vector4, size: Vector4, colour: Color, basis_turn: Projection = Projection.IDENTITY) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	node.mesh = mesh
	var mat := TetraMaterial4D.new()
	mat.albedo_color = colour
	node.material_override = mat
	if parent == self:
		_part(node)
	else:
		parent.add_child(node)
	node.position = at
	if basis_turn != Projection.IDENTITY:
		node.basis = basis_turn
	return node


## The log she sits on, behind her: a round-ish trunk on its side.
func _seat() -> void:
	_box(self, "Log", Vector4(0.0, SEAT_H * 0.5, -0.05, 0.0), Vector4(1.3, SEAT_H, 0.42, 0.5), Color(0.35, 0.25, 0.16))
	_box(self, "LogEnd", Vector4(0.66, SEAT_H * 0.5, -0.05, 0.0), Vector4(0.04, SEAT_H * 0.96, 0.40, 0.48), Color(0.60, 0.48, 0.33))


func _figure() -> void:
	var holder := Node4D.new()
	holder.name = "Crew"
	_part(holder)
	var figure := Node4D.new()
	figure.name = "Figure"
	figure.set_script(AVATAR)
	figure.set("build", 2)
	figure.set("skin", jacket)
	figure.set("accent", skin)
	figure.set("hair", Color(0.55, 0.33, 0.18))
	figure.set("wear_cap", false)
	figure.set("eyes", true)
	figure.set("eye_colour", Color(0.12, 0.11, 0.10))
	figure.set("eye_spacing", 0.066)
	figure.set("eye_height", 0.022)
	holder.add_child(figure)
	figure.position = Vector4(0.0, -SIT_DROP, 0.12, 0.0) if seated else Vector4.ZERO
	for tag in ["L", "R"]:
		_paint(figure, "Hip%s/Thigh%s" % [tag, tag], trousers)
		_paint(figure, "Hip%s/Knee%s/Shin%s" % [tag, tag, tag], trousers)
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	if head != null:
		# An aviator's cap in leather, goggles pushed up on it. Through W as the head is.
		_box(head, "Cap", Vector4(0.0, 0.15, -0.01, 0.0), Vector4(0.33, 0.14, 0.32, 0.31), jacket.darkened(0.25))
		for side in [-1.0, 1.0]:
			_box(head, "Goggle%d" % int(side), Vector4(side * 0.075, 0.2, 0.14, 0.0), Vector4(0.09, 0.07, 0.04, 0.09), Color(0.70, 0.78, 0.82))
			_box(head, "Flap%d" % int(side), Vector4(side * 0.16, 0.0, 0.0, 0.0), Vector4(0.03, 0.16, 0.14, 0.2), jacket.darkened(0.25))
	var torso: Node4D = figure.get_node_or_null("Tunic") as Node4D
	if torso != null:
		_box(torso, "Scarf", Vector4(0.0, 0.2, 0.0, 0.0), Vector4(0.40, 0.07, 0.27, 0.37), scarf)
		_box(torso, "ScarfEnd", Vector4(0.1, 0.06, 0.14, 0.0), Vector4(0.07, 0.22, 0.03, 0.08), scarf)
	if not seated:
		return
	# Seated: thighs forward, shins back down, boots flat; arms out to the fire, a slight lean in.
	for side in ["left", "right"]:
		var hip: Node4D = figure.get("hip_%s" % side) as Node4D
		var knee: Node4D = figure.get("knee_%s" % side) as Node4D
		var ankle: Node4D = figure.get("ankle_%s" % side) as Node4D
		if hip != null:
			hip.basis = Basis4D.from_yz(THIGH_SIT)
		if knee != null:
			knee.basis = Basis4D.from_yz(SHIN_SIT)
		if ankle != null:
			ankle.basis = Basis4D.from_yz(-(THIGH_SIT + SHIN_SIT))
		var shoulder: Node4D = figure.get("shoulder_%s" % side) as Node4D
		var elbow: Node4D = figure.get("elbow_%s" % side) as Node4D
		if shoulder != null:
			shoulder.basis = Basis4D.from_yz(-0.85)
		if elbow != null:
			elbow.basis = Basis4D.from_yz(0.55)
	var lean: Node4D = figure.get("torso") as Node4D
	if lean != null:
		lean.basis = Basis4D.from_yz(-0.12)


func _paint(figure: Node, path: String, colour: Color) -> void:
	var limb: MeshInstance4D = figure.get_node_or_null(path) as MeshInstance4D
	if limb == null:
		return
	var mat := TetraMaterial4D.new()
	mat.albedo_color = colour
	limb.material_override = mat


## The fire: a ring of stones, logs crossed in it, flames and their light (as the camp's, scripts/pen_research_camp_4d.gd).
func _fire() -> void:
	var ring := Node4D.new()
	ring.name = "Fire"
	_part(ring)
	ring.position = FIRE
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in 9:
		var a: float = TAU * float(k) / 9.0
		var s: float = rng.randf_range(0.18, 0.26)
		_box(ring, "Stone%d" % k, Vector4(cos(a) * 0.55, s * 0.4, sin(a) * 0.55, rng.randf_range(-0.12, 0.12)),
			Vector4(s * 1.2, s * 0.8, s, s * 1.1), Color(0.48, 0.46, 0.43).darkened(rng.randf_range(0.0, 0.25)), Basis4D.from_zx(-a + rng.randf_range(-0.3, 0.3)))
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + 0.4
		_box(ring, "Firewood%d" % k, Vector4(cos(a) * 0.16, 0.14, sin(a) * 0.16, 0.0), Vector4(0.62, 0.09, 0.09, 0.12),
			Color(0.30, 0.20, 0.12), Basis4D.from_zx(-a) * Basis4D.from_xy(0.35))
	var flames := MeshInstance4D.new()
	flames.name = "Flames"
	var fm := ArrayTetraMesh4D.new()
	for k in 3:
		var box := BoxTetraMesh4D.new()
		box.size = Vector4(0.2, 0.75 - 0.12 * float(k), 0.2, 0.36)
		fm.merge_with(box.to_array_tetra_mesh(), Vector4(cos(float(k) * 1.9) * 0.08, 0.42 - 0.05 * float(k), sin(float(k) * 1.9) * 0.08, 0.0),
			Basis4D.from_zx(0.5 * float(k)))
	flames.mesh = fm
	flames.material_override = Mats.glow(flame, 1.0)
	ring.add_child(flames)
	_flames.append(flames)
	var core := MeshInstance4D.new()
	core.name = "FlameCore"
	var cb := BoxTetraMesh4D.new()
	cb.size = Vector4(0.14, 0.42, 0.14, 0.3)
	core.mesh = cb
	core.material_override = Mats.glow(flame_core, 1.0)
	ring.add_child(core)
	core.position = Vector4(0.0, 0.3, 0.0, 0.0)
	_flames.append(core)
	if not Engine.is_editor_hint():
		_light = OmniLight4D.new()
		_light.name = "FireLight"
		_light.position = Vector4(0.0, 0.9, 0.0, 0.0)
		_light.set("omni_range_meters", fire_reach)
		_light.light_color = fire_colour
		_light.light_energy = fire_energy
		ring.add_child(_light)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	for i in _flames.size():
		var f: Node4D = _flames[i]
		var flick: float = 0.85 + 0.2 * sin(_t * (11.0 + 4.0 * float(i))) * sin(_t * 5.3 + float(i))
		f.basis = Basis4D.from_zx(_t * (0.6 + 0.3 * float(i))) * Basis4D.from_scale(Vector4(1.0, flick, 1.0, 1.0))
	if _light != null:
		_light.light_energy = fire_energy * (0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 5.3 + 1.0))
