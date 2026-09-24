@tool
extends Node4D

## Gold orbs buried in the mining rock, revealed by digging them out.
##
## NOTHING IN VoxelMining IS TOUCHED. The rock is still the block that ships in
## project/ramon/VoxelMining/, carving exactly as it did; the gold is a handful of small
## spheres sitting in the same space, hidden until the voxels around them are gone. That
## keeps the destructible-terrain code free of a gameplay reward it has no business
## knowing about, and it means the orbs can be moved, recoloured or removed without
## regenerating anything.
##
## REVEALED BY THE SWING, NOT BY WATCHING THE FIELD. The pickaxe says where it bit and how
## wide the bite was, and an orb inside that sphere comes to light. Polling the voxel field
## instead would mean reaching into the block's private state every frame for an answer it
## already broadcasts once per hit.
##
## THEY SIT IN THE ROCK'S OWN FRAME, so moving or resizing the rock carries them with it -
## the alternative is a set of world coordinates that quietly end up hanging in mid-air
## the first time somebody drags the boulder.

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export var rock_path: NodePath
@export var pickaxe_path: NodePath
@export var player_path: NodePath
@export var inventory_path: NodePath
## What the belt calls a nugget. Matches a row in pen_inventory_4d's ITEMS.
@export var effect_name: String = "found_gold"

@export_group("The seam")
## Pieces lying within reach of a swing made from the slice you start on. These teach the
## mechanic: hit rock, find gold.
@export_range(0, 12, 1) var shallow_count: int = 3
## And pieces lying too far through W for ANY swing from that slice to touch, however you
## stand. These are the point.
##
## A carve is a SPHERE about a metre across, so a piece further through W than that radius
## cannot be reached from the default slice no matter where in the field you put your
## feet - the geometry says so, not a difficulty curve. To get one you have to move
## through W or turn the slice, and then dig again from a cross-section that did not exist
## a moment ago. It is the one thing in this project that a three-dimensional game cannot
## do, and until now nothing asked the player to do it.
@export_range(0, 12, 1) var deep_count: int = 3
@export var gold: Color = Color(0.98, 0.78, 0.22): set = _set_gold
@export_range(0.05, 1.0, 0.01) var orb_size: float = 0.40: set = _set_size
## How deep in they sit, as a fraction of the rock's half-width. Under 1 so none of them
## is poking out of the surface before a pick has touched it.
##
## THIS IS A SHELL, NOT A BOX. Scattering them uniformly through the volume sounds like a
## seam and plays like an empty rock: most of a cube is nowhere near its surface, so the
## average piece ended up about two metres in, and mining the whole bottom face of the
## thing turned up nothing. They now sit at a RADIUS - a shell just under the skin - so
## ordinary digging on any face runs into one within a swing or two.
@export_range(0.1, 0.95, 0.05) var seam_spread: float = 0.78
## How much the shell wobbles, so they are not all at an identical depth.
@export_range(0.0, 0.4, 0.01) var seam_jitter: float = 0.12
## How far beyond a swing's own reach a deep piece must sit. Slack, so the rule holds
## even at the widest the carve is ever tuned to.
@export_range(0.1, 2.0, 0.05) var deep_margin: float = 0.45
@export var seed_value: int = 4242

@export_group("Collecting")
## How close the swing has to land, on top of the carve's own radius.
## How much wider than the bite a swing counts as having uncovered. Generous, because a
## seam you have to hit within half a metre of is a seam most people never find - and
## there is nothing on screen telling you it is in there.
@export_range(0.0, 2.0, 0.05) var reveal_slack: float = 0.70
## How near you have to get. The nugget is knocked into the opening you just made, so this
## wants to be "step forward after swinging" rather than "stand on the exact spot" - at
## 1.4 you could back off half a pace after the swing and leave it behind without ever
## knowing it was there. Pulled back from 2.3 after a playtest - findable, but you still
## have to go to it. Tightened twice by playtest: 1.4 was too mean, 2.3 too kind.
@export_range(0.5, 4.0, 0.1) var pick_up_within: float = 1.65

var _rock: Node4D
var _pickaxe: Node
var _player: Node4D
var _inventory: Node
var _orbs: Array[Node4D] = []
var _found: Array[bool] = []


func _set_gold(v: Color) -> void: gold = v; _later()
func _set_size(v: float) -> void: orb_size = v; _later()


