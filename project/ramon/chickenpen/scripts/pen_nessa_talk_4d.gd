extends PenNpcTalk4D

## Nessa's half of the conversation: she stops searching to talk, opens on whichever beat
## of her small quest you have reached, and hands over a golden egg when she gets her coin
## back.
##
## Reach, the shared catch key, the prompt over her head and freezing the player come from
## PenNpcTalk4D, which the keeper uses too. This file is only what makes her her.
##
## THE QUEST STATE IS THE INVENTORY, NOT A COPY OF IT. She asks pen_inventory_4d whether
## you are carrying `found_coin` rather than keeping her own flag, because the coin can be
## picked up by walking over it without her being involved at all. A second record of the
## same fact is a second thing to get out of step.
##
## SHE STOPS AND TURNS TO FACE YOU. A character who keeps pacing while delivering lines
## reads as broken rather than busy, and one who stops but keeps facing the fence reads as
## rude. Both are two lines here, and both are the difference between a person and a sign.

const COIN: String = "found_coin"
const EGG: String = "found_egg"

@export var searcher_path: NodePath
@export var inventory_path: NodePath
## Her old passing mutter. Cleared while a conversation is open, so she is not muttering
## at you and talking to you at the same time.
@export var mutter_path: NodePath

var _searcher: Node
var _inventory: Node
var _mutter: Label
var _hinted: bool = false
var _gave_coin: bool = false
var _met: bool = false


func _configure() -> void:
	_searcher = get_node_or_null(searcher_path)
	_inventory = get_node_or_null(inventory_path)
	_mutter = get_node_or_null(mutter_path) as Label
	_talk.use_script(NessaScript.NODES, NessaScript.START)


func _began() -> void:
	if _searcher != null:
		_searcher.set("halted", true)
		if _player != null and _searcher.has_method("face_towards"):
			_searcher.call("face_towards", _player.global_position)
	if _mutter != null:
		_mutter.text = ""


func _ended() -> void:
	if _searcher != null:
		_searcher.set("halted", false)


func _entry_node() -> String:
	if not _met:
		_met = true
		return NessaScript.START
	if _catcher != null and _catcher.get("carried") != null:
		return "greet_carrying"
	if _gave_coin:
		return "greet_done"
	if _has(COIN):
		return "greet_has_coin"
	if _hinted:
		return "greet_hinted"
	return "greet_looking"


func _on_effect(name: String) -> void:
	match name:
		"coin_hinted":
			_hinted = true
		"take_coin":
			_gave_coin = true
			# It is hers again, so it leaves your pockets. Leaving it on the belt after
			# handing it over is the sort of small lie that makes an inventory useless.
			if _inventory != null and _inventory.has_method("remove_item"):
				_inventory.call("remove_item", COIN)
		"give_egg":
			if _inventory != null:
				_inventory.call("add_item", EGG)


func _has(item: String) -> bool:
	return _inventory != null and bool(_inventory.call("has_item", item))


func reset() -> void:
	_met = false
	_hinted = false
	_gave_coin = false
	if _talk != null:
		_talk.stop()
		_talk.reset()
	if _searcher != null:
		_searcher.set("halted", false)
	_set_player_moving(true)
