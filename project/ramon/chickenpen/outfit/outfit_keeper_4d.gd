extends Node

## KEEPS THE OUTFIT ON THE PLAYER IN EVERY SCENE. One of these sits on the window's root, beside the
## running scene rather than in it (the way the laptop trip's node does, scripts/pen_laptop_trip_4d.gd),
## so it outlives a scene being parked, swapped or reloaded. It watches everything that enters the tree,
## and gives every player figure a wearer (outfit_wearer_4d.gd): the pen's player when the pen loads,
## the cinema's own player when the theatre opens beside the pen, and the pen's again when you come back
## from the menu. The cave and the far room use the pen's player, so they need nothing.
##
## ONLY THE PLAYER, AND ONLY THE PEN'S. A player figure here is a node called Avatar, on the pen's own
## block_avatar_4d.gd, under a body called Player on the pen's walker. The NPCs share the avatar script
## but not that body, so Trym, the professor and the rest are never dressed; the labs carry copies of
## the scripts under other paths, so their players are left as their own scenes make them.
##
## A RUNTIME AUTOLOAD, without the project setting. The fitting circle adds it the first time the pen
## loads (outfit_circle_4d.gd), so nothing shared (project.godot) had to change. Until then there is
## nothing to dress: the outfit is chosen in the pen.

const Wearer := preload("res://ramon/chickenpen/outfit/outfit_wearer_4d.gd")
const AVATAR_SCRIPT := "res://ramon/chickenpen/scripts/block_avatar_4d.gd"
const WALKER_SCRIPT := "res://ramon/chickenpen/scripts/block_walker_character_4d.gd"
const NAME := &"OutfitKeeper"

var _wearers: Array[Node] = []


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("Avatar", "", true, false):
		_consider(node)


func _on_node_added(node: Node) -> void:
	if node.name == &"Avatar":
		# Deferred: the figure has only just entered, and its body may still be being built round it.
		_consider.call_deferred(node)


## The wearer dressing [param figure], if it has one yet.
func wearer_for(figure: Node) -> Node:
	for wearer in _wearers:
		if is_instance_valid(wearer) and wearer.get("avatar") == figure:
			return wearer
	return null


func _consider(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or not is_player_figure(node):
		return
	# Forget the wearers whose figure has gone (the cinema's, once you are home). A plain loop: a
	# typed filter() choked on the freed ones and could not hand back an Array[Node] (8 Oct, coming
	# back from the menu, when the pen re-enters the tree and its player is seen again).
	var alive: Array[Node] = []
	for wearer in _wearers:
		if is_instance_valid(wearer):
			alive.append(wearer)
	_wearers = alive
	if wearer_for(node) != null:
		return
	var wearer: Node = Wearer.new()
	wearer.name = "Wearer"
	wearer.set("avatar", node)
	add_child(wearer, true)
	_wearers.append(wearer)


static func is_player_figure(node: Node) -> bool:
	if node.name != &"Avatar" or not _on_script(node, AVATAR_SCRIPT):
		return false
	var body: Node = node.get_parent()
	return body != null and body.name == &"Player" and body is CharacterBody4D and _on_script(body, WALKER_SCRIPT)


static func _on_script(node: Node, path: String) -> bool:
	var script: Script = node.get_script() as Script
	return script != null and script.resource_path == path