func _ready() -> void:
	_rock = get_node_or_null(rock_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	_inventory = get_node_or_null(inventory_path)
	_pickaxe = get_node_or_null(pickaxe_path)
	rebuild()
	if _pickaxe != null and _pickaxe.has_signal("mined"):
		if not _pickaxe.is_connected("mined", _on_mined):
			_pickaxe.connect("mined", _on_mined)


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_orbs.clear()
	_found.clear()
	if _rock == null:
		_rock = get_node_or_null(rock_path) as Node4D
	if _rock == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# The rock's solid half-width, from its own exported grid rather than a guess.
	var grid: float = float(_rock.get("grid_size")) * float(_rock.get("cell_size"))
	var reach: float = grid * 0.5 * float(_rock.get("box_fill_fraction")) * seam_spread
	# How far a single swing can reach through W, which is what divides the two kinds.
	var bite: float = float(_rock.get("mining_radius_meters"))
	for i in shallow_count + deep_count:
		var deep: bool = i >= shallow_count
		var off_slice: float = 0.0
		if deep:
			# Clear of the bite by a margin, and still inside the rock's own W extent -
			# a piece buried outside the material is not buried, it is missing.
			off_slice = rng.randf_range(bite + deep_margin, maxf(reach, bite + deep_margin + 0.1))
			if rng.randf() < 0.5:
				off_slice = -off_slice
		else:
			off_slice = rng.randf_range(-bite * 0.5, bite * 0.5)
		# A DIRECTION AND A DEPTH, rather than three independent numbers. Three uniform
		# coordinates put most pieces near the middle of the rock; a unit direction times
		# a depth puts every one of them the same distance under whichever face you happen
		# to be standing at, which is what makes them findable by digging rather than by
		# knowing where they are.
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn())
		if dir.length() < 0.001:
			dir = Vector3(1.0, 0.0, 0.0)
		dir = dir.normalized()
		var depth: float = reach * (1.0 + rng.randf_range(-seam_jitter, seam_jitter))
		var at := Vector4(dir.x * depth, dir.y * depth, dir.z * depth, off_slice)
		var orb := MeshInstance4D.new()
		orb.name = "Nugget%d" % i
		var mesh := OrthoplexTetraMesh4D.new()
		# Round, because a gold BOX in a rock reads as a crate somebody buried.
		mesh.size = Vector4.ONE * orb_size
		orb.mesh = mesh
		var material := TetraMaterial4D.new()
		material.albedo_color = gold
		orb.material_override = material
		add_child(orb)
		orb.position = at
		orb.visible = false
		if Engine.is_editor_hint() and get_tree() != null \
				and get_tree().edited_scene_root != null:
			orb.owner = get_tree().edited_scene_root
		_orbs.append(orb)
		_found.append(false)


## A swing landed. Anything inside the bite is now in daylight.
func _on_mined(at: Vector4, radius: float) -> void:
	for i in _orbs.size():
		if not is_instance_valid(_orbs[i]) or _orbs[i].visible:
			continue
		if (_orbs[i].global_position - at).length() <= radius + reveal_slack:
			_orbs[i].visible = true
			# IT COMES OUT WITH THE SWING. Left where it was buried, a revealed nugget sits
			# about two metres inside a six-metre rock and you have to tunnel in and stand
			# in the hole to get within pick_up_within of it - which nobody did, because
			# nothing tells you there is anything in there. Knocking it loose into the
			# opening you just made is what a pickaxe hitting a seam should do anyway.
			#
			# ITS W IS ITS OWN. Only the three dimensions you can walk in are moved, so the
			# deep half of the seam still sits a slice away and still has to be turned onto
			# - which is the one part of this that is about the fourth dimension.
			_orbs[i].global_position = Vector4(at.x, at.y, at.z,
				_orbs[i].global_position.w)


## Walking into a revealed one pockets it. Kept here rather than in the collector, which
## owns the two authored pickups and counts them towards a different thing.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _player == null:
		return
	for i in _orbs.size():
		if _found[i] or not is_instance_valid(_orbs[i]) or not _orbs[i].visible:
			continue
		if (_orbs[i].global_position - _player.global_position).length() > pick_up_within:
			continue
		_found[i] = true
		_orbs[i].visible = false
		if _inventory != null and _inventory.has_method("add_item"):
			_inventory.call("add_item", effect_name)


## How many of the deep ones are still in there - the ones that need the slice turned.
func deep_left() -> int:
	var n: int = 0
	for i in _orbs.size():
		if i >= shallow_count and not _found[i]:
			n += 1
	return n


## How many are still in the rock, for anything that wants to say so.
func left_in_the_rock() -> int:
	var n: int = 0
	for i in _orbs.size():
		if not _found[i]:
			n += 1
	return n


## And how many have been dug out, which is the half a professor would brag about.
func dug_out() -> int:
	return _orbs.size() - left_in_the_rock()
