extends PenNpcTalk4D

## The chicken keeper's half of the conversation: which script he speaks from, which
## greeting he opens with, and what his gauntlet switches on.
##
## Everything else - reach, the shared catch key, the prompt over his head, freezing the
## player - is in PenNpcTalk4D, which the girl by the fence uses too.
##
## THE LOCATOR IS OFF UNTIL HE HANDS IT OVER. It is a gauntlet he gives you, so the game
## should not open with it already on your wrist. Turn `gate_locator` off to get the old
## behaviour back when it gets in the way of testing.

@export var manager_path: NodePath
## What the gold buys. Given one, walking up with a nugget opens his builder instead of
## his usual greeting.
@export var upgrades_path: NodePath
## What the gauntlet switches on. Hidden at the start, shown when he hands it over.
@export var locator_ui_paths: Array[NodePath] = []
@export var gate_locator: bool = true

var _manager: Node
var _upgrades: Node
var _has_gauntlet: bool = false
var _met: bool = false


func _configure() -> void:
	_manager = get_node_or_null(manager_path)
	_upgrades = get_node_or_null(upgrades_path)
	_talk.use_script(KeeperScript.NODES, KeeperScript.START, Callable(KeeperScript, "fill"))
	_show_locator(not gate_locator)


func _before_begin() -> void:
	_talk.returned = _returned()
	_talk.total = _total()


## The scripted meeting once, then whatever state you turn up in - which is what makes him
## a second readout of the count as well as a character.
func _entry_node() -> String:
	# Gold in hand and a job left to do beats anything else he might say.
	if _upgrades != null and bool(_upgrades.call("can_pay")) \
			and not bool(_upgrades.call("all_built")):
		return "greet_gold"
	if not _met:
		_met = true
		return KeeperScript.START
	if _catcher != null and _catcher.get("carried") != null:
		return "greet_carrying"
	if gate_locator and not _has_gauntlet:
		return "greet_no_gauntlet"
	var home: int = _returned()
	var all: int = _total()
	if all > 0 and home >= all:
		return "greet_done"
	if home == 0:
		return "greet_none"
	if home >= all - 2:
		return "greet_nearly"
	return "greet_some"


func _on_effect(name: String) -> void:
	match name:
		"give_gauntlet":
			_has_gauntlet = true
		"withhold_gauntlet":
			_has_gauntlet = false
		"build_feeder":
			_build("feeder")
		"build_beacon":
			_build("beacon")
	_talk.set_flag("gauntlet", _has_gauntlet)
	if gate_locator:
		_show_locator(_has_gauntlet)


## The dialogue has already promised it, so a refusal here would leave him describing a
## trough that is not there. buy() only fails if the gold has gone missing between the
## greeting and the choice, which the entry check makes very unlikely and which is worth
## a warning rather than a silent nothing.
func _build(which: String) -> void:
	if _upgrades == null:
		return
	if not bool(_upgrades.call("buy", which)):
		push_warning("%s: keeper promised a %s and could not pay for it." % [name, which])


func _show_locator(on: bool) -> void:
	for path in locator_ui_paths:
		var node: CanvasItem = get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = on


func _returned() -> int:
	return int(_manager.call("returned_count")) if _manager != null else 0


func _total() -> int:
	if _manager == null:
		return 12
	var agents: Array = _manager.get("agents") as Array
	return agents.size() if agents != null else 12


## Item 73: a restart should give you the first meeting again.
func reset() -> void:
	_met = false
	_has_gauntlet = false
	if _talk != null:
		_talk.stop()
		_talk.reset()
	_show_locator(not gate_locator)
	_set_player_moving(true)
