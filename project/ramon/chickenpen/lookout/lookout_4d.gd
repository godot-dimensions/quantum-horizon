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
##   owl_4d.gd                the ana owl, on a twig of a dead tree at w +1.5 (lookout_tree_4d.gd)
##   lookout_wren_4d.gd       Wren, with lookout_wren_talk_4d.gd and wren_script.gd
##   balloon_4d.gd            Wren's balloon and its ride, over the farm and out ana
##   ana_marsh_4d.gd          the marsh that is only there along W, at w +8
##   heron_4d.gd              the heron that fishes in it
##
## F at the ladder's foot climbs (and at the deck's ladder gap, climbs down); Z raises the
## camera anywhere; J opens the journal anywhere; B takes you up in the balloon once it is up.

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
const TREE := preload("res://ramon/chickenpen/lookout/lookout_tree_4d.gd")
const HAWK := preload("res://ramon/chickenpen/lookout/hawk_flight_4d.gd")
const DEV := preload("res://ramon/chickenpen/lookout/lookout_dev_overlay_4d.gd")
const WOOD := preload("res://ramon/chickenpen/lookout/kata_wood_4d.gd")
const CHIPMUNK := preload("res://ramon/chickenpen/lookout/chipmunk_4d.gd")
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
## The kata wood (kata_wood_4d.gd), with the chipmunks: over the same field as the marsh, the
## other way along W - where the balloon goes if the fork goes kata.
@export var wood_at: Vector4 = Vector4(-26.0, 0.0, -24.0, -8.0)
@export_range(0, 6) var chipmunk_count: int = 3
## Which of the five thousand starlings is white. The pen's flock draws none unless told.
@export var white_starling: int = 2731
## P: the PROJECTION on or off, for whichever camera is drawing (Ramon, 2 Oct: "try to turn on
## projection ... make a toggle button for it"). Off is the plain cut, the Cross-section
## renderer; on is the Combined renderer, which draws the cut and over it a see-through
## projection of the whole 4D scene along W - so what is ana or kata of your slice shows as a
## ghost, tinted by which side it is on. It is a camera setting, so it costs nothing while off.
@export var projection_key: Key = KEY_P
## How strongly the ghost is drawn over the cut, and the opacity each tetrahedron adds to it.
## The ground is a slab hundreds of metres deep in W, so a high base turns into a haze over the
## whole field (lofting_gotchas.md, "the fog over the floor is the projection pass").
@export_range(0.0, 1.0, 0.01) var projection_opacity: float = 0.55
@export_range(0.0, 1.0, 0.005) var projection_opacity_base: float = 0.05
var projection: bool = false

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
## The dead tree the owl sits in, out at its w.
var owl_tree: Node4D
## U: flying the flock's hawk.
var hawk_flight: Node
## F4: the developer overlay.
var dev_overlay: Control
var wood: Node4D
var chipmunks: Array[Node4D] = []
var balloon: Node
var wren: Node4D
var wren_head: Node4D
var marsh: Node4D
var heron: Node4D

var _board: Node4D
var _board_tag: WorldTag4D
var _board_shown: String = ""
var _down: Node4D
var _down_tag: WorldTag4D
var _down_shown: String = ""
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
	dev_overlay = _overlay(DEV, "DevOverlay", 9) as Control
	dev_overlay.set("lookout", self)
	cutscene = CUTSCENE.new()
	cutscene.name = "Cutscene"
	cutscene.set("lookout", self)
	add_child(cutscene)
	hawk_flight = HAWK.new()
	hawk_flight.name = "Hawk"
	add_child(hawk_flight)
	hawk_flight.call("setup", self)
	_build_owl()
	_build_balloon()
	_build_marsh()
	_build_wood()
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
	marsh.set("lookout_path", get_path())
	# Facing along the open water, its back to the reeds.
	heron.basis = Basis4D.from_zx(-PI * 0.5)
	room.get_node("World").add_child(heron)
	marsh.set("heron_path", heron.get_path())


func _build_wood() -> void:
	wood = Node4D.new()
	wood.name = "KataWood"
	wood.set_script(WOOD)
	wood.position = wood_at
	room.get_node("World").add_child(wood)
	for i in chipmunk_count:
		var c := Node4D.new()
		c.name = "Chipmunk%d" % i
		c.set_script(CHIPMUNK)
		c.set("chipmunk_seed", 11 + i * 7)
		c.set("wood_path", wood.get_path())
		c.set("player_path", player.get_path() if player != null else NodePath())
		c.set("lookout_path", get_path())
		var a: float = float(i) / float(maxi(chipmunk_count, 1)) * TAU
		c.position = wood_at + Vector4(cos(a) * 1.6, 0.0, sin(a) * 1.6, 0.0)
		room.get_node("World").add_child(c)
		chipmunks.append(c)


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


