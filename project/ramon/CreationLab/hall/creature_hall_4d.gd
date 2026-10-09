@tool
extends Node4D

## THE CREATURE HALL (Creature Lab v2, 9 Oct 2026; CreationLab/PLAN_V2.md part E, from Ramon's walkthrough:
## "a large Animal Creation Showcase hall ... land and flying animals ... a central path to a large central
## pedestal with the Brachiosaurus at its rear ... varied, asymmetric pedestals ... avoid making the space feel
## like a rigid grid of identical museum stands"). Its own scene, through the entry room's hologram door
## (creature_lab_4d.gd), behind the Voxel Lab's loading board; back out through the door you came in by.
##
##   the hall      a 30 x 44 m kit room, 14 m to its ceiling and no ceiling lines; the back wall blue with
##                 the title (creature_hall.tscn)
##   the stations  STATIONS below: where each pedestal stands, its shape and height, and who lives on it.
##                 Built one a frame behind the board, so the lofting of every animal is on nobody's screen
##   the walkers   the four-legged ones walk their decks and turn in before the edge (pedestal_roam_4d.gd);
##                 Nike and the chickens steer themselves and are only kept on; the crows fly short loops
##                 round their perches and land again
##   the paths     PathCreator's network on right angles, branching to every station
##
## BLOCK-IN FIRST (Ramon: "block everything in first, and than worry about optimization after"): every animal
## is the full live one; what each costs is the next batch.
##
## NO class_name (engine_gotchas.md).

