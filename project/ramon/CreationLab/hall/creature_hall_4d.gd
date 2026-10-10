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
## ROUND 3 (10 Oct, PLAN_ROUND3.md): the building stays still. The view's slice no longer turns here; right
## drag turns every creature and tree through W round its own middle (turn_pivot_4d.gd), R puts them whole
## again, and walls, floor, pedestals, paths, doors and labels never move.
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
const TurnPivot := preload("res://ramon/CreationLab/hall/turn_pivot_4d.gd")
const LightEditor := preload("res://ramon/CreationLab/hall/carried/hall_light_editor.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const HallGrass := preload("res://ramon/CreationLab/hall/carried/grass/hall_grass_4d.gd")
const SpecLabel := preload("res://ramon/CreationLab/hall/carried/hall_float_panel_4d.gd")
const HeronLoop := preload("res://ramon/CreationLab/hall/heron_loop_4d.gd")
## The hall a little dimmer than the lab (round 3, item 41: "the current room lighting feels slightly too bright").
const EXPOSURE_K := 0.9
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
## The hall's own chipmunk (round 3: a visible tail, sat on its deck; hall/carried/README.md).
const CHIPMUNK := "res://ramon/CreationLab/hall/carried/hall_chipmunk_4d.gd"
const CROW := "res://ramon/CreationLab/LabKit/carried/chickenpen/scripts/pen_crow_4d.gd"
const OAK := "res://ramon/CreationLab/hall/carried/hall_oak_4d.gd"
const DREAMER := "res://ramon/CreationLab/hall/carried/hall_dreamer_4d.gd"

## Every station: where (x, z), the pedestal ("round": size.x its radius; "square": its width and depth),
## how tall, who stands on it, its name on the loading board, and how many more of it stand at other W's on
## the same deck (w_copies, w_population_4d.gd). Its info card's words are in creature_hall_info.tres, by
## the station's name.
## Round 3 (10 Oct) adds to each: "style" ("natural": green and grass; "technical": Azathoth's), "holo" (the
## hologram's height, foot and fall-off; hall_pedestal.gd), "grass" (blade height, m: the pen's are 0.66, these
## shorter, shortest under the small animals so their feet show) and "push" (how far round an animal the blades
## lie aside), "front" (the side you come from: the label stands there, facing you; the path's approach),
## "closeup" (the small ones: C for a close look, from "eye" metres off and "lift" up, at "aim" over its feet).
const STATIONS := [
	{"name": "Centre", "at": Vector2(0, -9), "shape": "square", "size": Vector2(10, 10), "h": 0.6, "kind": "brachio", "title": "Brachiosaurus",
		"style": "natural", "holo": {"height": 2.2, "base": 0.75, "falloff": 1.15, "glow": 1.1}, "grass": 0.42, "push": 1.2, "front": Vector2(0, 1)},
	{"name": "Wolf", "at": Vector2(-9.5, 9), "shape": "round", "size": Vector2(3.4, 3.4), "h": 0.5, "kind": "wolf", "title": "Wolf", "w_copies": 1,
		"style": "natural", "holo": {"height": 0.7, "base": 0.45, "falloff": 1.8}, "grass": 0.32, "push": 0.7, "front": Vector2(0, -1)},
	{"name": "Azathoth", "at": Vector2(9.5, 9), "shape": "square", "size": Vector2(7, 6), "h": 0.7, "kind": "azathoth", "title": "Azathoth",
		"style": "technical", "holo": {"height": 1.4, "base": 0.6, "falloff": 1.5, "glow": 0.9, "grow": 0.55}, "front": Vector2(0, -1)},
	{"name": "Chickens", "at": Vector2(-5, 17), "shape": "round", "size": Vector2(2.0, 2.0), "h": 0.35, "kind": "chickens", "title": "Chickens", "w_copies": 2,
		"style": "natural", "holo": {"height": 0.45, "base": 0.4, "falloff": 1.8}, "grass": 0.13, "push": 0.3, "front": Vector2(0, -1)},
	{"name": "Heron", "at": Vector2(5, 17), "shape": "round", "size": Vector2(1.3, 1.3), "h": 0.3, "kind": "heron", "title": "Grey heron", "w_copies": 1,
		"style": "natural", "holo": {"height": 0.5, "base": 0.4, "falloff": 1.8}, "grass": 0.2, "push": 0.35, "front": Vector2(0, -1)},
	{"name": "Nike", "at": Vector2(-10.5, -4), "shape": "round", "size": Vector2(3.0, 3.0), "h": 0.45, "kind": "nike", "title": "Nike",
		"style": "natural", "holo": {"height": 0.65, "base": 0.45, "falloff": 1.8}, "grass": 0.26, "push": 0.8, "front": Vector2(0, 1)},
	{"name": "Goat", "at": Vector2(10.5, -4), "shape": "square", "size": Vector2(4.4, 4.4), "h": 0.75, "kind": "goat", "title": "Goat", "w_copies": 1,
		"style": "natural", "holo": {"height": 0.65, "base": 0.45, "falloff": 1.8}, "grass": 0.22, "push": 0.5, "front": Vector2(0, 1)},
	{"name": "Owl", "at": Vector2(-12, -19.2), "shape": "square", "size": Vector2(1.6, 1.6), "h": 0.5, "kind": "owl", "title": "Eagle owl", "w_copies": 1,
		"style": "natural", "holo": {"height": 0.5, "base": 0.4, "falloff": 1.8}, "grass": 0.22, "front": Vector2(0, 1),
		"closeup": true, "eye": 1.5, "lift": 0.35, "aim": 0.3},
	{"name": "Chipmunk", "at": Vector2(-6.2, -19.4), "shape": "round", "size": Vector2(0.9, 0.9), "h": 0.9, "kind": "chipmunk", "title": "Chipmunk", "w_copies": 2,
		"style": "natural", "holo": {"height": 0.4, "base": 0.35, "falloff": 1.8}, "grass": 0.09, "push": 0.25, "front": Vector2(0, 1),
		"closeup": true, "eye": 0.75, "lift": 0.12, "aim": 0.18},
	{"name": "Crows", "at": Vector2(11, -19.6), "shape": "square", "size": Vector2(3.6, 3.6), "h": 0.4, "kind": "crows", "title": "Crows", "w_copies": 1,
		"style": "natural", "holo": {"height": 0.5, "base": 0.4, "falloff": 1.8}, "grass": 0.2, "push": 0.25, "front": Vector2(0, 1)},
	{"name": "TreeSW", "at": Vector2(-12.6, 18.6), "shape": "round", "size": Vector2(0.62, 0.62), "h": 0.15, "kind": "tree", "seed": 3, "w_copies": 1,
		"style": "natural", "grass": 0.28},
	{"name": "TreeSE", "at": Vector2(12.6, 18.6), "shape": "round", "size": Vector2(0.62, 0.62), "h": 0.15, "kind": "tree", "seed": 7, "w_copies": 1,
		"style": "natural", "grass": 0.28},
	{"name": "TreeW", "at": Vector2(-13, -11), "shape": "round", "size": Vector2(0.62, 0.62), "h": 0.15, "kind": "tree", "seed": 11, "w_copies": 1,
		"style": "natural", "grass": 0.28},
	{"name": "TreeE", "at": Vector2(13, -10.5), "shape": "round", "size": Vector2(0.62, 0.62), "h": 0.15, "kind": "tree", "seed": 5, "w_copies": 1,
		"style": "natural", "grass": 0.28},
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
## The exhibits' turn through W (xw, zw radians), shared by every pivot; eased home by R.
var turn: Vector2 = Vector2.ZERO
var _leveling: bool = false
## The close look (C at a small creature): {"cam", "st", "phase" in/hold/out, "t", "from", "to"}; empty when none.
var _look: Dictionary = {}


func _enter_tree() -> void:
	add_to_group("lab_mood_listener")


func toggle_palette() -> void:
	Style.palette = "grey" if Style.palette == "black" else "black"
	Style.apply(Style.mood)
	_dark_walls()
	for n in get_tree().get_nodes_in_group("lab_mood_listener"):
		if n != self and is_ancestor_of(n) and n.has_method("apply_mood"):
			n.call("apply_mood", Style.mood, true)
	_label_switch()


func _label_switch() -> void:
	if hud != null:
		# The Voxel and Aquatic Labs' words (round 3, item 42).
		hud.set("switch_text", "DARK MODE %s  ·  B" % ("ON" if Style.palette == "black" else "OFF"))
		hud.call("refresh_switch")


func apply_mood(m: String, _instant: bool = false) -> void:
	Style.apply(m)
	_dark_walls()
	if hud != null:
		hud.call("set_mood", m)


## In dark mode the hall's walls went flat black (round 3, item 42: "some walls become completely black ... avoid
## losing all geometric definition"): its walls are big and the lights hang far from them. Here only, the dark
## walls' grid lines a step lighter and at full strength, so the tiles read; the surface stays near black.
## (Swatches are shared; the next scene's Style.apply puts its own back.)
func _dark_walls() -> void:
	if Style.palette == "black":
		LabGrid.set_swatch("kit_wall", Color(0.085, 0.088, 0.096), Color(0.27, 0.28, 0.30), Color(0.15, 0.155, 0.17), 1.0)


func _ready() -> void:
	var room: Node = get_node_or_null("Room")
	if room != null:
		var light: Dictionary = Style.ROOM_LIGHT.duplicate(true)
		for m in light:
			if (light[m] as Dictionary).has("exposure"):
				light[m]["exposure"] = float(light[m]["exposure"]) * EXPOSURE_K
		room.set("mood_overrides", light)
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
	# In the doorway itself, half way through the wall (the kit's walls are 0.5 m), the opening's own size
	# (round 3: "position the holographic effect within the wall's thickness ... align it with the doorway").
	door.set("width", 3.4)
	door.set("height", 4.2)
	door.position = Vector4(0.0, 0.0, 22.0 + 0.25, 0.0)
	add_child(door)
	_build_route()
	player = KitPlayer.make()
	add_child(player)
	player.global_position = Vector4(start_at.x, 0.05, start_at.y, 0.0)
	player.set("_facing", PI)
	var rig: Node = player.get_node_or_null("CameraRig")
	if rig != null:
		# The view's slice does not turn here: right drag turns the exhibits instead (round 3, item 38).
		rig.set("slice_turning", false)
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
	hud.set("strip", _strip())
	# Tab: every light in the hall on its own (round 3, item 40; the Botany Lab's panel, carried).
	var ed := PanelContainer.new()
	ed.name = "LightEditor"
	ed.set_script(LightEditor)
	ed.set("room", self)
	var dev := CanvasLayer.new()
	dev.name = "Dev"
	dev.layer = 5
	add_child(dev)
	dev.add_child(ed)
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
	if not _look.is_empty():
		_look_step(delta)
		_apply_turn(delta)
		return
	_door_check(player.global_position)
	_card_check(player.global_position)
	_apply_turn(delta)
	hud.set("strip", _strip())


func _strip() -> Array:
	var out: Array = [["WASD", "Move"], ["Mouse", "Look"], ["Right drag", "Turn the animals in 4D"], ["R", "Whole again"]]
	if _near_closeup() != null:
		out.append(["C", "Close look"])
	out.append(["B", "Dark mode"])
	return out


# -- the close look -----------------------------------------------------------------------------------

## The small creature whose station you are by (its card is up), or null (round 3, item 33).
func _near_closeup() -> Variant:
	if _card_at.is_empty():
		return null
	for st in stations:
		if String(st["name"]) == _card_at and bool((st["data"] as Dictionary).get("closeup", false)) and not (st["animals"] as Array).is_empty():
			return st
	return null


## A close camera on a small creature (Ramon, item 33: "briefly transition to a closer camera angle ... from a
## flattering perspective ... preserve the creature's animation ... skip or dismiss"): your camera's copy eases
## in to a point in front of it, a little to one side and above, looking at it; any of C, a click or Esc eases
## back. It keeps looking at the creature while it is there, so a turn of its head or the exhibits' turn
## through W stays in frame. Any station with "closeup" gets it.
func close_look() -> bool:
	var st: Variant = _near_closeup()
	if st == null or not _look.is_empty():
		return false
	var pc: Camera4D = player.get_node_or_null("CameraRig/Pitch/Camera4D") as Camera4D
	if pc == null:
		return false
	var s: Dictionary = st["data"]
	var who: Node4D = (st["animals"] as Array)[0]
	var at: Vector4 = who.global_position + Vector4(0.0, float(s.get("aim", 0.2)), 0.0, 0.0)
	# In front of its face (the way it is turned, its +z), a little to one side; the station's front if it has none.
	var f4: Vector4 = who.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)
	var front: Vector2 = Vector2(f4.x, f4.z).normalized() if Vector2(f4.x, f4.z).length() > 0.01 else (s["front"] as Vector2).normalized()
	var side := Vector2(-front.y, front.x)
	var off: Vector2 = front * float(s.get("eye", 1.2)) + side * float(s.get("eye", 1.2)) * 0.35
	var eye := Vector4(at.x + off.x, at.y + float(s.get("lift", 0.3)), at.z + off.y, at.w)
	var cam := pc.duplicate(0) as Camera4D
	cam.name = "CloseLook"
	add_child(cam)
	cam.global_position = pc.global_position
	cam.global_basis = pc.global_basis
	cam.make_current()
	_look = {"cam": cam, "pc": pc, "who": who, "aim": float(s.get("aim", 0.2)), "phase": "in", "t": 0.0,
		"from_eye": pc.global_position, "from_ang": _angles_of(pc.global_basis), "eye": eye}
	player.set("input_enabled", false)
	card.call("hide_card")
	hud.set("strip", [["C / Click", "Back"]])
	return true


func close_look_end() -> void:
	if _look.is_empty() or String(_look["phase"]) == "out":
		return
	var cam: Camera4D = _look["cam"]
	_look["phase"] = "out"
	_look["t"] = 0.0
	_look["out_eye"] = cam.global_position
	_look["out_ang"] = _angles_of(cam.global_basis)


func _look_step(delta: float) -> void:
	var cam: Camera4D = _look["cam"]
	var pc: Camera4D = _look["pc"]
	var who: Node4D = _look["who"]
	_look["t"] = float(_look["t"]) + delta
	var u: float = clampf(float(_look["t"]) / 0.8, 0.0, 1.0)
	var e: float = u * u * (3.0 - 2.0 * u)
	var target: Vector4 = (who.global_position if is_instance_valid(who) else cam.global_position) + Vector4(0.0, float(_look["aim"]), 0.0, 0.0)
	match String(_look["phase"]):
		"in", "hold":
			var eye: Vector4 = (_look["from_eye"] as Vector4).lerp(_look["eye"], e)
			var to_ang: Vector2 = _aim(eye, target)
			var fa: Vector2 = _look["from_ang"]
			_put_cam(cam, eye, Vector2(lerp_angle(fa.x, to_ang.x, e), lerpf(fa.y, to_ang.y, e)))
			if u >= 1.0:
				_look["phase"] = "hold"
		"out":
			var oe: Vector4 = _look["out_eye"]
			var oa: Vector2 = _look["out_ang"]
			var back_ang: Vector2 = _angles_of(pc.global_basis)
			_put_cam(cam, oe.lerp(pc.global_position, e), Vector2(lerp_angle(oa.x, back_ang.x, e), lerpf(oa.y, back_ang.y, e)))
			if u >= 1.0:
				pc.make_current()
				cam.queue_free()
				_look = {}
				player.set("input_enabled", true)
				hud.set("strip", _strip())


static func _angles_of(b: Projection) -> Vector2:
	var f: Vector4 = -(b * Vector4(0.0, 0.0, 1.0, 0.0))
	return Vector2(atan2(-f.x, -f.z), atan2(f.y, maxf(Vector2(f.x, f.z).length(), 0.0001)))


static func _aim(eye: Vector4, at: Vector4) -> Vector2:
	var d: Vector4 = at - eye
	return Vector2(atan2(-d.x, -d.z), atan2(d.y, maxf(Vector2(d.x, d.z).length(), 0.0001)))


static func _put_cam(cam: Camera4D, eye: Vector4, ang: Vector2) -> void:
	cam.global_position = eye
	cam.global_basis = Basis4D.from_zx(ang.x) * Basis4D.from_yz(ang.y)


# -- the turn through W ------------------------------------------------------------------------------

## Every creature's and tree's pivot to the shared turn; R eases it home.
func _apply_turn(delta: float) -> void:
	if _leveling:
		turn = turn.move_toward(Vector2.ZERO, delta * 3.0)
		if turn == Vector2.ZERO:
			_leveling = false
	for n in get_tree().get_nodes_in_group("hall_turn"):
		if is_ancestor_of(n):
			n.set("turn", turn)


## The exhibits back whole (the Water Lab's "R  Whole again"); the runner calls this too.
func whole_again() -> void:
	_leveling = true
	if hud != null:
		hud.call("toast", "Whole again")


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or loading or player == null:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.ctrl_pressed:
		return
	if not _look.is_empty():
		if k.keycode == KEY_C or k.keycode == KEY_ESCAPE:
			close_look_end()
			get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_C and close_look():
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_R:
		whole_again()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_B and not k.shift_pressed:
		# The strip always said B; only the button worked (round 3, item 42).
		toggle_palette()
		get_viewport().set_input_as_handled()


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


## A left click closes the card; a right drag turns the exhibits through W.
func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or card == null or loading:
		return
	if not _look.is_empty():
		var lb := event as InputEventMouseButton
		if lb != null and lb.pressed and lb.button_index == MOUSE_BUTTON_LEFT:
			close_look_end()
			get_viewport().set_input_as_handled()
			return
	var mm := event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		# As room 1's showcase turns its exhibit: across for xw, up and down for zw.
		_leveling = false
		turn += Vector2(mm.relative.x, mm.relative.y) * 0.006
		get_viewport().set_input_as_handled()
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
	return Pedestal.build(holder, String(s["name"]), s["at"], String(s["shape"]), s["size"], float(s["h"]),
		String(s.get("style", "plain")), s.get("holo", {}))


func _build_station(s: Dictionary) -> void:
	var ped: Dictionary = _pedestal(s)
	var node: Node4D = ped["node"]
	var deck := Node4D.new()
	deck.name = "Deck"
	deck.position = Vector4(0.0, float(ped["deck_h"]), 0.0, 0.0)
	node.add_child(deck)
	var st: Dictionary = {"name": String(s["name"]), "data": s, "node": node, "deck_h": float(ped["deck_h"]), "animals": [],
		"deck": ped["deck"]}
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
	if float(s.get("grass", 0.0)) > 0.0:
		st["grass"] = _deck_grass(s, st)
	if s.has("front"):
		st["label"] = _label(s, st)
	stations.append(st)


## The deck's grass (round 3, item 29): the pen's grass by way of the Botany Lab's copy, standing on the deck's
## top and nowhere else, as deep in W as the deck (its copies through W stand in it), the animals on the deck
## laying it aside where they walk.
func _deck_grass(s: Dictionary, st: Dictionary) -> Node4D:
	var at2: Vector2 = s["at"]
	var top: float = float(st["deck_h"])
	var deck: Vector2 = st["deck"]
	var round_deck: bool = String(s["shape"]) == "round"
	var cell: float = HallGrass.CELL
	var ext: float = maxf(deck.x, deck.y) + cell * 2.0
	var cells: int = int(ceil(ext * 2.0 / cell))
	var rect := Vector4(at2.x - ext, at2.y - ext, cell, float(cells))
	var w_half: float = Build.W_DEPTH * 0.5 - 0.1
	var heights := PackedFloat32Array()
	heights.resize(cells * cells * 2)
	for j in cells:
		for i in cells:
			var q := Vector2(rect.x + (float(i) + 0.5) * cell - at2.x, rect.y + (float(j) + 0.5) * cell - at2.y)
			var inside: bool = q.length() < deck.x - 0.03 if round_deck else (absf(q.x) < deck.x - 0.03 and absf(q.y) < deck.y - 0.03)
			var v: float = top if inside else HallGrass.NONE
			heights[j * cells + i] = v
			heights[(cells + j) * cells + i] = v
	var g := Node4D.new()
	g.name = "Grass" + String(s["name"])
	g.set_script(HallGrass)
	var settings: Dictionary = {"coverage": 1.0, "w_reach": w_half, "height_m": float(s["grass"]), "spacing_m": 0.05,
		"width_scale": 1.35, "radius": 36.0, "band_radii": [6.0, 14.0, 24.0], "band_vertices": [11, 7, 5, 3],
		"height_cap": top + 0.01, "push_reach": float(s.get("push", 0.4))}
	for k in settings:
		g.set(k, settings[k])
	g.set("push_nodes", (st["animals"] as Array).duplicate())
	add_child(g)
	g.set("player", player)
	g.call("start", heights, rect, Vector3(-w_half - 1.0, w_half + 1.0, 2.0), top)
	return g


## The specimen's label (round 3, item 28): the Botany Lab's framed panel, at the deck's front edge (or on the
## floor in front, where the deck is too small for it), facing the side you come from, its number, name and
## kicker from the cards' words. Still: it never moves when you turn the animals.
func _label(s: Dictionary, st: Dictionary) -> Node4D:
	var front: Vector2 = (s["front"] as Vector2).normalized()
	var deck: Vector2 = st["deck"]
	var edge: float = deck.x if String(s["shape"]) == "round" else absf(front.x) * deck.x + absf(front.y) * deck.y
	var on_deck: bool = edge >= 1.7
	var off: float = edge - 0.7 if on_deck else edge + 0.75
	var card: Dictionary = (INFO.get("cards") as Dictionary).get(String(s["name"]), {})
	var lb := Node4D.new()
	lb.name = "Label"
	lb.set_script(SpecLabel)
	var settings: Dictionary = {"width": 1.5, "depth": 0.62, "tilt": 52.0, "hover": 0.45 if on_deck else 0.75,
		"number": _number_of(String(s["name"])), "title": String(card.get("title", s.get("title", s["name"]))),
		"kicker": String(card.get("kicker", "")), "face_point": front * 30.0,
		"reach": 0.0, "give": 0.0, "notice": 0.0, "follow": 0.0, "turn_to_you": 0.0, "solid": false}
	for k in settings:
		lb.set(k, settings[k])
	lb.position = Vector4(front.x * off, float(st["deck_h"]) if on_deck else 0.0, front.y * off, 0.0)
	(st["node"] as Node4D).add_child(lb)
	lb.set("player", player)
	return lb


## A creature station's number, 1 up, in the table's order (trees not counted).
func _number_of(nm: String) -> int:
	var n: int = 0
	for s in STATIONS:
		if String(s["kind"]) == "tree":
			continue
		n += 1
		if String(s["name"]) == nm:
			return n
	return 0


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
				if body != null:
					_wrap(body)
				deck.add_child(b)
				if w != null:
					_roam(b, w, {"radius": 1.1, "margin": 0.2, "look_ahead": 0.8, "turn_rate": 10.0, "wander_degrees": 12.0})
				if body != null:
					st["animals"].append(body)
		"azathoth":
			# The cave's dreamer at pedestal size (round 3, item 36; the research's numbers: a mouth about 1 m across,
			# 1.5 m over the deck, limbs reaching 2 m, kept between the deck and 2.6 m up). Not in a turn pivot: it
			# squares itself to your slice and turns to you, which is the point of it; it eases along W after you.
			var az := _scripted(DREAMER, "Azathoth", {"creature_scale": 0.8, "core_height": 1.5, "limb_length": 2.0,
				"limb_count": 20, "pieces_per_limb": 12, "root_radius": 0.09, "tip_radius": 0.02, "curl_scale": 2.0 / 12.0,
				"room_radii": Vector4(size.x * 0.5 - 0.25, 2.6, size.y * 0.5 - 0.25, 2.5), "floor_clear": 0.08,
				"breath_height": 0.08, "too_close": 3.0, "turn_rate": 1.6, "dust_count": 24, "w_follow": 1.5, "w_follow_limit": 2.5})
			if az != null:
				# It finds you once, as it enters the tree: the paths from where it will stand, set first.
				az.set("player_path", NodePath("../" + String(deck.get_path_to(player))))
				az.set("camera_rig_path", NodePath("../" + String(deck.get_path_to(player.get_node("CameraRig")))))
				deck.add_child(az)
				st["animals"].append(az)
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
					_wrap(body)
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
				deck.add_child(_wrap(wf))
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
					# No pen here: no fence to hop, no trough to go to. NOT the leash (round 3, item 31, "stuck"):
					# it stops him the moment he is past its radius and checks again on the first frame of every
					# walk, so once out he never walked again. His own roam instead (heads home when he stops past
					# roam_radius), with short walks so he keeps to his deck.
					antics.set("fence_path", NodePath())
					antics.set("feeder_path", NodePath())
					antics.set("roam_radius", maxf(size.x - 1.8, 0.6))
					# Livelier than the pen's: walking about half the time, lying down now and then (the pen's
					# lie_chance 0.3 and long roots had him still two thirds of the time).
					antics.set("walk_seconds", Vector2(3.0, 5.5))
					antics.set("root_seconds", Vector2(1.5, 3.0))
					antics.set("lie_chance", 0.12)
				deck.add_child(_wrap(nk))
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
				deck.add_child(_wrap(c))
				if cw != null:
					_roam(deck, cw, {"radius": size.x, "margin": 0.35, "steer": false})
				st["animals"].append(c)
		"heron":
			var hr := _scripted(HERON, "Heron", {"idle_only": true, "size": 1.0})
			if hr != null:
				_turn(hr, -0.5)
				deck.add_child(_wrap(hr))
				st["animals"].append(hr)
				# Now and then a loop off the deck and back to the same spot (round 3, item 39).
				var fl := Node.new()
				fl.name = "HeronLoop"
				fl.set_script(HeronLoop)
				fl.set("heron_path", NodePath("../" + String(deck.get_path_to(hr))))
				fl.set("seed", 3 + (st["animals"] as Array).size())
				deck.add_child(fl)
		"owl":
			# A dead branch to sit on: a post, and a bough off it.
			var wood := Color(0.24, 0.2, 0.17)
			_bar(deck, "Post", Vector4(-0.35, 0.8, 0.1, 0.0), Vector4(0.14, 1.6, 0.14, 0.14), wood)
			_bar(deck, "Bough", Vector4(0.05, 1.52, 0.1, 0.0), Vector4(1.1, 0.09, 0.09, 0.09), wood)
			var ow := _scripted(OWL, "Owl", {"idle_only": true, "size": 0.5})
			if ow != null:
				ow.position = Vector4(0.15, 1.565, 0.1, 0.0)
				deck.add_child(_wrap(ow))
				st["animals"].append(ow)
		"chipmunk":
			# Twice the size it was (round 3, item 32: "far too small to appreciate").
			var cm := _scripted(CHIPMUNK, "Chipmunk", {"idle_only": true, "size": 1.8, "w_stretch": 2.2})
			if cm != null:
				_turn(cm, 0.4)
				deck.add_child(_wrap(cm))
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
				# Its parent is its turn pivot, so its perches are one more step up.
				var perches: Array[NodePath] = [NodePath("../../Rail"), NodePath("../../Crate")]
				cr.set("perch_paths", perches)
				deck.add_child(_wrap(cr))
				st["animals"].append(cr)
			if rail == null or crate == null:
				push_warning("Crows: no perches")

		"tree":
			var t := _scripted(OAK, "Oak", {"bake": "oak_lite2", "leaves_per_node": 28, "leaf_seed": int(s.get("seed", 5)),
				"snap_to_ground": false, "height": 6.4})
			if t != null:
				deck.add_child(_wrap(t))


## Puts an exhibit in a turn pivot of its own (turn_pivot_4d.gd), in its place under its parent if it has one.
## Returns the pivot: add that to the deck when the exhibit has no parent yet. Done before anything enters the
## tree, so nothing is reparented while it runs.
func _wrap(m: Node4D) -> Node4D:
	var pv := Node4D.new()
	pv.name = String(m.name) + "Turn"
	pv.set_script(TurnPivot)
	var parent: Node = m.get_parent()
	if parent != null:
		var idx: int = m.get_index()
		parent.remove_child(m)
		parent.add_child(pv)
		parent.move_child(pv, idx)
	pv.add_child(m)
	return pv


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
## wolf and Nike on the left, Azathoth and the goat on the right; and up the left side and along the back,
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
	# Halfway: left to the wolf and Nike, right to Azathoth and the goat.
	var jl0: int = g.call("add_node", "junction", Vector4(-6.2, 0, 2.4, 0), b)
	var jl: int = g.call("add_node", "junction", Vector4(-9.5, 0, 2.4, 0), b)
	var jr: int = g.call("add_node", "junction", Vector4(9.5, 0, 2.4, 0), b)
	g.call("add_edge", j2, jl0, "secondary")
	g.call("add_edge", jl0, jl, "secondary")
	g.call("add_edge", jl, _dest(g, Vector2(-9.5, 4.4), "Wolf", "round", Vector2(0, -1)), "secondary")
	g.call("add_edge", jl, _dest(g, Vector2(-9.5, 0.2), "Nike", "round", Vector2(0, 1)), "secondary")
	g.call("add_edge", j2, jr, "secondary")
	g.call("add_edge", jr, _dest(g, Vector2(9.5, 5.3), "Azathoth", "rect", Vector2(0, -1)), "secondary")
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
	# The side routes' dots small and a lighter cyan (round 3, item 26).
	net.set("dot_size", 0.4)
	net.set("dot_color", Color(0.55, 0.88, 1.0, 1.0))
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
