extends Node

## The Lookout: a photography subgame at the edge of the pen's field (follow_up/lookout_plan.md).
##
## Wren keeps a fire-lookout tower and a field journal of everything that lives on the farm,
## "and some things that live next to it, along W". She hands you her camera. From the cab
## nothing sees you and nothing blocks you; the camera's focus ring slides your slice along W,
## so focusing is finding a thing in W.
##
## THIS NODE OWNS THE GAME and nothing in the pen knows it is here: it sits in the inherited
## scene chickenpen_lookout.tscn, finds the pen's nodes by path and leaves them as they are.
## The pieces, each its own script in this folder:
##
##   lookout_tower_4d.gd      the tower (World/Lookout), built from boxes
##   lookout_station_4d.gd    the climb, the cab, the camera in your hands
##   lookout_viewfinder_4d.gd what you see through it, the W-meter
##   photo_subjects_4d.gd     who can be photographed and what they are doing
##   photo_judge_4d.gd        judging a photo from the game's state
##   field_journal_4d.gd      the book: pages, four behaviours each, the best photo of each
##   lookout_sound_4d.gd      the shutter, the winder, the rungs, the radio
##
## F at the ladder's foot climbs; J opens the journal anywhere.

const STATION := preload("res://ramon/chickenpen/lookout/lookout_station_4d.gd")
const SUBJECTS := preload("res://ramon/chickenpen/lookout/photo_subjects_4d.gd")
const JUDGE := preload("res://ramon/chickenpen/lookout/photo_judge_4d.gd")
const JOURNAL := preload("res://ramon/chickenpen/lookout/field_journal_4d.gd")
const SOUND := preload("res://ramon/chickenpen/lookout/lookout_sound_4d.gd")
const GROUND := preload("res://ramon/chickenpen/lookout/lookout_ground_4d.gd")

@export var tower_path: NodePath = NodePath("../../World/Lookout")
@export var player_path: NodePath = NodePath("../../Player")
@export var camera_path: NodePath = NodePath("../../Player/CameraRig/Pitch/Camera4D")
@export var catcher_path: NodePath = NodePath("../../Player/Catcher")
## Where the journal is kept. Tests point it elsewhere so they never touch the real one.
@export var journal_path: String = "user://lookout_journal.cfg"
## How close to the ladder's foot F climbs, across the ground and through W.
@export_range(0.5, 4.0, 0.1) var ladder_reach: float = 1.6
@export_range(0.2, 4.0, 0.1) var ladder_reach_w: float = 1.2

var room: Node
var tower: Node4D
var player: Node4D
var farm_camera: Camera4D
var catcher: Node
var subjects: Node
var judge: Node
var journal: Node
var station: Node
var sounds: Node
var ground: RefCounted

var _ladder: Node4D
var _tag: WorldTag4D
var _shown: String = ""


func _ready() -> void:
	room = get_node("../..")
	tower = get_node_or_null(tower_path) as Node4D
	player = get_node_or_null(player_path) as Node4D
	farm_camera = get_node_or_null(camera_path) as Camera4D
	catcher = get_node_or_null(catcher_path)
	journal = JOURNAL.new()
	journal.name = "Journal"
	journal.set("save_path", journal_path)
	journal.set("photo_folder", journal_path.get_basename() + "_photos")
	add_child(journal)
	subjects = SUBJECTS.new()
	subjects.name = "Subjects"
	add_child(subjects)
	subjects.call("setup", self)
	judge = JUDGE.new()
	judge.name = "Judge"
	add_child(judge)
	judge.call("setup", self)
	sounds = SOUND.new()
	sounds.name = "Sound"
	add_child(sounds)
	station = STATION.new()
	station.name = "Station"
	add_child(station)
	station.call("setup", self)
	_build_ladder_prompt()
	# The chickens are made in their manager's _ready and the hills' meshes are loaded by
	# then: collect the subjects and map the ground once everything is up.
	_late_setup.call_deferred()


func _late_setup() -> void:
	subjects.call("refresh")
	ground = GROUND.build(room, 0.0, 3.0)
	judge.call("set_ground", ground)


func _build_ladder_prompt() -> void:
	if tower == null:
		return
	_ladder = Node4D.new()
	_ladder.name = "LookoutLadder"
	room.get_node("World").add_child(_ladder)
	_ladder.global_position = tower.call("ladder_foot") + Vector4(0.0, 1.2, 0.0, 0.0)
	_tag = WorldTag4D.new()
	_tag.name = "Prompt"
	if farm_camera != null:
		_tag.camera_path = farm_camera.get_path()
	_tag.anchor_path = _ladder.get_path()
	_tag.lift = 8.0
	_ladder.add_child(_tag)


## Whether F would climb right now: at the ladder's foot, hands free, nobody to talk to.
func can_climb() -> bool:
	if station == null or bool(station.call("busy")) or _ladder == null or player == null:
		return false
	if not player.is_inside_tree() or not player.is_visible_in_tree() or player.get("input_enabled") == false:
		return false
	var gap: Vector4 = _ladder.global_position - player.global_position
	if Vector2(gap.x, gap.z).length() > ladder_reach or absf(gap.w) > ladder_reach_w:
		return false
	if catcher != null and (catcher.get("carried") != null or catcher.get("_candidate") != null):
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


func _process(_delta: float) -> void:
	if _tag == null:
		return
	var text: String = ("%s  climb the lookout" % _catch_key()) if can_climb() else ""
	if text != _shown:
		_shown = text
		if text == "":
			_tag.clear()
		else:
			_tag.show_text(text)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"catch_target") and can_climb():
		get_viewport().set_input_as_handled()
		station.call("climb")


# --- What the station tells us -----------------------------------------------------------------

func on_cab_entered() -> void:
	sound(&"hatch")


func on_cab_left() -> void:
	pass


func on_ride_escape() -> void:
	pass


func on_photo(photo: Dictionary) -> void:
	var best: Dictionary = photo.get("best", {})
	var verdict: String = String(judge.call("verdict", best))
	var result: Dictionary = journal.call("record", photo, verdict)
	var view: Control = station.get("view")
	if view != null:
		view.call("toast", result)
	if bool(result.get("new_page", false)):
		sound(&"new_page")
	elif bool(result.get("new_slot", false)) or bool(result.get("better", false)):
		sound(&"page")


func sound(id: StringName, amount: float = 1.0) -> void:
	if sounds != null:
		sounds.call("play", id, amount)


func _catch_key() -> String:
	if not InputMap.has_action(&"catch_target"):
		return "F"
	for event in InputMap.action_get_events(&"catch_target"):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "F"
