extends Node

## Walk into a pickup and it is yours - if you are in its slice.
##
## THE SLICE RULE IS THE WHOLE POINT. These sit off the starting slice, so reaching one
## means doing the thing the gauntlet teaches. Collecting on plain 4D distance would let a
## player brush past one they could not see and collect it by accident, which teaches the
## opposite of what the placement is for. Measured along the slice frame, the same axis
## the catch and the locator use.

@export var player_path: NodePath
@export var slice_frame_path: NodePath
@export var inventory_path: NodePath
@export var readout_path: NodePath
@export var pickups_path: NodePath

@export_range(0.3, 4.0, 0.1) var reach: float = 1.1
## How far off your slice a pickup can be and still be collected. Tight, like the catch.
@export_range(0.05, 1.0, 0.05) var slice_tolerance: float = 0.35
@export_range(0.0, 8.0, 0.5) var message_seconds: float = 3.0

var _player: Node4D
var _frame: Node4D
var _inventory: Node
var _readout: Label
var _pickups: Node
var _left: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_frame = get_node_or_null(slice_frame_path) as Node4D
	_inventory = get_node_or_null(inventory_path)
	_readout = get_node_or_null(readout_path) as Label
	_pickups = get_node_or_null(pickups_path)
	if _player == null or _inventory == null or _pickups == null:
		push_warning("PenCollector: player, inventory or pickups missing - nothing can be found (item 82).")
	if _readout != null:
		_readout.text = ""


func _process(delta: float) -> void:
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
		if _left <= 0.0 and _readout != null:
			_readout.text = ""
	if _player == null or _pickups == null:
		return
	var slice: Projection = _frame.global_basis if _frame != null else _player.global_basis
	for node in _pickups.get_children():
		var item: Node4D = node as Node4D
		if item == null or not item.visible:
			continue
		var rel: Vector4 = item.global_position - _player.global_position
		if absf(rel.dot(slice.w)) > slice_tolerance:
			continue
		if Vector2(rel.dot(slice.x), rel.dot(slice.z)).length() > reach:
			continue
		if absf(rel.dot(slice.y)) > 2.0:
			continue
		_take(item)


func _take(item: Node4D) -> void:
	var id: String = "found_coin" if int(item.get("kind")) == 0 else "found_egg"
	item.visible = false
	item.set_process(false)
	if _inventory != null:
		_inventory.call("add_item", id)
	if _readout != null:
		_readout.text = "Found: %s" % ("an ADA coin" if id == "found_coin" else "a golden egg")
		_left = message_seconds


## Item 73: put them all back where they were.
func reset() -> void:
	if _pickups == null:
		return
	for node in _pickups.get_children():
		var item: Node4D = node as Node4D
		if item == null:
			continue
		item.visible = true
		item.set_process(true)
