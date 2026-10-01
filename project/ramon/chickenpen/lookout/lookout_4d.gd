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
##   lookout_story_4d.gd      the beats, Wren's tips, the line on the HUD card
##   lookout_radio_4d.gd      Wren on the radio: subtitles that take no input
##   lookout_cutscene_4d.gd   the short camera moves: the approach, the owl
##   journal_card_4d.gd       the HUD card (UI/Journal); journal_book_4d.gd, the book (J)
##   owl_4d.gd                the ana owl, on its post at w +1.5
##   lookout_wren_4d.gd       Wren, with lookout_wren_talk_4d.gd and wren_script.gd
##   balloon_4d.gd            Wren's balloon and its ride, over the farm and out ana
##   ana_marsh_4d.gd          the marsh that is only there along W, at w +8
##   heron_4d.gd              the heron that fishes in it
##
## F at the ladder's foot climbs; J opens the journal anywhere.

const STATION := preload("res://ramon/chickenpen/lookout/lookout_station_4d.gd")
const SUBJECTS := preload("res://ramon/chickenpen/lookout/photo_subjects_4d.gd")
const JUDGE := preload("res://ramon/chickenpen/lookout/photo_judge_4d.gd")
const JOURNAL := preload("res://ramon/chickenpen/lookout/field_journal_4d.gd")
const SOUND := preload("res://ramon/chickenpen/lookout/lookout_sound_4d.gd")
const GROUND := preload("res://ramon/chickenpen/lookout/lookout_ground_4d.gd")
const STORY := preload("res://ramon/chickenpen/lookout/lookout_story_4d.gd")
const RADIO := preload("res://ramon/chickenpen/lookout/lookout_radio_4d.gd")
const CUTSCENE := preload("res://ramon/chickenpen/lookout/lookout_cutscene_4d.gd")
const BOOK := preload("res://ramon/chickenpen/lookout/journal_book_4d.gd")
const OWL := preload("res://ramon/chickenpen/lookout/owl_4d.gd")
const BALLOON := preload("res://ramon/chickenpen/lookout/balloon_4d.gd")
const MARSH := preload("res://ramon/chickenpen/lookout/ana_marsh_4d.gd")
const HERON := preload("res://ramon/chickenpen/lookout/heron_4d.gd")

@export var tower_path: NodePath = NodePath("../../World/Lookout")
@export var player_path: NodePath = NodePath("../../Player")
@export var camera_path: NodePath = NodePath("../../Player/CameraRig/Pitch/Camera4D")
@export var catcher_path: NodePath = NodePath("../../Player/Catcher")
## Where the journal is kept. Tests point it elsewhere so they never touch the real one.
@export var journal_path: String = "user://lookout_journal.cfg"
## How close to the ladder's foot F climbs, across the ground and through W.
@export_range(0.5, 4.0, 0.1) var ladder_reach: float = 1.6
@export_range(0.2, 4.0, 0.1) var ladder_reach_w: float = 1.2
@export var wren_path: NodePath = NodePath("../../World/Wren")
@export var wren_head_path: NodePath = NodePath("../../World/WrenHead")
## Where the balloon is moored, west of the tower.
@export var balloon_mooring: Vector4 = Vector4(-23.5, 0.0, -30.0, 0.0)
## The marsh's middle, out along W. Inside the pen's bounds (a 46 m sphere in x, z and w),
## so it can be walked to.
@export var marsh_at: Vector4 = Vector4(-26.0, 0.0, -24.0, 8.0)
## Which of the five thousand starlings is white. The pen's flock draws none unless told.
@export var white_starling: int = 2731

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
var story: Node
var radio: Control
var cutscene: Node
var book: Control
var owl: Node4D
var balloon: Node
var wren: Node4D
var wren_head: Node4D
var marsh: Node4D
var heron: Node4D