const KitPlayer := preload("res://ramon/CreationLab/kit/kit_player.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const Hud := preload("res://ramon/CreationLab/scripts/rd_hud.gd")
const Build := preload("res://ramon/CreationLab/scripts/chamber_build.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const Graph := preload("res://ramon/CreationLab/PathCreator/graph/path_graph.gd")
const Network := preload("res://ramon/CreationLab/PathCreator/graph/path_network_4d.gd")
const Target := preload("res://ramon/CreationLab/v2/lab_target_4d.gd")
const Shimmer := preload("res://ramon/CreationLab/hall/carried/vl_shimmer_4d.gd")
const LoadBoard := preload("res://ramon/CreationLab/hall/carried/vl_load_board.gd")
const Pedestal := preload("res://ramon/CreationLab/hall/hall_pedestal.gd")
const Roam := preload("res://ramon/CreationLab/hall/pedestal_roam_4d.gd")
const WPop := preload("res://ramon/CreationLab/hall/w_population_4d.gd")
const LabScript := preload("res://ramon/CreationLab/creature_lab_4d.gd")
const LAB := "res://ramon/CreationLab/creature_lab.tscn"
const Card := preload("res://ramon/CreationLab/hall/hall_info_card.gd")
const INFO := preload("res://ramon/CreationLab/hall/creature_hall_info.tres")
## How near a pedestal's edge its card comes up (m), and how far away you go before a closed card may come back.
const CARD_NEAR := 2.5
const CARD_RESET := 4.5

const CREATURES := "res://ramon/CreationLab/hall/creatures/"
const CARRIED := "res://ramon/CreationLab/LabKit/carried/"
## The pen's strider copy: the hide cut into rigid pieces, only a band at each joint posed per vertex (the
## Model copy skins every vertex every frame: some 10 ms an animal here, follow_up/lofting_gotchas.md).
const WALKER := "res://ramon/CreationLab/LabKit/carried/chickenpen/scripts/strider_walker.gd"
const OWL := "res://ramon/CreationLab/LabKit/carried/chickenpen/lookout/owl_4d.gd"
const HERON := "res://ramon/CreationLab/LabKit/carried/chickenpen/lookout/heron_4d.gd"
const CHIPMUNK := "res://ramon/CreationLab/LabKit/carried/chickenpen/lookout/chipmunk_4d.gd"
const CROW := "res://ramon/CreationLab/LabKit/carried/chickenpen/scripts/pen_crow_4d.gd"
const OAK := "res://ramon/CreationLab/hall/carried/hall_oak_4d.gd"

## Every station: where (x, z), the pedestal ("round": size.x its radius; "square": its width and depth),
## how tall, who stands on it, its name on the loading board, and how many more of it stand at other W's on
## the same deck (w_copies, w_population_4d.gd). Its info card's words are in creature_hall_info.tres, by
## the station's name.
const STATIONS := [
	{"name": "Centre", "at": Vector2(0, -9), "shape": "square", "size": Vector2(10, 10), "h": 0.6, "kind": "brachio", "title": "Brachiosaurus"},
	{"name": "Wolf", "at": Vector2(-9.5, 9), "shape": "round", "size": Vector2(3.4, 3.4), "h": 0.5, "kind": "wolf", "title": "Wolf", "w_copies": 1},
	{"name": "Horse", "at": Vector2(9.5, 9), "shape": "square", "size": Vector2(6, 5), "h": 0.6, "kind": "horse", "title": "Horse", "w_copies": 1},
	{"name": "Chickens", "at": Vector2(-5, 17), "shape": "round", "size": Vector2(2.0, 2.0), "h": 0.35, "kind": "chickens", "title": "Chickens", "w_copies": 2},
	{"name": "Heron", "at": Vector2(5, 17), "shape": "round", "size": Vector2(1.3, 1.3), "h": 0.3, "kind": "heron", "title": "Grey heron", "w_copies": 1},
	{"name": "Nike", "at": Vector2(-10.5, -4), "shape": "round", "size": Vector2(3.0, 3.0), "h": 0.45, "kind": "nike", "title": "Nike"},
	{"name": "Goat", "at": Vector2(10.5, -4), "shape": "square", "size": Vector2(4.4, 4.4), "h": 0.75, "kind": "goat", "title": "Goat", "w_copies": 1},
	{"name": "Owl", "at": Vector2(-12, -19.2), "shape": "square", "size": Vector2(1.6, 1.6), "h": 0.5, "kind": "owl", "title": "Eagle owl", "w_copies": 1},
	{"name": "Chipmunk", "at": Vector2(-6.2, -19.4), "shape": "round", "size": Vector2(0.6, 0.6), "h": 0.9, "kind": "chipmunk", "title": "Chipmunk", "w_copies": 2},
	{"name": "Crows", "at": Vector2(11, -19.6), "shape": "square", "size": Vector2(3.6, 3.6), "h": 0.4, "kind": "crows", "title": "Crows", "w_copies": 1},
	{"name": "TreeSW", "at": Vector2(-12.6, 18.6), "shape": "round", "size": Vector2(1.5, 1.5), "h": 0.15, "kind": "tree", "seed": 3, "w_copies": 1},
	{"name": "TreeSE", "at": Vector2(12.6, 18.6), "shape": "round", "size": Vector2(1.5, 1.5), "h": 0.15, "kind": "tree", "seed": 7, "w_copies": 1},
	{"name": "TreeW", "at": Vector2(-13, -11), "shape": "round", "size": Vector2(1.5, 1.5), "h": 0.15, "kind": "tree", "seed": 11, "w_copies": 1},
	{"name": "TreeE", "at": Vector2(13, -10.5), "shape": "round", "size": Vector2(1.5, 1.5), "h": 0.15, "kind": "tree", "seed": 5, "w_copies": 1},
]

## Where you arrive: far enough in that the camera, 6 m behind you, is inside the hall.
@export var start_at: Vector2 = Vector2(0.0, 15.2)
@export_group("Camera")
@export_range(2.0, 12.0, 0.1) var camera_distance: float = 6.0
@export_range(0.5, 3.5, 0.05) var camera_height: float = 2.45
@export_range(-45.0, 20.0, 0.5) var camera_pitch_degrees: float = -9.0

var player: CharacterBody4D
var hud: Control
## Each station as built: {"name", "data", "node", "deck_h", "animals": [Node4D]}.
var stations: Array = []
var loading: bool = false
var _board: Control
var _board_t: float = 0.0
var _to_build: Array = []
var _leaving: bool = false
var card: Control
var _card_at: String = ""
## Stations whose card was closed with a click, until you walk away from them.
var _closed: Dictionary = {}


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func toggle_palette() -> void:
	Style.palette = "grey" if Style.palette == "black" else "black"
	Style.apply(Style.mood)
	for n in get_tree().get_nodes_in_group("lab_mood_listener"):
		if n != self and is_ancestor_of(n) and n.has_method("apply_mood"):
			n.call("apply_mood", Style.mood, true)
	_label_switch()


func _label_switch() -> void:
	if hud != null:
		hud.set("switch_text", "GREY  ·  B" if Style.palette == "black" else "BLACK  ·  B")
		hud.call("refresh_switch")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	if hud != null:
		hud.call("set_mood", m)


func _ready() -> void:
	var room: Node = get_node_or_null("Room")
	if room != null:
		room.set("mood_overrides", Style.ROOM_LIGHT.duplicate(true))
		room.call("set_mood", String(room.get("mood")), true, false)
	if Engine.is_editor_hint():
		# In the editor the pedestals only, to lay the hall out by; the animals are built in the game.
		for s in STATIONS:
			_pedestal(s)
		return
	Build.box(self, "DoorStep", Vector3(0.0, -0.25, 22.8), Vector3(4.6, 0.5, 1.6), "kit_floor")
	var door := Node4D.new()
	door.name = "LabDoor"
	door.set_script(Shimmer)
	door.set("width", 3.4)
	door.set("height", 4.1)
	door.position = Vector4(0.0, 0.0, 22.0 - 0.17, 0.0)
	add_child(door)
	_build_route()
	player = KitPlayer.make()
	add_child(player)
	player.global_position = Vector4(start_at.x, 0.05, start_at.y, 0.0)
	player.set("_facing", PI)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		# The slice turns here (right drag, R levels it): the hall is for seeing the animals in 4D.
		rig.set("slice_turning", true)
		rig.set("pitch", deg_to_rad(camera_pitch_degrees))
		rig.set("distance", camera_distance)
		rig.set("_zoom_target", camera_distance)
		rig.set("_rest_distance", camera_distance)
		rig.set("pivot_height", camera_height)
		rig.set("_home_pivot", camera_height)
		rig.call("_apply")
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Control.new()
	hud.set_script(Hud)
	hud.set("glass", true)
	layer.add_child(hud)
	hud.connect("mood_pressed", toggle_palette)
	if room != null:
		room.set("mood_key", KEY_NONE)
	_label_switch()
	apply_mood(String(room.get("mood")) if room != null else "bright")
	hud.set("strip", [["WASD", "Move"], ["Mouse", "Look"], ["Right drag", "Turn the slice"], ["R", "Level"], ["B", "Black / grey"]])
	card = Control.new()
	card.name = "InfoCard"
	card.set_script(Card)
	card.set("close_hint", INFO.get("close_hint"))
	layer.add_child(card)
	_to_build = STATIONS.duplicate()
	_open_board()


# -- the loading board -------------------------------------------------------------------------------

func _open_board() -> void:
	loading = true
	_board_t = 0.0
	_board = LoadBoard.open(self)
	_board.set("kicker", "CREATURE LAB  ·  THROUGH THE DOOR")
	_board.set("title", "CREATURE SHOWCASE")
	_board.set("subtitle", "Land and air, in four dimensions")
	_board.set("coming", ["A brachiosaurus on the centre pedestal, and the animals round it",
		"Every one lofted from a handful of 4D balls, walking on its own gait",
		"Turn the slice and see them as they are: a little of each at a time"])
	_board.set("diagram_title", "ANIMALS, LOFTED AS YOU WAIT")
	_board.connect("finished", func() -> void:
		loading = false
		_board = null
		if player != null:
			player.set("input_enabled", true))
	_feed_board()


## One station a frame while the board is up (every loft rig builds as it enters the tree, the brachiosaurus
## alone for some hundreds of milliseconds), the bars filling as they go.
func _feed_board() -> void:
	if _board == null:
		return
	var bars: Array = []
	var animals: int = 0
	for s in STATIONS:
		if String(s["kind"]) == "tree":
			continue
		var done: bool = _built(String(s["name"]))
		bars.append([String(s.get("title", s["name"])), 1.0 if done else 0.0, "ready" if done else ""])
	var nodes: int = 0
	for st in stations:
		animals += (st["animals"] as Array).size()
		nodes += _count(st["node"])
	_board.set("bars", bars)
	_board.set("numbers", [["Stations", "%d of %d" % [stations.size(), STATIONS.size()]], ["Animals", str(animals)], ["Scene nodes", str(nodes)]])
	_board.set("progress", float(stations.size()) / float(STATIONS.size()))
	if player != null:
		player.set("input_enabled", false)


func _built(nm: String) -> bool:
	for st in stations:
		if String(st["name"]) == nm:
			return true
	return false


static func _count(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _count(ch)
	return c


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or player == null:
		return
	if loading:
		_board_t += delta
		# A frame for the board to show first, then a station a frame.
		if _board_t > 0.1 and not _to_build.is_empty():
			_build_station(_to_build.pop_front())
		_feed_board()
		if _to_build.is_empty() and _board_t > 1.6 and _board != null:
			_board.call("finish")
		return
	_door_check(player.global_position)
	_card_check(player.global_position)


# -- the info cards ----------------------------------------------------------------------------------

## The card of the station you are nearest, when you are within CARD_NEAR of its pedestal's edge.
func _card_check(p: Vector4) -> void:
	var best: String = ""
	var best_d: float = INF
	for st in stations:
		var s: Dictionary = st["data"]
		if String(s["kind"]) == "tree":
			continue
		var sz: Vector2 = s["size"]
		var r: float = sz.x if String(s["shape"]) == "round" else maxf(sz.x, sz.y) * 0.5
		var at: Vector2 = s["at"]
		var d: float = Vector2(p.x - at.x, p.z - at.y).length() - r
		if d > CARD_RESET:
			_closed.erase(String(st["name"]))
		if d < best_d:
			best_d = d
			best = String(st["name"])
	var cards: Dictionary = INFO.get("cards")
	if best_d < CARD_NEAR and not _closed.has(best) and cards.has(best):
		if best != _card_at or not bool(card.call("showing")):
			card.call("show_card", cards[best])
			_card_at = best
	elif bool(card.call("showing")):
		card.call("hide_card")
		_card_at = ""


## A left click closes the card (the right drag still turns the slice).
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or card == null or loading:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and bool(card.call("showing")) 			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_closed[_card_at] = true
		card.call("hide_card")
		_card_at = ""
		get_viewport().set_input_as_handled()


# -- the way back ------------------------------------------------------------------------------------

func _door_check(p: Vector4) -> void:
	var door: Node4D = get_node_or_null("LabDoor") as Node4D
	if door == null or _leaving:
		return
	if p.z > door.position.z - 0.35 and absf(p.x) < 1.6:
		_leaving = true
		player.set("input_enabled", false)
		door.call("flash_out", self, to_lab)


## Back to the Creature Lab, arriving in its entry room by the hall's door.
func to_lab() -> void:
	LabScript.arrive_from = "hall"
	get_tree().change_scene_to_file(LAB)


# -- the stations ------------------------------------------------------------------------------------

func _pedestal(s: Dictionary) -> Dictionary:
	var holder: Node4D = get_node_or_null("Stations") as Node4D
	if holder == null:
		holder = Node4D.new()
		holder.name = "Stations"
		add_child(holder)
	return Pedestal.build(holder, String(s["name"]), s["at"], String(s["shape"]), s["size"], float(s["h"]))


func _build_station(s: Dictionary) -> void:
	var ped: Dictionary = _pedestal(s)
	var node: Node4D = ped["node"]
	var deck := Node4D.new()
	deck.name = "Deck"
	deck.position = Vector4(0.0, float(ped["deck_h"]), 0.0, 0.0)
	node.add_child(deck)
	var st: Dictionary = {"name": String(s["name"]), "data": s, "node": node, "deck_h": float(ped["deck_h"]), "animals": []}
	# Its own layer at W 0, then its copies through W on the same deck (w_population_4d.gd).
	var layers: Array = WPop.layers(s)
	for i in layers.size():
		var lay_d: Dictionary = layers[i]
		var lay := Node4D.new()
		lay.name = "W%d" % i
		lay.position = Vector4(0.0, 0.0, 0.0, float(lay_d["w"]))
		var g: float = float(lay_d["grow"])
		var r: Projection = Basis4D.from_zx(float(lay_d["turn"]))
		lay.basis = Projection(r.x * g, r.y * g, r.z * g, r.w * g)
		deck.add_child(lay)
		_populate(lay, s, st, (s["size"] as Vector2) / g)
	stations.append(st)


## Who stands on one layer of a station's deck (`deck`: the layer, its own frame, `size` the deck in it).
func _populate(deck: Node4D, s: Dictionary, st: Dictionary, size: Vector2) -> void:
	match String(s["kind"]):
		"brachio":
			var b: Node4D = _instance(CREATURES + "brachio.tscn")
			if b != null:
				# At the deck's rear, walking a slow small round there (it is 7 m long; the deck is 10).
				b.position = Vector4(0.0, 0.0, -1.2, 0.0)
				var body: Node4D = b.get_node_or_null("Brachio") as Node4D
				var w: Node = body.get_node_or_null("Walker") if body != null else null
				if body != null:
					_rescale(body, 0.2 / 0.25)
					_turn(body, PI * 0.5)
				# Before it enters the tree: the walker copies belt_speed into its pace only then
				# (follow_up/creation_lab_creatures.md). About 0.2 m/s at this size, stately.
				if w != null:
					w.set("belt_speed", 1.8)
				deck.add_child(b)
				if w != null:
					_roam(b, w, {"radius": 1.1, "margin": 0.2, "look_ahead": 0.8, "turn_rate": 10.0, "wander_degrees": 12.0})
				if body != null:
					st["animals"].append(body)
		"horse":
			var h: Node4D = _instance(CREATURES + "horse.tscn")
			if h != null:
				var strider: Node4D = h.get_node_or_null("Creature/Strider") as Node4D
				if strider != null:
					_rescale(strider, 0.32)
					strider.position.y += 0.1
					_turn(strider, 0.6)
				var hw: Node = h.get_node_or_null("Creature/Strider/Walker")
				if hw != null:
					# About 0.2 m/s at this size (its default walks it at half that).
					hw.set("belt_speed", 3.0)
				deck.add_child(h)
				var w: Node = h.get_node_or_null("Creature/Strider/Walker")
				if w != null:
					_roam(h.get_node("Creature"), w, {"half": size * 0.5, "margin": 1.2, "look_ahead": 1.0, "turn_rate": 30.0})
				if strider != null:
					st["animals"].append(strider)
		"goat":
			var g: Node4D = _instance(CREATURES + "goat.tscn")
			if g != null:
				var body: Node4D = g.get_node_or_null("Goat") as Node4D
				if body != null:
					_rescale(body, 0.38)
					_turn(body, -2.2)
					# The goat came with no walker of its own (room 1 walks it rigidly): the strider's.
					var w := Node4D.new()
					w.name = "Walker"
					w.set_script(load(WALKER))
					w.set("rig_path", NodePath("../Hide"))
					w.set("leg_name_prefixes", PackedStringArray(["FrontLegTop", "RearLegTop"]))
					w.set("belt_speed", 3.0)
					w.set("stride_length", 0.7)
					w.set("step_height", 0.2)
					w.set("body_bob", 0.04)
					w.set("blend_joints", true)
					body.add_child(w)
				deck.add_child(g)
				var gw: Node = g.get_node_or_null("Goat/Walker")
				if gw != null:
					_roam(g, gw, {"half": size * 0.5, "margin": 0.8, "look_ahead": 0.7, "turn_rate": 40.0})
				if body != null:
					st["animals"].append(body)
		"wolf":
			var wf: Node4D = _instance("res://ramon/CreationLab/v2/wolf2.tscn")
			if wf != null:
				_rescale(wf, 2.0)
				_turn(wf, 2.4)
				deck.add_child(wf)
				var w: Node = wf.get_node_or_null("Walker")
				if w != null:
					_roam(deck, w, {"radius": size.x, "margin": 1.4, "look_ahead": 1.0, "turn_rate": 40.0})
				st["animals"].append(wf)
		"nike":
			var nk: Node4D = _instance(CARRIED + "chickenpen/nike.tscn")
			if nk != null:
				_rescale(nk, 0.6)
				_turn(nk, -0.8)
				var antics: Node = nk.get_node_or_null("Antics")
				if antics != null:
					# No pen here: no fence to hop, no trough to go to; leashed to the middle of his deck.
					antics.set("fence_path", NodePath())
					antics.set("feeder_path", NodePath())
					antics.set("leash_radius", maxf(size.x - 1.6, 0.6))
				deck.add_child(nk)
				if antics != null:
					antics.call_deferred("leash", true)
				var w: Node = nk.get_node_or_null("Walker")
				if w != null:
					_roam(deck, w, {"radius": size.x, "margin": 1.2, "steer": false})
				st["animals"].append(nk)
		"chickens":
			for i in 3:
				var c: Node4D = _instance(CARRIED + "chickenpen/chicken.tscn")
				if c == null:
					continue
				c.name = "Chicken%d" % i
				# Just the bird and its walk: the pen's agent (penned, carried, chased) has nothing to do here.
				var agent: Node = c.get_node_or_null("Agent")
				if agent != null:
					c.remove_child(agent)
					agent.free()
				var a: float = TAU * float(i) / 3.0 + 0.4
				c.position = Vector4(cos(a) * 0.8, 0.0, sin(a) * 0.8, 0.0)
				_turn(c, a + 1.2)
				var cw: Node = c.get_node_or_null("Walker")
				if cw != null:
					# Its roam is in its own units (the bird is scaled 0.25), and no flock spacing: it compares
					# positions across the whole group, the copies through W in other frames among them.
					cw.set("roam_radius", size.x * 0.55 / maxf(c.basis.x.length(), 0.01))
					cw.set("separation", 0.0)
				deck.add_child(c)
				if cw != null:
					_roam(deck, cw, {"radius": size.x, "margin": 0.35, "steer": false})
				st["animals"].append(c)
		"heron":
			var hr := _scripted(HERON, "Heron", {"idle_only": true, "size": 1.0})
			if hr != null:
				_turn(hr, -0.5)
				deck.add_child(hr)
				st["animals"].append(hr)
		"owl":
			# A dead branch to sit on: a post, and a bough off it.
			var wood := Color(0.24, 0.2, 0.17)
			_bar(deck, "Post", Vector4(-0.35, 0.8, 0.1, 0.0), Vector4(0.14, 1.6, 0.14, 0.14), wood)
			_bar(deck, "Bough", Vector4(0.05, 1.52, 0.1, 0.0), Vector4(1.1, 0.09, 0.09, 0.09), wood)
			var ow := _scripted(OWL, "Owl", {"idle_only": true, "size": 0.5})
			if ow != null:
				ow.position = Vector4(0.15, 1.565, 0.1, 0.0)
				deck.add_child(ow)
				st["animals"].append(ow)
		"chipmunk":
			var cm := _scripted(CHIPMUNK, "Chipmunk", {"idle_only": true, "size": 0.9})
			if cm != null:
				_turn(cm, 0.4)
				deck.add_child(cm)
				st["animals"].append(cm)
		"crows":
			# Something to perch on: a rail on two posts and a crate.
			var dark := Color(0.2, 0.21, 0.24)
			_bar(deck, "PostL", Vector4(-1.2, 0.7, -0.6, 0.0), Vector4(0.1, 1.4, 0.1, 0.1), dark)
			_bar(deck, "PostR", Vector4(1.2, 0.7, -0.6, 0.0), Vector4(0.1, 1.4, 0.1, 0.1), dark)
			var rail := _bar(deck, "Rail", Vector4(0.0, 1.43, -0.6, 0.0), Vector4(2.6, 0.08, 0.12, 0.12), dark)
			var crate := _bar(deck, "Crate", Vector4(0.8, 0.3, 0.8, 0.0), Vector4(0.7, 0.6, 0.7, 0.4), Color(0.36, 0.3, 0.24))
			for i in 3:
				var cr := _scripted(CROW, "Crow%d" % i, {"flock_seed": 17 + i * 5, "ground_radius": 1.3, "cruise_height": 3.2,
					"fly_min": 2.5, "fly_max": 5.0})
				if cr == null:
					continue
				cr.position = Vector4(-0.9 + float(i) * 0.8, 0.0, 0.5, 0.0)
				var perches: Array[NodePath] = [NodePath("../Rail"), NodePath("../Crate")]
				cr.set("perch_paths", perches)
				deck.add_child(cr)
				st["animals"].append(cr)
			if rail == null or crate == null:
				push_warning("Crows: no perches")
		"tree":
			var t := _scripted(OAK, "Oak", {"bake": "oak_lite2", "leaves_per_node": 28, "leaf_seed": int(s.get("seed", 5)),
				"snap_to_ground": false, "height": 6.4})
			if t != null:
				deck.add_child(t)


## A scene of an animal, ready to be placed; null (and a warning) if it would not load.
func _instance(path: String) -> Node4D:
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		push_warning("Creature hall: could not load %s" % path)
		return null
	return ps.instantiate() as Node4D


## A code-built animal: a Node4D with its script and settings, not yet in the tree.
func _scripted(path: String, nm: String, settings: Dictionary) -> Node4D:
	var sc: Script = load(path) as Script
	if sc == null:
		push_warning("Creature hall: could not load %s" % path)
		return null
	var n := Node4D.new()
	n.name = nm
	n.set_script(sc)
	for k in settings:
		n.set(k, settings[k])
	return n


## Its walk kept on the deck: a roam node beside the animal (under `host`, the animal's parent's parent or
## the deck), steering by the walker's parent.
func _roam(host: Node, walker: Node, settings: Dictionary) -> void:
	var r := Node.new()
	r.name = "Roam"
	r.set_script(Roam)
	r.set("walker_path", NodePath("../" + String(host.get_path_to(walker))))
	r.set("seed", int(hash(walker.get_path())) & 0xffff)
	for k in settings:
		r.set(k, settings[k])
	host.add_child(r)


## Scales a creature by `k`, its height off the ground with it (its feet stay on the floor).
static func _rescale(n: Node4D, k: float) -> void:
	var b: Projection = n.basis
	n.basis = Projection(b.x * k, b.y * k, b.z * k, b.w * k)
	n.position.y *= k


## Turns a creature to `yaw` (radians, about y), keeping its scale.
static func _turn(n: Node4D, yaw: float) -> void:
	var b: Projection = n.basis
	var s := Vector4(b.x.length(), b.y.length(), b.z.length(), b.w.length())
	var r: Projection = Basis4D.from_zx(yaw)
	n.basis = Projection(r.x * s.x, r.y * s.y, r.z * s.z, r.w * s.w)


## A plain box (a post, a bough, a crate), on the deck.
func _bar(parent: Node4D, nm: String, centre: Vector4, size: Vector4, col: Color) -> MeshInstance4D:
	var m := MeshInstance4D.new()
	m.name = nm
	m.mesh = Mats.box_mesh(size)
	m.material_override = Mats.flat(col)
	m.position = centre
	parent.add_child(m)
	return m


# -- the paths ---------------------------------------------------------------------------------------

## The hall's routes (Ramon: "branching grid paths"; the newer labs' straight runs and right angles): up the
## middle to the centre pedestal; across near the door to the chickens and the heron; across halfway to the
## wolf and Nike on the left, the horse and the goat on the right; and up the left side and along the back,
## behind the centre pedestal, to the owl, the chipmunk and the crows.
func _build_route() -> void:
	var paths := Node4D.new()
	paths.name = "Paths"
	add_child(paths)
	var targets := Node4D.new()
	targets.name = "Targets"
	paths.add_child(targets)
	for s in STATIONS:
		if String(s["kind"]) == "tree":
			continue
		var sz: Vector2 = s["size"]
		var foot: Vector2 = Vector2(sz.x * 2.0, sz.x * 2.0) if String(s["shape"]) == "round" else sz
		_target(targets, String(s["name"]), s["at"], Vector3(foot.x + 0.3, 1.0, foot.y + 0.3))
	var g: Resource = Graph.new()
	var b := {"band": 1.2}
	var s0: int = g.call("add_node", "start", Vector4(0, 0, 20.6, 0), b)
	var j1: int = g.call("add_node", "junction", Vector4(0, 0, 14, 0), b)
	var j2: int = g.call("add_node", "junction", Vector4(0, 0, 2.4, 0), b)
	var centre: int = _dest(g, Vector2(0, -2.6), "Centre", "rect", Vector2(0, 1), "available")
	g.call("add_edge", s0, j1)
	g.call("add_edge", j1, j2)
	g.call("add_edge", j2, centre)
	# Near the door: the chickens and the heron.
	g.call("add_edge", j1, _dest(g, Vector2(-5, 14), "Chickens", "round", Vector2(0, -1)), "secondary")
	g.call("add_edge", j1, _dest(g, Vector2(5, 14), "Heron", "round", Vector2(0, -1)), "secondary")
	# Halfway: left to the wolf and Nike, right to the horse and the goat.
	var jl0: int = g.call("add_node", "junction", Vector4(-6.2, 0, 2.4, 0), b)
	var jl: int = g.call("add_node", "junction", Vector4(-9.5, 0, 2.4, 0), b)
	var jr: int = g.call("add_node", "junction", Vector4(9.5, 0, 2.4, 0), b)
	g.call("add_edge", j2, jl0, "secondary")
	g.call("add_edge", jl0, jl, "secondary")
	g.call("add_edge", jl, _dest(g, Vector2(-9.5, 4.4), "Wolf", "round", Vector2(0, -1)), "secondary")
	g.call("add_edge", jl, _dest(g, Vector2(-9.5, 0.2), "Nike", "round", Vector2(0, 1)), "secondary")
	g.call("add_edge", j2, jr, "secondary")
	g.call("add_edge", jr, _dest(g, Vector2(9.5, 5.3), "Horse", "rect", Vector2(0, -1)), "secondary")
	g.call("add_edge", jr, _dest(g, Vector2(9.5, -0.6), "Goat", "rect", Vector2(0, 1)), "secondary")
	# Up the left and along the back: the owl, the chipmunk, the crows.
	var jb: int = g.call("add_node", "junction", Vector4(-6.2, 0, -16.5, 0), b)
	g.call("add_edge", jl0, jb, "secondary")
	g.call("add_edge", jb, _dest(g, Vector2(-12, -16.5), "Owl", "rect", Vector2(0, 1)), "secondary")
	g.call("add_edge", jb, _dest(g, Vector2(-6.2, -17.9), "Chipmunk", "round", Vector2(0, 1)), "secondary")
	g.call("add_edge", jb, _dest(g, Vector2(11, -16.5), "Crows", "rect", Vector2(0, 1)), "secondary")
	var net := Node4D.new()
	net.name = "Route"
	net.set_script(Network)
	net.set("graph", g)
	net.set("targets", NodePath("../Targets"))
	net.set("floor_swatch", "kit_floor")
	net.set("frame_tint", Color(0.09, 0.38, 0.843))
	paths.add_child(net)


func _dest(g: Resource, at: Vector2, target: String, frame: String, approach: Vector2, state: String = "arrival") -> int:
	return int(g.call("add_node", "destination", Vector4(at.x, 0, at.y, 0),
		{"band": 1.2, "state": state, "target": target, "frame": frame, "approach": approach}))


func _target(host: Node4D, nm: String, at: Vector2, size: Vector3) -> void:
	var t := Node4D.new()
	t.name = nm
	t.set_script(Target)
	t.set("label", nm)
	t.set("size", size)
	t.position = Vector4(at.x, 0.0, at.y, 0.0)
	host.add_child(t)