## The owl, on a twig of a dead tree off the north side, out at w +1.5 (Ramon, 2 Oct: "make
## the owl a tree, could be a bare dead tree of lofted shapes, so it can sit on a twig").
## The twig ends where the old post's top was, so everything aimed at the owl still is.
func _build_owl() -> void:
	if tower == null:
		return
	var perch: Vector4 = tower.call("ana_perch")
	owl_tree = Node4D.new()
	owl_tree.name = "OwlTree"
	owl_tree.set_script(TREE)
	# Its trunk back and to one side of the twig, so the limb reaches out towards the deck.
	var base: Vector4 = perch + tower.global_basis * Vector4(-1.3, 0.0, -1.4, 0.0)
	base.y = tower.global_position.y
	owl_tree.set("height", 13.5)
	owl_tree.set("trunk_radius", 0.42)
	owl_tree.set("limb_count", 5)
	owl_tree.set("use_perch", true)
	owl_tree.set("perch", tower.global_basis.inverse() * (perch - base))
	room.get_node("World").add_child(owl_tree)
	owl_tree.global_position = base
	owl_tree.global_basis = tower.global_basis
	owl = Node4D.new()
	owl.name = "AnaOwl"
	owl.set_script(OWL)
	owl.set("lookout_path", get_path())
	room.get_node("World").add_child(owl)
	owl.global_position = owl_tree.call("perch_point") + Vector4(0.0, 0.03, 0.0, 0.0)
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
	for c in chipmunks:
		var cu: float = float(c.get("size"))
		var chip: Node4D = c
		subjects.call("add", {"id": String(c.name).to_lower(), "page": "chipmunks", "name": "A chipmunk", "node": c, "lift": 0.0,
			"radius": 0.09 * cu, "w_radius": 0.05 * cu * float(c.get("w_stretch")),
			"point": func(_s: Dictionary) -> Variant: return chip.call("centre") if chip.is_visible_in_tree() else null,
			"behave": func(_s: Dictionary) -> Array: return chip.call("behaviour")})
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
		hawk_flight.get("camera") if hawk_flight != null else null, farm_camera, room.get_node_or_null("World/TalkCam")]
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


func set_projection(on: bool) -> void:
	projection = on
	_apply_projection(current_camera())
	# The starlings are not 4D meshes, so the projection pass leaves them out; the flock draws
	# its own ghost of the birds off your slice instead.
	var flock: Node = room.get_node_or_null("World/Flock")
	if flock != null and "ghost" in flock:
		flock.set("ghost", on)


## Puts the camera on the renderer the toggle asks for, if it is not on it already. Run every
## frame on whichever camera is current, so a camera made later (raising the camera, a
## cutscene) picks the setting up as soon as it draws.
func _apply_projection(cam: Camera4D) -> void:
	if cam == null:
		return
	var want: String = "Combined" if projection else "Cross-section"
	if String(cam.get("rendering_engine_name")) == want:
		return
	cam.set("projection_opacity", projection_opacity)
	cam.set("projection_opacity_base", projection_opacity_base)
	cam.set("rendering_engine_name", want)


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
	for c in chipmunks:
		var dc: Vector4 = c.global_position - eye
		if Vector3(dc.x, dc.y, dc.z).length() < 45.0 and absf(dc.w) < 5.0:
			c.call("hear")
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
	# And at the top, on the balcony: F at the gap in the rail climbs down.
	if bool(tower.call("is_balcony")):
		_down = Node4D.new()
		_down.name = "LookoutLadderTop"
		room.get_node("World").add_child(_down)
		_down.global_position = tower.call("ladder_top") + Vector4(0.0, 1.0, 0.0, 0.0)
		_down_tag = WorldTag4D.new()
		_down_tag.name = "Prompt"
		_down_tag.anchor_path = _down.get_path()
		_down_tag.lift = 8.0
		_down.add_child(_down_tag)


func _near_ladder() -> bool:
	if _ladder == null or player == null or not player.is_visible_in_tree():
		return false
	var gap: Vector4 = _ladder.global_position - player.global_position
	return Vector2(gap.x, gap.z).length() <= ladder_reach and absf(gap.w) <= ladder_reach_w


