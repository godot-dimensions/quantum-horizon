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
@export_range(1, 12, 1) var count: int = 5
@export var gold: Color = Color(0.98, 0.78, 0.22): set = _set_gold
@export_range(0.05, 1.0, 0.01) var orb_size: float = 0.30: set = _set_size
## How deep in they sit, as a fraction of the rock's half-width. Under 1 so none of them
## is poking out of the surface before a pick has touched it.
@export_range(0.1, 0.95, 0.05) var seam_spread: float = 0.62
@export var seed_value: int = 4242

@export_group("Collecting")
## How close the swing has to land, on top of the carve's own radius.
@export_range(0.0, 2.0, 0.05) var reveal_slack: float = 0.35
@export_range(0.5, 4.0, 0.1) var pick_up_within: float = 1.4

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
	for i in count:
		var at := Vector4(
			rng.randf_range(-reach, reach), rng.randf_range(-reach, reach),
			rng.randf_range(-reach, reach), rng.randf_range(-reach * 0.4, reach * 0.4))
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
