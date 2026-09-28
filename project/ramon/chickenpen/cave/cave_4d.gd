extends Node4D

## The cave, as it stands when the pen's crossing brings you in: the baked rock, what you
## can bump into, and the rule that keeps you inside it.
##
## HOSTED, NOT STANDALONE. The pen does not unload when you walk into the hill (see
## pen_crossing_4d.gd): the field is switched off and this scene is added beside it, and it
## is the PEN'S player who walks in - with the same belt, the same pickaxe and the same
## dialogue system - so the gold you dig here is in your belt when you come out, and the
## miner speaks through the same machinery as the professor. Paths out of this scene to
## the player therefore go up one more level than they look like they should.
##
## HUNG A KILOMETRE ALONG x. The field's ground, fence and buildings are switched off
## while you are here, but switching a physics body off is not something this project has
## checked frees its collider, and a cave on top of the pen would be standing in its barn.
## A kilometre away, nothing of the pen can touch it whatever state it is in.
##
## THE WALLS ARE NOT BOXES. Physics here is bounding boxes only (hub_demo_lessons.md) and a
## cave is the least box-shaped thing there is. What keeps you in instead is the same
## density the walls were baked from: past a small margin from the rock you are put back
## on the right side of it, along the density's gradient - so the boundary you feel is the
## boundary you see, to the accuracy of the bake. The floor and the props are boxes as
## usual.

const CaveRock := preload("res://ramon/chickenpen/cave/cave_rock_4d.gd")

@export var player_path: NodePath = NodePath("../Player")
## How much air you keep between you and the rock, in the density's units (about metres).
@export_range(0.1, 2.0, 0.05) var wall_margin: float = 0.55
## The height on the body the test is made at: chest, not feet, since the floor is the
## rock's edge too and feet are always on it.
@export_range(0.2, 2.0, 0.05) var test_height: float = 1.0

## How close to the rock the camera may come, in the density's units.
@export_range(0.05, 1.5, 0.05) var camera_margin: float = 0.35

var _player: Node4D
var _recipe
var _rig: Node


func _ready() -> void:
	_recipe = CaveRock.new()
	_player = get_node_or_null(player_path) as Node4D
	var body := StaticBody4D.new()
	body.name = "Solid"
	add_child(body)
	# The floor: one box under the whole cave.
	var lo: Vector4 = CaveRock.LO
	var hi: Vector4 = CaveRock.HI
	_add_box(body, Vector4((lo.x + hi.x) * 0.5, -0.5, (lo.z + hi.z) * 0.5, (lo.w + hi.w) * 0.5),
		Vector4(hi.x - lo.x, 1.0, hi.z - lo.z, hi.w - lo.w))
	for box in _recipe.solid_boxes():
		_add_box(body, box[0], box[1])
	# The orbit camera's own ray only sees colliders, and these walls have none.
	_rig = get_node_or_null(str(player_path) + "/CameraRig")
	if _rig != null:
		_rig.set("clearance_provider", self)


func _exit_tree() -> void:
	if _rig != null and is_instance_valid(_rig) and _rig.get("clearance_provider") == self:
		_rig.set("clearance_provider", null)


## How far back along [param direction] from [param origin] the camera can sit before it is
## inside the rock: a march through the same density the walls were baked from.
func camera_clearance(origin: Vector4, direction: Vector4, wanted: float) -> float:
	var inv: Projection = global_basis.inverse()
	var o: Vector4 = inv * (origin - global_position)
	var d: Vector4 = inv * direction
	var step := 0.25
	var t := step
	while t <= wanted:
		var q: Vector4 = o + d * t
		# The rock, and the daylight: the tunnel runs on a little past the light, and a
		# camera back there sees the light's unlit back instead of the cave.
		if _recipe.air_density(q) < camera_margin or q.z > CaveRock.DAYLIGHT_Z - 0.3:
			return maxf(t - step, 0.4)
		t += step
	return wanted


func _add_box(body: StaticBody4D, centre: Vector4, size: Vector4) -> void:
	var shape := BoxShape4D.new()
	shape.size = size
	var holder := CollisionShape4D.new()
	holder.shape = shape
	holder.position = centre
	body.add_child(holder)


## Where to stand on arriving, in the world: the crossing reads this.
func arrival() -> Vector4:
	return global_position + global_basis * CaveRock.ARRIVE


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var here: Vector4 = global_basis.inverse() * (_player.global_position - global_position) + Vector4(0.0, test_height, 0.0, 0.0)
	var air: float = _recipe.air_density(here)
	if air >= wall_margin:
		return
	# Out along the gradient, by exactly the shortfall - a slide along the wall rather
	# than a bounce off it. Only in (x, z, w): height is the floor's business.
	var g := Vector4.ZERO
	var h := 0.1
	for axis in [0, 2, 3]:
		var e := Vector4.ZERO
		e[axis] = h
		g[axis] = (_recipe.air_density(here + e) - _recipe.air_density(here - e)) / (2.0 * h)
	var along: float = g.length()
	if along < 1e-5:
		return
	var push: Vector4 = g / along * ((wall_margin - air) / along)
	_player.global_position += global_basis * push
	if _player is CharacterBody4D:
		var body := _player as CharacterBody4D
		var n: Vector4 = global_basis * (g / along)
		var into: float = body.linear_velocity.dot(n)
		if into < 0.0:
			body.linear_velocity -= n * into
