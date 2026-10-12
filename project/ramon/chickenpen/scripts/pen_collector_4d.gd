extends Node

## Walk into a pickup and it is yours - if you are in its slice.
##
## THE SLICE RULE IS THE WHOLE POINT. These sit off the starting slice, so reaching one
## means doing the thing the gauntlet teaches. Collecting on plain 4D distance would let a
## player brush past one they could not see and collect it by accident, which teaches the
## opposite of what the placement is for. Measured along the slice frame, the same axis
## the catch and the locator use.

const Confetti := preload("res://ramon/chickenpen/discovery/pen_confetti_4d.gd")
const Toast := preload("res://ramon/chickenpen/discovery/pen_discovery_toast.gd")

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
		# Only pickups (the egg's confetti burst lands elsewhere, but anything else under here is not one).
		if item == null or not item.visible or not ("kind" in item):
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
	var kind: int = int(item.get("kind"))
	item.visible = false
	item.set_process(false)
	# A bag of azoth (kind 2) is azoth, so the keeper can take it: the same item as a mined piece.
	if kind == 2:
		var worth: int = int(item.get("bag_worth"))
		if _inventory != null:
			for i in worth:
				_inventory.call("add_item", "found_azoth")
		if _readout != null:
			_readout.text = "Found: a bag of azoth, %d pieces. Somebody hid this." % worth
			_left = message_seconds
		return
	if kind == 4:
		if _inventory != null:
			_inventory.call("add_item", "found_clock")
		if _readout != null:
			_readout.text = "Found: a strange clock. Its hands point every way at once."
			_left = message_seconds
		Toast.say(self, "A strange clock!", "Hey, this looks interesting. Maybe Mithra would like it.", Color(0.62, 0.78, 0.74))
		return
	var id: String = "found_watch" if kind == 0 else ("found_egg_white" if kind == 3 else "found_egg")
	if _inventory != null:
		_inventory.call("add_item", id)
	if _readout != null:
		_readout.text = "Found: %s" % {"found_watch": "a pocket watch, still ticking", "found_egg": "a golden egg", "found_egg_white": "an egg"}[id]
		_left = message_seconds
	# The eggs (10 Oct, Ramon's walkthrough item 14: "Provide a small, satisfying collection response"): a pop of
	# confetti where it lay and a short card saying how many of the pen's three you have.
	if id != "found_watch":
		var burst: Node4D = Confetti.new()
		_player.get_parent().add_child(burst)
		burst.call("throw", item.global_position)
		var golden: bool = id == "found_egg"
		Toast.say(self, "A golden egg!" if golden else "An egg!", _egg_tally(), Color(0.95, 0.75, 0.30) if golden else Color(0.88, 0.86, 0.80))


## "2 of the pen's 3 eggs": the pen's eggs are the pickups named PenEgg*.
func _egg_tally() -> String:
	var all: int = 0
	var got: int = 0
	for node in _pickups.get_children():
		if String(node.name).begins_with("PenEgg"):
			all += 1
			if not (node as Node4D).visible:
				got += 1
	return "%d of the pen's %d eggs" % [got, all] if all > 0 else ""


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
