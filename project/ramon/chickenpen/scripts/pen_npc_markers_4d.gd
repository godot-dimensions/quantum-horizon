extends Node

## THE NPC MARKERS (Ramon, 7 Oct: "i like there is a rotating marker on the profesor npc, can we make it orange and
## put it around all npcs? even animals? or is it a static placement that never follows along?"): the professor's
## ritual ring, turning slowly, in orange, round the feet of everyone you can talk to and of the animals that walk
## the ground. Each follows its own: under it on the ground, at its x, z and W, wherever it goes.
##
## Not on the chickens (finding them is the game, and no marker may give one away: chicken_cues_4d.gd), nor on what
## flies, perches or climbs (the crows, the owl, the starlings and the hawk, the chipmunks), nor on the wolf (its
## raid is a cutscene).
##
## IN THE DEV LOOK ONLY (Ramon, 7 Oct: "character rings should not be active in art mode"): they follow the look's
## switch (look/pen_look_4d.gd applied_changed); with no look in the scene they show.
##
## The rings are this node's own children, outside World, so the dev look leaves them as they are (it only looks
## under World and the pen) and a scaled animal (Nike at 0.6) does not shrink its ring. One mesh a size, shared,
## each ring a single node. Someone made after the pen loads (the heron, by the Lookout) is looked for again until
## found.
##
## NO class_name (engine_gotchas.md).

const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")

## Who gets one, by node path from the scene's root, and the ring's radius in metres. Those who stand still have
## a clearing in the grass round them (grass/pen_grass_4d.gd clearings); those who roam lay the grass down as they
## go (its pushers), so their rings are drawn in close, inside what they flatten.
@export var targets: Dictionary = {
	"World/ProfessorPost/Professor": 0.85,
	"World/KeeperPost/Keeper": 0.75,
	"World/TrymCabin/Trym": 0.75,
	"World/Range/RangeMaster": 0.75,
	"World/LookoutSite/Wren": 0.75,
	"World/CampGuide/Guide": 0.75,
	"Mithra": 0.45,
	"World/Nike": 0.9,
	"World/RockPileSpot/Cat": 0.4,
	"World/TrymCabin/RedCat": 0.4,
	"World/AnaHeron": 0.7,
}
@export var colour: Color = Color(1.0, 0.3, 0.06)
## How fast the rings turn (turns a second).
@export_range(0.0, 1.0, 0.01) var turns: float = 0.06
## How high over the ground under its owner a ring lies.
@export_range(0.0, 0.2, 0.005, "suffix:m") var lift: float = 0.015

var _rings: Dictionary = {}     # path -> [ring Node4D, owner Node4D or null]
var _meshes: Dictionary = {}    # radius -> mesh
var _material: TetraMaterial4D
var _time: float = 0.0
var _look_again: float = 0.0
var _dev: bool = true


func _ready() -> void:
	var look: Node = get_node_or_null("../Look")
	if look != null and look.has_signal("applied_changed"):
		_dev = bool(look.get("_applied"))
		look.connect("applied_changed", func(on: bool) -> void: _dev = on)
	# The dev look's landmark colour (Ramon, 7 Oct: the panel's swatch), followed when it changes.
	if look != null and "landmark_colour" in look:
		colour = look.get("landmark_colour")
	if look != null and look.has_signal("colours_changed"):
		look.connect("colours_changed", _recolour)
	_material = Mats.glow(colour, 1.0)
	for path in targets:
		var ring := MeshInstance4D.new()
		ring.name = "Marker_" + String(path).get_file()
		ring.mesh = _ring_mesh(float(targets[path]))
		ring.material_override = _material
		ring.visible = false
		# Not a thing standing in the grass: the grass's mask skips it (grass/pen_grass_4d.gd _collect), or a
		# ring would leave a bald circle wherever its owner stood when the pen loaded.
		ring.set_meta(&"_look_own", true)
		add_child(ring)
		_rings[path] = [ring, null]


func _process(delta: float) -> void:
	_time += delta
	_look_again -= delta
	var root: Node = owner if owner != null else get_tree().current_scene
	if root == null:
		return
	var turn: Projection = Basis4D.from_zx(_time * turns * TAU)
	for path in _rings:
		var rec: Array = _rings[path]
		var ring := rec[0] as MeshInstance4D
		var who := rec[1] as Node4D
		if who == null or not is_instance_valid(who):
			who = null
			if _look_again <= 0.0:
				who = root.get_node_or_null(NodePath(String(path))) as Node4D
				rec[1] = who
		if not _dev or who == null or not who.is_visible_in_tree():
			ring.visible = false
			continue
		var at: Vector4 = who.global_position
		# On the ground under it, or at its feet when it stands on something that is not ground (the cat on its
		# rock pile).
		at.y = maxf(_ground_under(at, who), at.y - 0.05) + lift
		ring.global_position = at
		ring.basis = turn
		ring.visible = true
	if _look_again <= 0.0:
		_look_again = 1.0


func _recolour(_foundation: Color, landmark: Color) -> void:
	colour = landmark
	_material = Mats.glow(colour, 1.0)
	for path in _rings:
		(_rings[path][0] as MeshInstance4D).material_override = _material


## The top of whatever static thing is under [param at] (looking through its owner and anyone else who moves),
## or its owner's own height when there is nothing.
func _ground_under(at: Vector4, who: Node4D) -> float:
	var params := RaycastParameters4D.new()
	params.global_ray_origin = at + Vector4(0.0, 1.0, 0.0, 0.0)
	params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
	params.max_distance = 4.0
	var ex: Array[Node4D] = [who]
	for i in 4:
		params.set_exclude_nodes(ex)
		var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
		if hit.is_empty() or not bool(hit.get("hit", false)) or not hit.has("global_point"):
			return at.y
		var body: Object = hit.get("body")
		if body is StaticBody4D:
			return (hit["global_point"] as Vector4).y
		if not (body is Node4D):
			return at.y
		ex.append(body as Node4D)
	return at.y


## Sixteen thin glowing pieces round a circle of [param r] and four runes just outside it, as the professor's
## ring was, in one mesh.
func _ring_mesh(r: float) -> ArrayTetraMesh4D:
	var key: String = "%.2f" % r
	if _meshes.has(key):
		return _meshes[key]
	var mesh := ArrayTetraMesh4D.new()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		var piece := BoxTetraMesh4D.new()
		piece.size = Vector4(2.0 * r * tan(PI / 16.0) * 0.8, 0.012, 0.025 * maxf(r / 0.85, 0.7), 0.42)
		mesh.merge_with(piece.to_array_tetra_mesh(), Vector4(cos(a) * r, 0.0, sin(a) * r, 0.0), Basis4D.from_zx(-a + PI * 0.5))
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + PI * 0.25
		var glyph := BoxTetraMesh4D.new()
		var g: float = 0.10 * clampf(r / 0.85, 0.6, 1.3)
		glyph.size = Vector4(g, 0.012, g, 0.42)
		mesh.merge_with(glyph.to_array_tetra_mesh(), Vector4(cos(a) * (r + 0.16), 0.0, sin(a) * (r + 0.16), 0.0), Basis4D.from_zx(a))
	_meshes[key] = mesh
	return mesh
