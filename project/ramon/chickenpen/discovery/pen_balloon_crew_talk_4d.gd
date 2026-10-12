extends PenNpcTalk4D

## Tamsin's side of a conversation, both of her (Ramon, 10 Oct, item 20: "Both NPC instances should share the same
## underlying interaction logic where appropriate. The campsite version introduces the discovery; the balloon version
## handles payment and boarding."). As the camp guide's (scripts/pen_camp_guide_talk_4d.gd): PenNpcTalk4D owns the
## reach, F, the prompt and the staging.
##
## role "fire": at her fire by the stake, in the farm's slice (discovery/balloon_crew_script.gd): the hidden balloon
## and its price, a hint if asked, then what to say once it is found and once you have flown.
## role "ride": her twin by the basket, at the balloon's W (discovery/balloon_ride_script.gd): with 2 azoth she offers
## the ride; "pay" takes the 2 azoth (only if you have them and have not paid already, so it can never charge twice),
## sets the balloon's one-ride ticket (lookout/balloon_4d.gd ticket), and the ride starts when the box closes.

const CrewScript := preload("res://ramon/chickenpen/discovery/balloon_crew_script.gd")
const RideScript := preload("res://ramon/chickenpen/discovery/balloon_ride_script.gd")
const Balloon := preload("res://ramon/chickenpen/lookout/balloon_4d.gd")

@export_enum("fire", "ride") var role: String = "fire"
@export var inventory_path: NodePath = ^"../../UI/Inventory"
@export var lookout_path: NodePath = ^"../Lookout"
## What the ride costs, and in what.
@export var price: int = 2
@export var currency: String = "found_azoth"

## This session: Tamsin at the fire has been met; a ride has been flown.
static var met: bool = false
static var flown: bool = false

var _board_due: bool = false


func _configure() -> void:
	if role == "ride":
		_talk.use_script(RideScript.NODES, RideScript.START)
	else:
		_talk.use_script(CrewScript.NODES, CrewScript.START)


func _entry_node() -> String:
	if role == "ride":
		if Balloon.ticket:
			return "ready"
		return "offer" if _carrying() >= price else "short"
	if flown:
		return "flown"
	if Balloon.found:
		return "found"
	if not met:
		met = true
		return CrewScript.START
	return "again"


func _carrying() -> int:
	var inv: Node = get_node_or_null(inventory_path)
	return int(inv.call("count_of", currency)) if inv != null else 0


func _balloon() -> Node:
	var lookout: Node = get_node_or_null(lookout_path)
	return lookout.get("balloon") if lookout != null else null


## Not while the balloon is up (her twin stays by the sand; the ride is away). And her twin only once your slice is
## aligned with the balloon's W (Ramon, 10 Oct, item 43: "Only allow the balloon NPC interaction when the player is
## properly aligned with its W-slice"): V does that when most of the balloon shows.
func _can_talk() -> bool:
	var b: Node = _balloon()
	if b != null and bool(b.get("riding")):
		return false
	if role == "ride" and b != null and _rig is Node4D and _player != null:
		# Aligned: the slice flat (no turn into W) and you within 30 cm of the balloon's W (V puts you exactly there;
		# stepping there with E and Q counts too).
		var flat: bool = GroundBasis4D.tilt((_rig as Node4D).basis) < 0.05
		if not flat or absf(_player.global_position.w - (b as Node4D).global_position.w) > 0.3:
			return false
	return super()


func _on_effect(effect_name: String) -> void:
	if effect_name == "pay":
		if Balloon.ticket:
			_board_due = true
			return
		if _carrying() < price:
			return
		var inv: Node = get_node_or_null(inventory_path)
		for i in price:
			inv.call("remove_item", currency)
		Balloon.ticket = true
		_board_due = true
	elif effect_name == "board":
		_board_due = Balloon.ticket


func _ended() -> void:
	if not _board_due:
		return
	_board_due = false
	var b: Node = _balloon()
	if b != null and Balloon.ticket:
		b.call("board")
		if not b.is_connected("ride_finished", _on_flown):
			b.connect("ride_finished", _on_flown)


func _on_flown() -> void:
	flown = true


## Ctrl+R: a new visitor.
func reset() -> void:
	met = false
	flown = false
	_board_due = false
