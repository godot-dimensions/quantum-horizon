extends PenNpcTalk4D

## Mithra's half of the conversation: she stops searching to talk, opens on whichever beat
## of her small quest you have reached, and hands over a piece of azoth when she gets her
## pocket watch back.
##
## Reach, the shared catch key, the prompt over her head and freezing the player come from
## PenNpcTalk4D, which the keeper uses too. This file is only what makes her her.
##
## THE QUEST STATE IS THE INVENTORY, NOT A COPY OF IT. She asks pen_inventory_4d whether
## you are carrying `found_watch` rather than keeping her own flag, because the watch can be
## picked up by walking over it without her being involved at all. A second record of the
## same fact is a second thing to get out of step.
##
## SHE STOPS AND TURNS TO FACE YOU. A character who keeps pacing while delivering lines
## reads as broken rather than busy, and one who stops but keeps facing the fence reads as
## rude. Both are two lines here, and both are the difference between a person and a sign.

const WATCH: String = "found_watch"
const EGG: String = "found_egg"
const AZOTH: String = "found_azoth"
## The strange clock from the meadow's edge (10 Oct): she takes it and tells you about the hawk (U).
const CLOCK: String = "found_clock"

@export var searcher_path: NodePath
@export var inventory_path: NodePath
## Her old passing mutter. Cleared while a conversation is open, so she is not muttering
## at you and talking to you at the same time.
@export var mutter_path: NodePath

var _searcher: Node
var _inventory: Node
var _mutter: Label
var _hinted: bool = false
var _gave_watch: bool = false
var _gave_clock: bool = false
## Once she has fetched you a bird she has nothing left to offer, and says so.
var _gifted: bool = false
var _met: bool = false


func _configure() -> void:
	_searcher = get_node_or_null(searcher_path)
	_inventory = get_node_or_null(inventory_path)
	_mutter = get_node_or_null(mutter_path) as Label
	_talk.use_script(MithraScript.NODES, MithraScript.START)


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
		return MithraScript.START
	if _catcher != null and _catcher.get("carried") != null:
		return "greet_carrying"
	if _has(CLOCK) and not _gave_clock:
		return "greet_has_clock"
	if _gifted:
		return "greet_after_gift"
	if _gave_watch:
		return "greet_done"
	if _has(WATCH):
		return "greet_has_watch"
	if _hinted:
		return "greet_hinted"
	return "greet_looking"


func _on_effect(name: String) -> void:
	match name:
		"watch_hinted":
			_hinted = true
		"take_watch":
			_gave_watch = true
			# It is hers again, so it leaves your pockets. Leaving it on the belt after
			# handing it over is the sort of small lie that makes an inventory useless.
			if _inventory != null and _inventory.has_method("remove_item"):
				_inventory.call("remove_item", WATCH)
		"take_clock":
			_gave_clock = true
			if _inventory != null and _inventory.has_method("remove_item"):
				_inventory.call("remove_item", CLOCK)
		"give_nugget":
			# A piece of azoth rather than the golden egg she used to hand over. The egg is a
			# trinket you can also just find in the field; a nugget buys a trough off the
			# keeper, so thanking you with one is thanking you with something.
			if _inventory != null:
				_inventory.call("add_item", AZOTH)


func _has(item: String) -> bool:
	return _inventory != null and bool(_inventory.call("has_item", item))


func reset() -> void:
	_met = false
	_gave_clock = false
	_hinted = false
	_gave_watch = false
	_gifted = false
	if _talk != null:
		_talk.stop()
		_talk.reset()
	if _searcher != null:
		_searcher.set("halted", false)
	_set_player_moving(true)

## SHE starts this one. Every other conversation in the scene opens because the player
## walked up and pressed a key; this one opens because she has just crossed the field
## with a chicken and is standing in front of them holding it.
##
## IT GOES THROUGH THE SAME DOOR as a normal conversation - _before_begin does the camera
## staging, the walk-lock and the tag - so an unprompted conversation is framed exactly
## like a prompted one. Calling _talk.begin() on its own would have played the lines with
## the camera still behind the player's shoulder and the player free to walk away
## mid-sentence.
func begin_delivery() -> void:
	if _talk == null or _talk.is_running():
		return
	_before_begin()
	_talk.begin("delivery")


func gave_a_chicken() -> void:
	_gifted = true
