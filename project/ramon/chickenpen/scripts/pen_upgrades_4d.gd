extends Node4D

## What the azoth is FOR. The keeper takes a piece and builds something onto his pen.
##
## ONE NUGGET, ONE TROUGH, and the rock holds six. That is the loop: dig, carry, spend,
## go back and dig another - and the field gets a little kinder each time you do.
##
## It is one nugget rather than a price because the belt refuses duplicates: it carries a
## single Azoth token, not a count. Teaching it to stack would change a widget four other
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
## A trough has gone up, and where. Nike listens for this and goes to eat at it; the pig
## knowing about food is his business, not this node's, so it announces and forgets.
signal feeder_raised(at: Vector4)

@export var inventory_path: NodePath
@export var manager_path: NodePath
@export var pen_path: NodePath
## The belt's name for a nugget, which is what one of these costs.
@export var cost_effect: String = "found_azoth"

@export_group("Feeder")
## Loose birds nearer the pen than this are drawn in. Beyond it they stay where they are:
## an upgrade that reached the whole field would empty the map from a standing start.
@export_range(2.0, 30.0, 0.5) var draw_radius: float = 11.0
## Where the gathered birds end up, measured out from the pen's centre. Outside the fence
## on purpose - see the header.
@export_range(2.0, 12.0, 0.5) var gather_radius: float = 6.0
## How tightly they mill about once gathered. Small, and it has to stay smaller than the
## stand-off below or they wander back into the trough they were moved out of.
@export_range(0.1, 6.0, 0.1) var gather_wander: float = 0.5
## Where the ring of feeding birds sits, measured from the trough's centre. Half the
## trough's length plus a bird, and half its width plus a bird - see the gather loop.
@export_range(0.4, 4.0, 0.05) var rim_long: float = 1.2
@export_range(0.3, 4.0, 0.05) var rim_wide: float = 0.75
## The man who sells them. The first trough goes next to him so you can see what you
## bought - see the header on _where_needed.
@export var keeper_path: NodePath = NodePath("../../World/Keeper")
## Between the keeper and the first trough, and between each trough and the next. Wide
## enough that two of them read as two, given each is 1.6 long.
@export_range(1.0, 8.0, 0.1) var beside_gap: float = 2.6
## How many the rock can pay for. Six, because that is how many nuggets are in it.
@export_range(1, 8, 1) var max_feeders: int = 6
@export var feeder_colour := Color(0.42, 0.29, 0.18, 1.0)
## The feed. The one saturated yellow on the farm - see the header on _raise_feeder.
@export var grain_colour := Color(0.94, 0.78, 0.22, 1.0)

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
## azoth is not actually there, so a dialogue that offers the choice cannot get out of step
## with the belt that pays for it.
func buy(which: String) -> bool:
	if which != "feeder" or all_built() or not can_pay():
		return false
	_inventory.call("remove_item", cost_effect)
	_raise_feeder(_where_needed())
	built.emit(which)
	return true


## WHERE THE TROUGH GOES. Next to the keeper for the first one, and next to the last one
## after that.
##
## IT USED TO BE CLEVER AND THAT WAS THE PROBLEM. The spot was worked out from the average
## bearing of the loose birds, so the trough landed wherever the flock happened to be
## giving you trouble - which is behind the pen more often than not, out of sight of the
## man who just sold it to you. You paid a nugget and nothing visibly happened. A purchase
## has to show you what you bought, and the only place guaranteed to be on screen at the
## moment of buying is where you are standing: in front of the keeper.
##
## So the first one goes beside him, and every one after it goes beside the last, walking
## out in a line. You can see the row grow, and it is obvious that another nugget means
## another trough. The birds come to them wherever they are - the gather loop works off
## each trough's own position and does not care - so nothing is lost by being clear.
func _where_needed() -> Vector4:
	var centre: Vector4 = _pen.global_position if _pen != null else Vector4.ZERO
	var keeper: Node4D = get_node_or_null(keeper_path) as Node4D
	if keeper == null:
		# No keeper to stand next to, so the old ring is the fallback rather than dropping
		# it on the pen's own centre post.
		var ring: Vector2 = Vector2(0.0, 1.0).rotated(
			TAU * float(_feeders.size()) / float(max_feeders)) * gather_radius
		return centre + Vector4(ring.x, 0.0, ring.y, 0.0)

	# OUTWARD FROM THE PEN, THEN SIDEWAYS. The first step is along the line from the pen's
	# centre out through the keeper, which puts the trough on the far side of him from the
	# fence - and that matters, because he stands close enough to the corner that a step
	# along his OWN sideways axis drops it straight onto the rails.
	var him := Vector2(keeper.global_position.x - centre.x, keeper.global_position.z - centre.z)
	if him.length() < 0.01:
		him = Vector2(0.0, 1.0)
	var out: Vector2 = him.normalized()
	# The row then runs at right angles to that, so it stays the same distance from the
	# pen all the way along instead of marching off across the field.
	var along := Vector2(out.y, -out.x)
	var base := Vector2(keeper.global_position.x, keeper.global_position.z)
	var at: Vector2 = base + out * beside_gap + along * beside_gap * float(_feeders.size())
	return Vector4(at.x, 0.0, at.y, keeper.global_position.w)


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
		# AT THE RIM, NOT IN IT. Each bird used to be sent to the trough's CENTRE with two
		# metres of wander around it, so a gathered flock milled about inside the timber
		# and walked through the thing it was supposed to be eating out of. Nothing here
		# does collision - the birds are kinematic and the trough is scenery - so the fix
		# is to stop asking them to stand where the trough is.
		#
		# Each bird gets its OWN fixed place round the edge, taken from its instance id.
		# Fixed, because a bearing worked out from where the bird currently is chases it:
		# as it walks the target rotates, and it circles the trough forever without
		# arriving. A stable angle per bird also spreads them into a ring rather than a
		# heap, which is what birds at a feeder look like.
		#
		# The ring is an ELLIPSE, matching the trough's footprint - 1.6 long by 0.6 wide -
		# plus a bird's reach. A circle wide enough to clear the ends would leave the ones
		# at the sides standing half a metre out in the grass.
		var angle: float = float(int(agent.get_instance_id()) % 977) / 977.0 * TAU
		var stand := Vector2(cos(angle) * rim_long, sin(angle) * rim_wide)
		# Its own w is kept: a trough is food, not a fourth-dimensional winch. A bird a
		# slice away comes to stand beside it in ITS slice, and you still have to rotate
		# to reach it.
		agent.set("home_position", Vector4(best.x + stand.x, 0.0, best.z + stand.y,
			float(agent.get("home_position").w)))
		if float(agent.get("wander_radius")) > gather_wander:
			agent.set("wander_radius", gather_wander)