var _board: Node4D
var _board_tag: WorldTag4D
var _board_shown: String = ""
var _slow: float = 0.0
var _current_cam: Camera4D
var _camera_search_at: int = -100000

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
	story = STORY.new()
	story.name = "Story"
	add_child(story)
	story.call("setup", self)
	wren = get_node_or_null(wren_path) as Node4D
	wren_head = get_node_or_null(wren_head_path) as Node4D
	# Overlays, each on a canvas layer of its own: the radio over the viewfinder, the book
	# over both, the cutscene's bars over everything. Added after the station, so their
	# _input comes first (later nodes hear input first).
	radio = _overlay(RADIO, "Radio", 7) as Control
	radio.set("lookout", self)
	book = _overlay(BOOK, "Book", 8) as Control
	book.set("lookout", self)
	cutscene = CUTSCENE.new()
	cutscene.name = "Cutscene"
	cutscene.set("lookout", self)
	add_child(cutscene)
	_build_owl()
	_build_balloon()
	_build_marsh()
	_build_ladder_prompt()
	# The chickens are made in their manager's _ready and the hills' meshes are loaded by
	# then: collect the subjects and map the ground once everything is up.
	_late_setup.call_deferred()


func _late_setup() -> void:
	subjects.call("refresh")
	_register_own_subjects()
	ground = GROUND.build(room, 0.0, 3.0)
	judge.call("set_ground", ground)
	if wren != null and journal.call("flag", "met_wren"):
		wren.set("has_camera", false)
	# A journal already this far: the balloon is up by the tower.
	if balloon != null and bool(journal.call("flag", "balloon_said")) and bool(story.call("balloon_open")):
		balloon.call("set_ready", true, true)
	var flock: Node = room.get_node_or_null("World/Flock")
	if flock != null and white_starling >= 0:
		flock.set("white_bird", white_starling)


func _build_balloon() -> void:
	balloon = Node4D.new()
	balloon.name = "Balloon"
	balloon.set_script(BALLOON)
	balloon.set("lookout", self)
	# Placed before it enters the tree: it takes its mooring from where it starts.
	balloon.position = balloon_mooring
	room.get_node("World").add_child(balloon)
	_board = Node4D.new()
	_board.name = "BalloonBoard"
	room.get_node("World").add_child(_board)
	_board.position = balloon_mooring + Vector4(0.0, 1.6, 0.0, 0.0)
	_board_tag = WorldTag4D.new()
	_board_tag.name = "Prompt"
	if farm_camera != null:
		_board_tag.camera_path = farm_camera.get_path()
	_board_tag.anchor_path = _board.get_path()
	_board_tag.lift = 8.0
	_board.add_child(_board_tag)


func _build_marsh() -> void:
	marsh = Node4D.new()
	marsh.name = "AnaMarsh"
	marsh.set_script(MARSH)
	marsh.position = marsh_at
	room.get_node("World").add_child(marsh)
	heron = Node4D.new()
	heron.name = "AnaHeron"
	heron.set_script(HERON)
	heron.set("marsh_path", marsh.get_path())
	heron.set("player_path", player.get_path() if player != null else NodePath())
	heron.set("lookout_path", get_path())
	heron.position = marsh_at + marsh.call("fishing_spot")
	# Facing along the open water, its back to the reeds.
	heron.basis = Basis4D.from_zx(-PI * 0.5)
	room.get_node("World").add_child(heron)


func _overlay(script: Script, part: String, layer: int) -> Node:
	var canvas := CanvasLayer.new()
	canvas.name = part + "Layer"
	canvas.layer = layer
	add_child(canvas)
	var node: Control = Control.new()
	node.name = part
	node.set_script(script)
	canvas.add_child(node)
	return node


## The owl, on the ana post outside the north window.
func _build_owl() -> void:
	if tower == null:
		return
	owl = Node4D.new()
	owl.name = "AnaOwl"
	owl.set_script(OWL)
	owl.set("lookout_path", get_path())
	room.get_node("World").add_child(owl)
	owl.global_position = tower.call("ana_perch") + Vector4(0.0, 0.03, 0.0, 0.0)
	# Facing the cab it sits outside: its face to the window, its back to the field.
	owl.global_basis = Basis4D.from_zx(0.0)


