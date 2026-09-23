extends Node4D

## What the gold is FOR. The keeper takes a nugget and builds something onto his pen.
##
## ONE NUGGET, ONE TROUGH, and the rock holds six. That is the loop: dig, carry, spend,
## go back and dig another - and the field gets a little kinder each time you do.
##
## It is one nugget rather than a price because the belt refuses duplicates: it carries a
## single Gold token, not a count. Teaching it to stack would change a widget four other
## things share, and a trip per nugget turns out to read better than a running total
## anyway. Each one is its own errand.
##
## THE KEEPER CHOOSES WHERE, and he puts it where the birds are thickest. A row of
## identical troughs at authored angles would be a menu; one that appears where you have
## been struggling is a man watching his own field. When nothing is loose he falls back to
## the bearing furthest from the troughs already up, so the ring fills in rather than
## doubling up in one place.
##
## THE FEEDER DOES NOT PUSH CHICKENS. Every agent already wanders around a home_position
## inside a wander_radius, so the feeder simply moves where a nearby bird THINKS home is.
## No steering code, no second opinion about who owns a chicken's movement, and a bird
## that drifts in does it at its own pace looking like a bird rather than a magnet.
##
## AND THEY GATHER OUTSIDE THE FENCE, deliberately. Pulling birds all the way in would
## play the game for you - the loop is catch and throw, and a trough is meant to remove
## the WALKING, not the catching. They collect at arm's length from the pen and wait to be
## picked up.

signal built(which: String)

@export var inventory_path: NodePath
@export var manager_path: NodePath
@export var pen_path: NodePath
## The belt's name for a nugget, which is what one of these costs.
@export var cost_effect: String = "found_gold"

@export_group("Feeder")
## Loose birds nearer the pen than this are drawn in. Beyond it they stay where they are:
## an upgrade that reached the whole field would empty the map from a standing start.
@export_range(2.0, 30.0, 0.5) var draw_radius: float = 11.0
## Where the gathered birds end up, measured out from the pen's centre. Outside the fence
## on purpose - see the header.
@export_range(2.0, 12.0, 0.5) var gather_radius: float = 6.0
## How tightly they mill about once gathered.
@export_range(0.5, 6.0, 0.1) var gather_wander: float = 2.0
## How many the rock can pay for. Six, because that is how many nuggets are in it.
@export_range(1, 8, 1) var max_feeders: int = 6
@export var feeder_colour := Color(0.42, 0.29, 0.18, 1.0)

var _inventory: Node
var _manager: Node
var _pen: Node4D
var _feeders: Array[Vector4] = []


func _ready() -> void:
	_inventory = get_node_or_null(inventory_path)
	_manager = get_node_or_null(manager_path)
	_pen = get_node_or_null(pen_path) as Node4D
	if _inventory == null or _manager == null or _pen == null:
		push_warning("%s: inventory, manager or pen missing - nothing can be built." % name)


func feeder_count() -> int:
	return _feeders.size()


func all_built() -> bool:
	return _feeders.size() >= max_feeders


func can_pay() -> bool:
	return _inventory != null and bool(_inventory.call("has_item", cost_effect))


## Takes the nugget and puts the thing up. Returns false rather than half-building if the
## gold is not actually there, so a dialogue that offers the choice cannot get out of step
## with the belt that pays for it.
func buy(which: String) -> bool:
	if which != "feeder" or all_built() or not can_pay():
		return false
	_inventory.call("remove_item", cost_effect)
	_raise_feeder(_where_needed())
	built.emit(which)
	return true


## The bearing the next trough goes on: the average direction of the loose birds, so it
## lands among whichever ones are giving you trouble. Averaging vectors rather than
## angles, because the mean of 170 and -170 degrees is 0 and that is the wrong side of
## the pen entirely.
func _where_needed() -> Vector4:
	var centre: Vector4 = _pen.global_position if _pen != null else Vector4.ZERO
	var sum := Vector2.ZERO
	if _manager != null:
		for agent in _manager.get("agents"):
			if not is_instance_valid(agent):
				continue
			var bird: Node4D = agent.get_parent() as Node4D
			if bird == null:
				continue
			var gap: Vector4 = bird.global_position - centre
			var flat := Vector2(gap.x, gap.z)
			if flat.length() > gather_radius * 1.2:
				sum += flat.normalized()
	if sum.length() < 0.01:
		# Nothing loose worth chasing, so fill the ring instead of stacking them up.
		sum = Vector2(0.0, 1.0).rotated(TAU * float(_feeders.size()) / float(max_feeders))
	var want: Vector2 = sum.normalized() * gather_radius
	return centre + Vector4(want.x, 0.0, want.y, 0.0)


func _process(_delta: float) -> void:
	if _feeders.is_empty() or _manager == null:
		return
	for agent in _manager.get("agents"):
		if not is_instance_valid(agent):
			continue
		var bird: Node4D = agent.get_parent() as Node4D
		if bird == null:
			continue
		# The NEAREST trough claims it. With several up, a bird between two of them would
		# otherwise be told two different places to live and jitter between them.
		var best: Vector4 = Vector4.ZERO
		var best_gap: float = draw_radius
		for spot in _feeders:
			var gap: Vector4 = bird.global_position - spot
			var flat: float = Vector2(gap.x, gap.z).length()
			if flat < best_gap:
				best_gap = flat
				best = spot
		if best_gap >= draw_radius:
			continue
		# Its own w is kept: a trough is food, not a fourth-dimensional winch. A bird a
		# slice away comes to stand beside it in ITS slice, and you still have to rotate
		# to reach it.
		agent.set("home_position", Vector4(best.x, 0.0, best.z,
			float(agent.get("home_position").w)))
		if float(agent.get("wander_radius")) > gather_wander:
			agent.set("wander_radius", gather_wander)


func _raise_feeder(at: Vector4) -> void:
	_feeders.append(at)
	var trough := MeshInstance4D.new()
	trough.name = "Feeder%d" % _feeders.size()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(1.9, 0.44, 0.7, 1.6)
	trough.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = feeder_colour
	trough.material_override = material
	add_child(trough)
	# Placed in the pen's frame, since this node hangs off the pen.
	var local: Vector4 = at - (_pen.global_position if _pen != null else Vector4.ZERO)
	trough.position = Vector4(local.x, 0.22, local.z, local.w)


func reset() -> void:
	_feeders.clear()
	for child in get_children():
		child.queue_free()
