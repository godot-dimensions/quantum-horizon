extends Node

## THE MENU'S SOUNDS IN THE LABS (Ramon, 11 Oct: "add the menu sounds from frontier map, as interactive properties
## to the creature lab ... including the subtle background soundtrack", then "you have the go ahead to add the
## interactive sounds to all the labs. In the outside areas with the sea please don't add the background audio").
##
## The Frontier Map's MenuAudio (menu_audio.gd), unchanged: its four cues on each lab's moments and its music bed
## under the indoor rooms.
##   click  - something touched: a pick, a step, a page, a reset, a palette or dark-mode switch.
##   select - something opened: a showcase or presentation started, a door to another room.
##   swipe  - a panel slid over: an info panel, a desk, a close look, in or out.
##   error  - asked for what is not there.
##
## MIXED AS THE MAP MIXED IT, ON THE PROJECT'S BUSES ("mix it, maybe like the frontier map did it"): MenuAudio's
## own levels are the map's balance and stay as they are - the bed at -26 dB (about -40 LUFS from a -14 LUFS track),
## select -9, click -14, swipe -19, error at full level for the one cue that must not be missed - routed as the
## world routes its sounds (pen_sfx_4d.gd: its bed -26 dB on Music, its cues -6 to -20 dB on SFX), so the bus volumes
## and the master's limiter treat them like every other sound. The bed's level is the menu's Tab "Music" slider
## (Menu/style/menu_tuning.cfg).
##
## ONE NODE AT THE ROOT, "LabSounds", so the bed carries on through a lab's doors instead of starting again. Each
## room says it is one, in its _ready: LabSounds.room(self, true) indoors, LabSounds.room(self, false) out by the sea
## (the Voxel Lab's open world, the Aquatic Lab's sea), where the bed fades out and picks up again on the way back
## in. Once no lab room is on screen the node frees itself, bed and all. Cues: LabSounds.cue(get_tree(), "click").
##
## NO class_name: the labs preload it.

const TUNING := "res://ramon/Menu/style/menu_tuning.cfg"
## The menu's music slider's range (menu_final.gd MUSIC_DB_LOW / HIGH); 0.667 is the map's -26 dB.
const MUSIC_DB_LOW := -46.0
const MUSIC_DB_HIGH := -16.0
## Seconds with no lab room on screen before it goes (a change of room passes through no scene at all).
const GRACE := 1.5

var _audio: MenuAudio
var _away: float = 0.0
## Scene path of each room that has said it is one, and whether it wants the bed.
var _rooms: Dictionary = {}
var _bed_on: bool = true


## The one at the root, made the first time a room asks.
static func ensure(tree: SceneTree) -> Node:
	var found: Node = tree.root.get_node_or_null(^"LabSounds")
	if found != null:
		return found
	var made: Node = (load("res://ramon/Menu/scripts/menu_lab_sounds.gd") as GDScript).new()
	made.name = "LabSounds"
	tree.root.add_child.call_deferred(made)
	return made


## A lab room opening: its scene is one of the labs', with the bed (indoors) or without (out by the sea).
static func room(scene_root: Node, bed: bool) -> void:
	if Engine.is_editor_hint() or not scene_root.is_inside_tree() or scene_root.scene_file_path.is_empty():
		return
	var node: Node = ensure(scene_root.get_tree())
	(node.get("_rooms") as Dictionary)[scene_root.scene_file_path] = bed


## Plays one of the map's cues ("click", "select", "swipe", "error").
static func cue(tree: SceneTree, which: String) -> void:
	var node: Node = ensure(tree)
	if node.is_inside_tree():
		node.call("play", which)
	else:
		node.call_deferred("play", which)


func _ready() -> void:
	_audio = MenuAudio.new()
	add_child(_audio)
	_route(&"Music", ["_ambience"])
	_route(&"SFX", ["_click", "_select", "_error", "_swipe"])
	var cfg := ConfigFile.new()
	var level: float = 0.667
	if cfg.load(TUNING) == OK:
		level = float(cfg.get_value("sound", "music", level))
	_audio.set_ambience_db(lerpf(MUSIC_DB_LOW, MUSIC_DB_HIGH, clampf(level, 0.0, 1.0)))


func _route(bus: StringName, players: Array) -> void:
	if AudioServer.get_bus_index(bus) < 0:
		return
	for player_name in players:
		var p: Variant = _audio.get(String(player_name))
		if p is AudioStreamPlayer:
			(p as AudioStreamPlayer).bus = bus


func play(which: String) -> void:
	if _audio != null and is_instance_valid(_audio) and _audio.has_method(which):
		_audio.call(which)


func _process(delta: float) -> void:
	var here: Node = get_tree().current_scene
	if here != null and _rooms.has(here.scene_file_path):
		_away = 0.0
		var want: bool = bool(_rooms[here.scene_file_path])
		if want != _bed_on and _audio != null:
			_bed_on = want
			_audio.pause_ambience(not want, 0.8)
		return
	_away += delta
	if _away > GRACE:
		queue_free()