## Whether F would climb down now: on the balcony at the gap in the rail.
func can_climb_down() -> bool:
	if _down == null or station == null or story_busy() or player == null or not player.is_visible_in_tree():
		return false
	var mode: int = int(station.get("mode"))
	if mode != 0 and mode != 5:
		return false
	if mode == 0 and player.get("input_enabled") == false:
		return false
	var gap: Vector4 = (tower.call("ladder_top") as Vector4) - player.global_position
	return Vector2(gap.x, gap.z).length() <= 1.3 and absf(gap.y) < 1.0 and absf(gap.w) < 1.2


## Whether F would climb right now: at the ladder's foot, with Wren's camera, hands free,
## nobody to talk to. With the camera raised too: it comes down for the climb.
func can_climb() -> bool:
	var mode: int = int(station.get("mode")) if station != null else -1
	if station == null or (mode != 0 and mode != 5) or story_busy() or _ladder == null or player == null:
		return false
	if not player.is_inside_tree() or not player.is_visible_in_tree() or player.get("input_enabled") == false:
		return false
	if not _near_ladder() or bool(tower.call("on_deck", player.global_position)):
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


## Whether B (or F at the basket) would take you up: the balloon is up by the tower and you
## are free - on the farm, the camera raised or not. From anywhere: Ramon, 2 Oct, "how do you
## enter the balloon, that's not clear to me".
func can_board() -> bool:
	if balloon == null or not bool(balloon.get("ready_now")) or bool(balloon.get("riding")) or _board == null:
		return false
	var mode: int = int(station.get("mode"))
	if (mode != 0 and mode != 5) or story_busy() or player == null or not player.is_visible_in_tree():
		return false
	if mode == 0 and player.get("input_enabled") == false:
		return false
	var world := room.get_node_or_null("World") as Node4D
	if world == null or not world.is_visible_in_tree():
		return false
	return bool(story.call("balloon_open"))


func _near_basket() -> bool:
	var gap: Vector4 = _board.global_position - player.global_position
	return Vector2(gap.x, gap.z).length() <= 2.2 and absf(gap.w) <= 1.2


func _process(delta: float) -> void:
	if _slow > 0.0:
		# Real seconds, not scaled ones: the slow motion must end on time.
		_slow -= delta / maxf(Engine.time_scale, 0.01)
		if _slow <= 0.0:
			Engine.time_scale = 1.0
	if _board_tag != null:
		var board_text: String = ""
		if can_board():
			board_text = ("%s or B  board the balloon" % _catch_key()) if _near_basket() else "Wren's balloon  ·  B to go up"
		_board_tag.fade_to = 60.0
		_board_tag.fade_from = 45.0
		if board_text != _board_shown:
			_board_shown = board_text
			if board_text == "":
				_board_tag.clear()
			else:
				_board_tag.show_text(board_text)
	# The prompts are placed through whichever camera is drawing: the farm's, or the raised one.
	var cam: Camera4D = current_camera()
	_apply_projection(cam)
	for t in [_tag, _board_tag, _down_tag]:
		if t != null:
			t.set("_camera", cam)
	if _down_tag != null:
		# With the camera up, the keys card says it; the tag would sit under the viewfinder.
		var down_text: String = ("%s  climb down" % _catch_key()) if can_climb_down() and int(station.get("mode")) == 0 else ""
		if down_text != _down_shown:
			_down_shown = down_text
			if down_text == "":
				_down_tag.clear()
			else:
				_down_tag.show_text(down_text)
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
	if event.is_action_pressed(&"catch_target") and can_climb_down():
		get_viewport().set_input_as_handled()
		station.call("climb_down")
	elif event.is_action_pressed(&"catch_target") and can_climb():
		get_viewport().set_input_as_handled()
		station.call("climb")
	elif event.is_action_pressed(&"catch_target") and can_board() and _near_basket():
		get_viewport().set_input_as_handled()
		balloon.call("board")
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == projection_key:
		get_viewport().set_input_as_handled()
		set_projection(not projection)
	elif key.keycode == KEY_Z and station.call("can_raise"):
		get_viewport().set_input_as_handled()
		station.call("raise")
	elif key.keycode == KEY_B and can_board():
		get_viewport().set_input_as_handled()
		balloon.call("board")


# --- What the station tells us -----------------------------------------------------------------

func on_cab_entered() -> void:
	sound(&"hatch")
	story.call("on_cab_entered")


func on_camera_raised() -> void:
	story.call("on_camera_raised")


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
		sound(&"secret" if page in ["owl", "white_starling", "heron", "chipmunks"] else &"new_page")
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