func _register_own_subjects() -> void:
	if owl != null:
		var u: float = float(owl.get("size"))
		subjects.call("add", {"id": "owl", "page": "owl", "name": "The ana owl", "node": owl, "lift": 0.38 * u,
			"radius": 0.42 * u, "w_radius": 0.16 * u * float(owl.get("w_stretch")),
			"behave": func(_s: Dictionary) -> Array: return owl.call("behaviour")})
	if heron != null:
		var hu: float = float(heron.get("size"))
		subjects.call("add", {"id": "heron", "page": "heron", "name": "The heron", "node": heron, "lift": 0.0,
			"radius": 0.5 * hu, "w_radius": 0.12 * hu * float(heron.get("w_stretch")),
			"point": func(_s: Dictionary) -> Variant: return heron.call("centre") if heron.is_visible_in_tree() else null,
			"behave": func(_s: Dictionary) -> Array: return heron.call("behaviour")})
	if wren != null:
		subjects.call("add", {"id": "wren", "page": "folk", "name": "Wren", "node": wren, "lift": 0.85, "radius": 0.85,
			"w_radius": 0.24, "behave": _behave_wren})


func _behave_wren(_s: Dictionary) -> Array:
	if int(station.get("mode")) == 4:
		return [4, "Wren at her tower"]
	return [1, "Farm folk"]


## The camera drawing the picture now: the station's, a cutscene's, or the farm's.
##
## CACHED, AND THE KNOWN ONES FIRST. Searching the pen's whole tree for cameras is thousands
## of nodes; the balloon's burner asked every frame and it cost 2.5 ms at the spawn point and
## 15 in the basket. So: the one found last time if it is still current, then the cameras this
## subgame and the pen are known to use, and the full search only if none of them is.
func current_camera() -> Camera4D:
	if is_instance_valid(_current_cam) and _current_cam.is_inside_tree() and _current_cam.is_current():
		return _current_cam
	var known: Array = [station.get("camera") if station != null else null, cutscene.get("_cam") if cutscene != null else null,
		farm_camera, room.get_node_or_null("World/TalkCam")]
	for cam in known:
		if cam is Camera4D and is_instance_valid(cam) and (cam as Camera4D).is_inside_tree() and (cam as Camera4D).is_current():
			_current_cam = cam
			return cam
	var now: int = Time.get_ticks_msec()
	if now - _camera_search_at > 1000:
		_camera_search_at = now
		for cam in room.find_children("*", "Camera4D", true, false):
			if (cam as Camera4D).is_current():
				_current_cam = cam
				return cam
	return _current_cam if is_instance_valid(_current_cam) else farm_camera


func next_hint() -> String:
	return String(story.call("next_hint")) if story != null else ""


func story_busy() -> bool:
	return story != null and bool(story.call("busy"))


func on_journal_wiped() -> void:
	if wren != null:
		wren.set("has_camera", true)
	show_balloon(false)


func show_balloon(on: bool) -> void:
	if balloon != null:
		balloon.call("set_ready", on)


## The heron's payoff, the first good photo of it: it lifts off, slowly - the whole farm
## at a third of its speed for a couple of seconds - and the card lights up.
func on_heron_found() -> void:
	if heron == null:
		return
	heron.call("perform", "take_off")
	_slow = 2.6
	Engine.time_scale = 0.35
	var card: Node = room.get_node_or_null("UI/Journal")
	if card != null and card.has_method("glow"):
		card.call("glow")
	radio.call("say", ["Oh. Oh, look at it go.", "That's the one. That's the page I never had."])


func on_ride_started() -> void:
	story.call("on_ride_started")


func on_ride_ended() -> void:
	pass


## X, in the basket: Wren's whistle. What can hear it looks up - the heron stands tall,
## the owl turns, and the nearest starlings roll, which sends a wave through the flock.
func on_whistle() -> void:
	sound(&"whistle")
	var eye: Vector4 = balloon.call("eye") if balloon != null else Vector4.ZERO
	if heron != null:
		var d: Vector4 = heron.global_position - eye
		if Vector3(d.x, d.y, d.z).length() < 45.0 and absf(d.w) < 5.0:
			heron.call("hear")
	if owl != null and owl.global_position.distance_to(eye) < 40.0:
		owl.call("perform", "look")
	var flock: Node4D = room.get_node_or_null("World/Flock") as Node4D
	if flock != null and flock.is_visible_in_tree():
		var local: Vector4 = flock.global_basis.inverse() * (eye - flock.global_position)
		var positions: PackedVector4Array = flock.call("positions")
		var near: Array = []
		for i in positions.size():
			var dist: float = positions[i].distance_to(local)
			if dist < 30.0:
				near.append([dist, i])
		near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for k in mini(near.size(), 14):
			flock.call("startle", int(near[k][1]), 1.0 if k % 2 == 0 else -1.0)


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


