extends Node4D

## A laptop you can use: stand at it, F, and you are at the prototypes menu - Menu2, with its
## toggle to the Frontier Map - until Escape brings you back (pen_laptop_trip_4d.gd). One of
## these at each laptop in the game: Trym's desk in the pen, the research table in the cave,
## the stand by the cinema's podium (Ramon, 29 Sept: "laptops will make you enter the menu2
## ... this menu should appear for all laptops in all scenes").
##
## A LAPTOP NEVER TAKES F FROM A PERSON (Ramon, 29 Sept: "when people talk it should not
## interfere with the laptops. make sure npcs are outside F radius, only then laptops can be
## activated"). Every conversation in the game (PenNpcTalk4D, group "npc_talk") is asked
## whether it could start right now; if any could, F is theirs and this offers nothing. Nor
## while a chicken is in reach or in your arms, nor mid-conversation. So a laptop someone is
## sitting at - Trym's, while he is at his desk - is his until he leaves it.
##
## SELF-CONTAINED, because the three live in three places: the pen's own systems are asleep
## while you are in the cinema, which has its own player. So each knows its own player and
## camera and carries its own prompt.

const Trip := preload("res://ramon/chickenpen/scripts/pen_laptop_trip_4d.gd")

@export var player_path: NodePath
@export var camera_path: NodePath
@export var catcher_path: NodePath
## How close, across the floor and through W.
@export_range(0.3, 4.0, 0.1) var reach: float = 1.4
@export_range(0.2, 4.0, 0.1) var reach_w: float = 1.0
@export var prompt: String = "use laptop"
@export_file("*.tscn") var menu_path: String = "res://ramon/Menu2.tscn"

var _player: Node4D
var _camera: Camera4D
var _catcher: Node
var _tag: WorldTag4D
var _shown := ""


func _ready() -> void:
	add_to_group(&"laptop")
	_player = get_node_or_null(player_path) as Node4D
	_camera = get_node_or_null(camera_path) as Camera4D
	_catcher = get_node_or_null(catcher_path)
	_tag = WorldTag4D.new()
	_tag.name = "Prompt"
	if _camera != null:
		_tag.camera_path = _camera.get_path()
	_tag.anchor_path = get_path()
	_tag.lift = 8.0
	add_child(_tag)


func _process(_delta: float) -> void:
	if _tag == null:
		return
	var text: String = ("%s  %s" % [_key(), prompt]) if usable() else ""
	if text == _shown:
		return
	_shown = text
	if text == "":
		_tag.clear()
	else:
		_tag.show_text(text)


## Whether F would open the menu right now - for the prompt, the key and the tests.
func usable() -> bool:
	if _player == null or not _player.is_inside_tree() or not is_visible_in_tree():
		return false
	if _player.get("input_enabled") == false:
		return false
	var gap: Vector4 = global_position - _player.global_position
	if Vector2(gap.x, gap.z).length() > reach or absf(gap.w) > reach_w:
		return false
	if _catcher != null and (_catcher.get("carried") != null or _catcher.get("_candidate") != null):
		return false
	for talker in get_tree().get_nodes_in_group(&"npc_talk"):
		if not talker.is_inside_tree() or not talker.can_process():
			continue
		var talk: Node = talker.get("_talk")
		if talk != null and bool(talk.call("is_running")):
			return false
		if bool(talker.call("_can_talk")):
			return false
	return true


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"catch_target") or not usable():
		return
	get_viewport().set_input_as_handled()
	var trip: Node = Trip.new()
	get_tree().root.add_child(trip)
	trip.call("go", menu_path, _camera)


## Read from the InputMap, as every prompt here is, so a rebind stays true.
func _key() -> String:
	if not InputMap.has_action(&"catch_target"):
		return "?"
	for event in InputMap.action_get_events(&"catch_target"):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"
