extends Node4D

## Spawns and owns the twelve chickens, and holds the progress count.
##
## ONE SOURCE SCENE, TWELVE PERSONALITIES (item 15). Every chicken is an instance of
## chicken.tscn with a different id and seed. Nothing is hand-edited per bird, so a change
## to the chicken reaches all twelve, and no two of them move in step.
##
## THE PLACEMENTS ARE A TEACHING ORDER, NOT A SCATTER (item 59). The brief asks for a
## progression, and the table below is it:
##
##   1-3   in or near the starting slice, in plain sight - these teach catching
##   4-6   ordinary XYZ exploration at w = 0 - these teach searching
##   7-10  meaningfully offset in W - these teach the locator, closest first (item 60)
##   11-12 W offset combined with distance - one new variable at a time, so these come
##         last (item 61)
##
## The first W chicken sits at w = 0.9 deliberately: item 60 wants the first off-slice
## bird to need only a small, unmistakable adjustment, so the player learns what the
## locator means before being asked to hunt.

const CHICKEN_SCENE := preload("res://ramon/chickenpen/chicken.tscn")

## x, z, w, and the wander radius allowed at that spot. Y comes from the ground.
const PLACEMENTS := [
	# In or near the starting slice.
	[3.4, 2.6, 0.0, 2.4],
	[-4.2, 3.4, 0.0, 2.4],
	[1.8, 6.2, 0.0, 2.0],
	# Ordinary exploration, still in the starting slice.
	[9.5, -3.2, 0.0, 3.0],
	[-10.0, -5.5, 0.0, 3.0],
	[7.2, 10.5, 0.0, 2.6],
	# THE W BIRDS RING THE PEN, six of them on a circle 9.5 out from its centre, at
	# bearings 30 degrees apart from the player's line of approach. Before this they were
	# scattered through the field on the player's side of the pen, which meant the whole
	# hunt happened in one direction and the pen was only ever something you walked back
	# to. Around it, every trip home is from somewhere else.
	#
	# THE TEACHING ORDER SURVIVES IT, which is why the bearings are paired rather than
	# evenly spread: the two nearest the player's start take the first and gentlest W
	# offsets, the two abreast of the pen take the next, and the two behind it - the
	# longest walk in the scene - take the largest. Nearest first, then W, then distance,
	# exactly as before.
	#
	# NONE OF THEM SPAWN IN THE PEN. The fence runs x -5 to 5 and z -15.5 to -6.5; the
	# closest of these sits 3.7 clear of it, and the widest wander radius here is 2.6, so
	# even a bird that drifts the whole way stays out. An earlier bird was authored at
	# z = -5.4 and spawned inside the fence, which counted it on frame one.
	#
	# The first one still sits near where the player starts ON PURPOSE: standing beside a
	# chicken you cannot see is a sharper first lesson than a distant one. It is 4.9 away,
	# not on top of the spawn at (0, -1.5) - hence 30 degrees rather than a bearing that
	# would have put a bird in the player's face.
	[4.75, -2.77, 0.9, 2.0],
	[-4.75, -2.77, -1.3, 2.2],
	[9.5, -11.0, 1.9, 2.2],
	[-9.5, -11.0, -2.1, 2.2],
	# Behind the pen: W plus the longest walk.
	[4.75, -19.23, 1.6, 2.6],
	[-4.75, -19.23, -2.5, 2.6],
]

@export var chicken_count: int = 12

## Height the chickens are placed at. The ground sits at 0 in this scene.
@export var ground_y: float = 0.0

## Scale applied to every chicken. They are authored much larger than the chibi player.
@export var chicken_scale: float = 0.25

signal progress_changed(returned_count: int, total: int)
signal chicken_returned(agent: Node)

var agents: Array = []

var _player: Node4D


func _ready() -> void:
	spawn_all()


func bind_player(player: Node4D) -> void:
	_player = player
	for agent in agents:
		agent.call("bind_player", player)


## Builds the flock. Safe to call again: it clears first, which is what item 73's restart
## needs.
func spawn_all() -> void:
	for child in get_children():
		child.queue_free()
	agents.clear()
	var wanted: int = mini(chicken_count, PLACEMENTS.size())
	if chicken_count > PLACEMENTS.size():
		push_warning("ChickenManager: asked for %d chickens but only %d placements are authored - the extra ones would have to be scattered, which item 59 explicitly does not want." % [chicken_count, PLACEMENTS.size()])
	for i in wanted:
		var place: Array = PLACEMENTS[i]
		var chicken: Node4D = CHICKEN_SCENE.instantiate()
		chicken.name = "Chicken%02d" % (i + 1)
		add_child(chicken)
		chicken.position = Vector4(place[0], ground_y, place[1], place[2])
		chicken.basis = Projection(
			Vector4(chicken_scale, 0, 0, 0), Vector4(0, chicken_scale, 0, 0),
			Vector4(0, 0, chicken_scale, 0), Vector4(0, 0, 0, chicken_scale))
		var agent: Node = chicken.get_node_or_null("Agent")
		if agent == null:
			push_warning("ChickenManager: %s has no Agent node - it will never react or be catchable." % chicken.name)
			continue
		agent.set("chicken_id", i + 1)
		# Distinct, reproducible personalities. A fixed multiplier rather than randomness
		# so a given chicken behaves the same way every run, which makes a bug in one of
		# them repeatable.
		agent.set("variation_seed", (i + 1) * 7919 + 13)
		agent.set("home_position", chicken.position)
		agent.set("wander_radius", place[3])
		agents.append(agent)
	if _player != null:
		bind_player(_player)
	emit_signal("progress_changed", returned_count(), agents.size())


func returned_count() -> int:
	var n := 0
	for agent in agents:
		if bool(agent.get("returned")):
			n += 1
	return n


## Chickens the locator may point at (items 56, 57): loose, not carried, not returned.
func locator_candidates() -> Array:
	var out: Array = []
	for agent in agents:
		if bool(agent.call("can_be_caught")):
			out.append(agent)
	return out


func note_returned(agent: Node) -> void:
	emit_signal("chicken_returned", agent)
	emit_signal("progress_changed", returned_count(), agents.size())


## Item 73: put everything back without an editor restart.
func reset() -> void:
	spawn_all()