## A TROUGH, NOT A BROWN BOX. It used to be one BoxTetraMesh4D, 1.9 by 0.44 by 0.7 by 1.6,
## in a single shade of brown - which from ten metres away, which is where you buy it from,
## was a brick lying in a field. It cost a nugget and looked like nothing.
##
## So it is built as the thing it is: a floor, two long sides, two ends, and grain heaped
## in the channel between them. Seven boxes instead of one, and the shape now reads at a
## distance because the eye has a rim and a filled middle to read rather than a silhouette.
##
## THE YELLOW IS THE POINT. Nothing else on the farm is that colour - the fence, the shed,
## the pen and the ground are all browns and greens - so a trough announces itself across
## the field and you can see which ones you have already paid for without counting.
##
## SLIGHTLY SMALLER THAN IT WAS, as asked: 1.6 long against 1.9. It reads as a piece of
## kit a person carried out rather than a piece of the scenery.
##
## AND IT IS AS WIDE IN W AS IT IS IN Z. Every piece spans 1.35 along the fourth axis, so
## rotating a slice does not take the sides off it and leave the grain hanging in the air.
## The grain itself is deliberately NARROWER in w than the timber, which is what makes it
## look contained: you see the box around it from every slice you can stand in.
func _raise_feeder(at: Vector4) -> void:
	_feeders.append(at)
	var trough := Node4D.new()
	trough.name = "Feeder%d" % _feeders.size()
	add_child(trough)

	var timber := TetraMaterial4D.new()
	timber.albedo_color = feeder_colour
	var grain := TetraMaterial4D.new()
	grain.albedo_color = grain_colour

	var w: float = 1.35
	var thick: float = 0.09
	# floor, the two long sides, the two ends
	_plank(trough, timber, Vector4(1.60, thick, 0.60, w), Vector4(0.0, thick * 0.5, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		_plank(trough, timber, Vector4(1.60, 0.31, thick, w),
			Vector4(0.0, 0.245, side * 0.255, 0.0))
		_plank(trough, timber, Vector4(thick, 0.31, 0.42, w),
			Vector4(side * 0.755, 0.245, 0.0, 0.0))
	# the feed: a bed filling the channel, and three heaps standing proud of it, which is
	# what stops it reading as a yellow lid.
	_plank(trough, grain, Vector4(1.36, 0.10, 0.36, w * 0.8), Vector4(0.0, 0.14, 0.0, 0.0))
	for i in 3:
		var along: float = (float(i) - 1.0) * 0.44
		_plank(trough, grain, Vector4(0.26, 0.09, 0.24, w * 0.6),
			Vector4(along, 0.235, (0.05 if i == 1 else -0.04), 0.0))

	# Placed in the pen's frame, since this node hangs off the pen. On the ground now
	# rather than lifted half its own height, because the pieces measure up from zero.
	var local: Vector4 = at - (_pen.global_position if _pen != null else Vector4.ZERO)
	trough.position = Vector4(local.x, 0.0, local.z, local.w)
	feeder_raised.emit(at)


func _plank(parent: Node4D, material: TetraMaterial4D, size: Vector4, at: Vector4) -> void:
	var piece := MeshInstance4D.new()
	var mesh := BoxTetraMesh4D.new()
	mesh.size = size
	piece.mesh = mesh
	piece.material_override = material
	parent.add_child(piece)
	piece.position = at


func reset() -> void:
	_feeders.clear()
	for child in get_children():
		child.queue_free()