func _near_ladder() -> bool:
	if _ladder == null or player == null or not player.is_visible_in_tree():
		return false
	var gap: Vector4 = _ladder.global_position - player.global_position
	return Vector2(gap.x, gap.z).length() <= ladder_reach and absf(gap.w) <= ladder_reach_w


## Whether F would climb right now: at the ladder's foot, with Wren's camera, hands free,
## nobody to talk to.
func can_climb() -> bool:
	if station == null or bool(station.call("busy")) or story_busy() or _ladder == null or player == null:
		return false
	if not player.is_inside_tree() or not player.is_visible_in_tree() or player.get("input_enabled") == false:
		return false
	if not _near_ladder():
		return false
	if wren != null and not bool(journal.call("flag", "met_wren")):
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


func can_board() -> bool:
	if balloon == null or not bool(balloon.get("ready_now")) or bool(balloon.get("riding")) or _board == null:
		return false
	if bool(station.call("busy")) or story_busy() or player == null or not player.is_visible_in_tree() or player.get("input_enabled") == false:
		return false
	if not bool(story.call("balloon_open")):
		return false
	var gap: Vector4 = _board.global_position - player.global_position
	return Vector2(gap.x, gap.z).length() <= 2.2 and absf(gap.w) <= 1.2


func _process(delta: float) -> void:
	if _slow > 0.0:
		# Real seconds, not scaled ones: the slow motion must end on time.
		_slow -= delta / maxf(Engine.time_scale, 0.01)
		if _slow <= 0.0:
			Engine.time_scale = 1.0
	if _board_tag != null:
		var board_text: String = ("%s  board the balloon" % _catch_key()) if can_board() else ""
		if board_text != _board_shown:
			_board_shown = board_text
			if board_text == "":
				_board_tag.clear()
			else:
				_board_tag.show_text(board_text)
	if _tag == null:
		return
	var text: String = ""
	if can_climb():
		text = "%s  climb the lookout" % _catch_key()
	elif _near_ladder() and not bool(journal.call("flag", "met_wren")) and not bool(station.call("busy")):
		text = "The camera is Wren's. Talk to her first"
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
	elif event.is_action_pressed(&"catch_target") and can_board():
		get_viewport().set_input_as_handled()
		balloon.call("board")


# --- What the station tells us -----------------------------------------------------------------

func on_cab_entered() -> void:
	sound(&"hatch")
	story.call("on_cab_entered")


func on_cab_left() -> void:
	pass


func on_ride_escape() -> void:
	if balloon != null:
		balloon.call("hurry")


func on_photo(photo: Dictionary) -> void:
	var best: Dictionary = photo.get("best", {})
	var verdict: String = String(judge.call("verdict", best))
	var result: Dictionary = journal.call("record", photo, verdict)
	var view: Control = station.get("view")
	if view != null:
		view.call("toast", result)
	if bool(result.get("new_page", false)):
		# A secret found: the pad and chimes, the subgame's one piece of music.
		var page: String = String(result.get("look", {}).get("page", ""))
		sound(&"secret" if page in ["owl", "white_starling", "heron"] else &"new_page")
	elif bool(result.get("new_slot", false)) or bool(result.get("better", false)):
		sound(&"page")
	story.call("on_photo", result)


func sound(id: StringName, amount: float = 1.0) -> void:
	if sounds != null:
		sounds.call("play", id, amount)


func sound_loop(id: StringName, on: bool, db: float = 0.0) -> void:
	if sounds != null:
		sounds.call("loop", id, on, db)


func _catch_key() -> String:
	if not InputMap.has_action(&"catch_target"):
		return "F"
	for event in InputMap.action_get_events(&"catch_target"):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "F"
